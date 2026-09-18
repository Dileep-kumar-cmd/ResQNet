package com.resqnet.mobile.mesh

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import java.nio.charset.StandardCharsets
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Autonomous Dual-Role Bluetooth Low Energy (BLE) Mesh Manager.
 * Operates simultaneously as BLE Peripheral (Advertiser & GATT Server)
 * and BLE Central (Scanner & GATT Client) with zero central coordinator.
 */
@SuppressLint("MissingPermission")
class BleMeshManager(private val context: Context) {

    companion object {
        private const val TAG = "BleMeshManager"

        // ResQNet 128-bit Mesh Service UUID
        val SERVICE_UUID: UUID = UUID.fromString("0000FE60-0000-1000-8000-00805F9B34FB")

        // ResQNet Inbound Write Characteristic UUID (Peripheral receives from Central)
        val WRITE_CHAR_UUID: UUID = UUID.fromString("0000FE61-0000-1000-8000-00805F9B34FB")

        // ResQNet Outbound Notify Characteristic UUID (Peripheral pushes to Centrals)
        val NOTIFY_CHAR_UUID: UUID = UUID.fromString("0000FE62-0000-1000-8000-00805F9B34FB")

        // Standard Client Characteristic Configuration Descriptor (CCCD)
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

        @Volatile
        var instance: BleMeshManager? = null

        fun getInstance(context: Context): BleMeshManager {
            return instance ?: synchronized(this) {
                instance ?: BleMeshManager(context.applicationContext).also { instance = it }
            }
        }
    }

    interface Listener {
        fun onPeerDiscovered(nodeId: String, address: String, rssi: Int)
        fun onPeerConnected(nodeId: String, address: String)
        fun onPeerDisconnected(nodeId: String, address: String)
        fun onPacketReceived(packetBytes: ByteArray, fromAddress: String)
        fun onStatusChanged(status: String)
        fun onMeshLog(message: String)
    }

    var listener: Listener? = null

    private val bluetoothManager: BluetoothManager? =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private var gattServer: BluetoothGattServer? = null

    private var localNodeId: String = "node_unknown"
    private var isMeshActive = false
    private var isLowPowerDutyCycle = false

    // Track Centrals connected to our GATT Server (we are Peripheral)
    private val subscribedCentrals = ConcurrentHashMap<String, BluetoothDevice>()

    // Track Peripherals connected via our GATT Clients (we are Central)
    private val connectedGattClients = ConcurrentHashMap<String, BluetoothGatt>()

    // Peer directory: address -> PeerState
    data class PeerState(
        val address: String,
        var nodeId: String,
        var rssi: Int,
        var lastSeenTime: Long,
        var isConnected: Boolean
    )

    private val peers = ConcurrentHashMap<String, PeerState>()
    private val connectingAddresses = Collections.synchronizedSet(HashSet<String>())
    private val mainHandler = Handler(Looper.getMainLooper())

    fun isRunning(): Boolean = isMeshActive

    fun getLocalNodeId(): String = localNodeId

    fun getActivePeerCount(): Int {
        val totalAddresses = HashSet<String>()
        totalAddresses.addAll(subscribedCentrals.keys)
        totalAddresses.addAll(connectedGattClients.keys)
        return totalAddresses.size
    }

    fun getPeersList(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        for ((addr, state) in peers) {
            list.add(
                mapOf(
                    "nodeId" to state.nodeId,
                    "address" to addr,
                    "rssi" to state.rssi,
                    "lastSeen" to state.lastSeenTime,
                    "isConnected" to state.isConnected
                )
            )
        }
        return list
    }

    /**
     * Start the autonomous mesh node:
     * 1. Start Peripheral Advertising & GATT Server
     * 2. Start Central Scanning & Auto-connect Client
     */
    @Synchronized
    fun startMesh(nodeId: String) {
        if (isMeshActive) {
            Log.d(TAG, "Mesh is already active for nodeId: $localNodeId")
            return
        }

        localNodeId = nodeId
        isMeshActive = true
        log("STARTING_MESH_NODE | ID: $localNodeId")

        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            log("BLUETOOTH_DISABLED | Bluetooth adapter is unavailable or off.")
            listener?.onStatusChanged("BLUETOOTH_DISABLED")
            return
        }

        advertiser = bluetoothAdapter.bluetoothLeAdvertiser
        scanner = bluetoothAdapter.bluetoothLeScanner

        // 1. Start GATT Server (Peripheral Role)
        startGattServer()

        // 2. Start Advertising (Peripheral Role)
        startAdvertising()

        // 3. Start Scanning (Central Role)
        startScanning()

        listener?.onStatusChanged("ACTIVE")
    }

    /**
     * Stop the mesh node and release all BLE resources
     */
    @Synchronized
    fun stopMesh() {
        if (!isMeshActive) return
        isMeshActive = false
        log("STOPPING_MESH_NODE")

        stopAdvertising()
        stopScanning()
        stopGattServer()

        // Close all central GATT client connections
        for ((_, gatt) in connectedGattClients) {
            try {
                gatt.disconnect()
                gatt.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing gatt: ${e.message}")
            }
        }
        connectedGattClients.clear()
        subscribedCentrals.clear()
        connectingAddresses.clear()

        listener?.onStatusChanged("STOPPED")
    }

    fun setDutyCycle(lowPower: Boolean) {
        isLowPowerDutyCycle = lowPower
        log("DUTY_CYCLE_CHANGED | Low Power: $lowPower")
        if (isMeshActive) {
            stopScanning()
            stopAdvertising()
            startAdvertising()
            startScanning()
        }
    }

    // =========================================================================
    // BLE PERIPHERAL: Advertising
    // =========================================================================

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            log("ADVERTISING_STARTED | Node: $localNodeId | UUID: $SERVICE_UUID")
        }

        override fun onStartFailure(errorCode: Int) {
            log("ADVERTISING_FAILED | ErrorCode: $errorCode")
        }
    }

    private fun startAdvertising() {
        val adv = advertiser ?: return
        try {
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(
                    if (isLowPowerDutyCycle) AdvertiseSettings.ADVERTISE_MODE_BALANCED
                    else AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
                )
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0) // Advertise indefinitely
                .build()

            // Transmit Service UUID and Node ID in service data payload
            val serviceDataBytes = localNodeId.toByteArray(StandardCharsets.UTF_8)
            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .setIncludeTxPowerLevel(false)
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .addServiceData(ParcelUuid(SERVICE_UUID), serviceDataBytes)
                .build()

            adv.startAdvertising(settings, data, advertiseCallback)
        } catch (e: Exception) {
            log("ERROR_START_ADVERTISING | ${e.message}")
        }
    }

    private fun stopAdvertising() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping advertising: ${e.message}")
        }
    }

    // =========================================================================
    // BLE PERIPHERAL: GATT Server
    // =========================================================================

    private fun startGattServer() {
        if (bluetoothManager == null) return

        gattServer = bluetoothManager.openGattServer(context, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                val addr = device.address
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    log("GATT_SERVER_CENTRAL_CONNECTED | Addr: $addr")
                    subscribedCentrals[addr] = device
                    updatePeerConnection(addr, true)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    log("GATT_SERVER_CENTRAL_DISCONNECTED | Addr: $addr")
                    subscribedCentrals.remove(addr)
                    updatePeerConnection(addr, false)
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }

                if (characteristic.uuid == WRITE_CHAR_UUID && value != null && value.isNotEmpty()) {
                    log("PACKET_RECEIVED_VIA_GATT_SERVER | From: ${device.address} | Bytes: ${value.size}")
                    mainHandler.post {
                        listener?.onPacketReceived(value, device.address)
                    }
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray?
            ) {
                if (descriptor.uuid == CCCD_UUID) {
                    if (value != null && Arrays.equals(value, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                        subscribedCentrals[device.address] = device
                        log("CENTRAL_SUBSCRIBED_NOTIFY | Addr: ${device.address}")
                    } else if (value != null && Arrays.equals(value, BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)) {
                        subscribedCentrals.remove(device.address)
                        log("CENTRAL_UNSUBSCRIBED_NOTIFY | Addr: ${device.address}")
                    }
                }

                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
            }
        })

        // Build the ResQNet Primary Mesh Service
        val meshService = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // Write Characteristic (Incoming packets from centrals)
        val writeChar = BluetoothGattCharacteristic(
            WRITE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        // Notify Characteristic (Outbound packets pushed to centrals)
        val notifyChar = BluetoothGattCharacteristic(
            NOTIFY_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                    BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        // Add CCCD descriptor to Notify Characteristic
        val cccd = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ
        )
        notifyChar.addDescriptor(cccd)

        meshService.addCharacteristic(writeChar)
        meshService.addCharacteristic(notifyChar)

        gattServer?.addService(meshService)
        log("GATT_SERVER_READY | Service: $SERVICE_UUID registered.")
    }

    private fun stopGattServer() {
        try {
            gattServer?.clearServices()
            gattServer?.close()
            gattServer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error closing gatt server: ${e.message}")
        }
    }

    // =========================================================================
    // BLE CENTRAL: Scanning & Auto-Connect
    // =========================================================================

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            processScanResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            for (r in results) {
                processScanResult(r)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            log("SCAN_FAILED | ErrorCode: $errorCode")
        }
    }

    private fun processScanResult(result: ScanResult) {
        val device = result.device ?: return
        val addr = device.address
        val rssi = result.rssi

        // Parse node ID from service data if available
        var peerNodeId = "node_${addr.replace(":", "").takeLast(6).lowercase()}"
        val record = result.scanRecord
        if (record != null) {
            val serviceData = record.getServiceData(ParcelUuid(SERVICE_UUID))
            if (serviceData != null && serviceData.isNotEmpty()) {
                peerNodeId = String(serviceData, StandardCharsets.UTF_8).trim()
            }
        }

        // Avoid connecting to ourselves if MAC matches or node ID matches
        if (peerNodeId == localNodeId) return

        val existing = peers[addr]
        if (existing == null) {
            val newState = PeerState(
                address = addr,
                nodeId = peerNodeId,
                rssi = rssi,
                lastSeenTime = System.currentTimeMillis(),
                isConnected = false
            )
            peers[addr] = newState
            log("DISCOVERED_PEER | Node: $peerNodeId | Addr: $addr | RSSI: $rssi dBm")
            mainHandler.post {
                listener?.onPeerDiscovered(peerNodeId, addr, rssi)
            }
        } else {
            existing.rssi = rssi
            existing.lastSeenTime = System.currentTimeMillis()
            if (existing.nodeId != peerNodeId && peerNodeId.startsWith("node_")) {
                existing.nodeId = peerNodeId
            }
        }

        // Automatic P2P connection to discovered ResQNet peer
        if (!connectedGattClients.containsKey(addr) &&
            !subscribedCentrals.containsKey(addr) &&
            !connectingAddresses.contains(addr)
        ) {
            connectToPeerGatt(device)
        }
    }

    private fun connectToPeerGatt(device: BluetoothDevice) {
        val addr = device.address
        connectingAddresses.add(addr)
        log("AUTO_CONNECTING_TO_PEER | Addr: $addr")

        device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                connectingAddresses.remove(addr)
                if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                    log("GATT_CLIENT_CONNECTED | Addr: $addr | Requesting MTU 512 & Discovering Services")
                    connectedGattClients[addr] = gatt
                    gatt.requestMtu(512)
                    gatt.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    log("GATT_CLIENT_DISCONNECTED | Addr: $addr | Status: $status")
                    connectedGattClients.remove(addr)
                    updatePeerConnection(addr, false)
                    try {
                        gatt.close()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error closing gatt: ${e.message}")
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    log("GATT_SERVICES_DISCOVERY_FAILED | Addr: $addr | Status: $status")
                    return
                }

                val service = gatt.getService(SERVICE_UUID)
                if (service == null) {
                    log("RESQNET_SERVICE_NOT_FOUND | Addr: $addr | Disconnecting")
                    gatt.disconnect()
                    return
                }

                val notifyChar = service.getCharacteristic(NOTIFY_CHAR_UUID)
                if (notifyChar != null) {
                    gatt.setCharacteristicNotification(notifyChar, true)
                    val cccd = notifyChar.getDescriptor(CCCD_UUID)
                    if (cccd != null) {
                        cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(cccd)
                        log("SUBSCRIBED_PEER_NOTIFY | Addr: $addr")
                    }
                }

                updatePeerConnection(addr, true)
                val peer = peers[addr]
                val pNodeId = peer?.nodeId ?: "node_${addr.takeLast(4)}"
                mainHandler.post {
                    listener?.onPeerConnected(pNodeId, addr)
                }
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                if (characteristic.uuid == NOTIFY_CHAR_UUID) {
                    val value = characteristic.value ?: return
                    log("PACKET_RECEIVED_VIA_GATT_CLIENT | From: $addr | Bytes: ${value.size}")
                    mainHandler.post {
                        listener?.onPacketReceived(value, addr)
                    }
                }
            }
        }, BluetoothDevice.TRANSPORT_LE)
    }

    private fun startScanning() {
        val scn = scanner ?: return
        try {
            val filter = ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()

            val settings = ScanSettings.Builder()
                .setScanMode(
                    if (isLowPowerDutyCycle) ScanSettings.SCAN_MODE_BALANCED
                    else ScanSettings.SCAN_MODE_LOW_LATENCY
                )
                .setReportDelay(0)
                .build()

            scn.startScan(listOf(filter), settings, scanCallback)
            log("SCANNING_STARTED | Filter: $SERVICE_UUID")
        } catch (e: Exception) {
            log("ERROR_START_SCANNING | ${e.message}")
        }
    }

    private fun stopScanning() {
        try {
            scanner?.stopScan(scanCallback)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping scanner: ${e.message}")
        }
    }

    private fun updatePeerConnection(address: String, connected: Boolean) {
        val p = peers[address]
        if (p != null) {
            p.isConnected = connected
            if (!connected) {
                mainHandler.post {
                    listener?.onPeerDisconnected(p.nodeId, address)
                }
            }
        }
    }

    // =========================================================================
    // MULTI-HOP PACKET TRANSMISSION (BROADCAST / FLOOD)
    // =========================================================================

    /**
     * Broadcasts raw packet bytes across all connected radio links:
     * 1. Centrals connected to our GATT Server (via Characteristic Notification)
     * 2. Peripherals connected to our GATT Clients (via Characteristic Write)
     */
    @Synchronized
    fun broadcastPacket(packetBytes: ByteArray): Int {
        if (!isMeshActive || packetBytes.isEmpty()) return 0
        var transmittedLinks = 0

        // 1. Push notification to all Centrals connected to our GATT Server
        val server = gattServer
        if (server != null && subscribedCentrals.isNotEmpty()) {
            val service = server.getService(SERVICE_UUID)
            val notifyChar = service?.getCharacteristic(NOTIFY_CHAR_UUID)
            if (notifyChar != null) {
                notifyChar.value = packetBytes
                for ((_, device) in subscribedCentrals) {
                    try {
                        server.notifyCharacteristicChanged(device, notifyChar, false)
                        transmittedLinks++
                    } catch (e: Exception) {
                        Log.e(TAG, "Error notifying central ${device.address}: ${e.message}")
                    }
                }
            }
        }

        // 2. Write to all Peripherals connected to our GATT Clients
        for ((_, gatt) in connectedGattClients) {
            try {
                val service = gatt.getService(SERVICE_UUID)
                val writeChar = service?.getCharacteristic(WRITE_CHAR_UUID)
                if (writeChar != null) {
                    writeChar.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                    writeChar.value = packetBytes
                    gatt.writeCharacteristic(writeChar)
                    transmittedLinks++
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error writing to peripheral ${gatt.device.address}: ${e.message}")
            }
        }

        log("BROADCAST_COMPLETED | Links: $transmittedLinks | Bytes: ${packetBytes.size}")
        return transmittedLinks
    }

    private fun log(message: String) {
        Log.i(TAG, message)
        mainHandler.post {
            listener?.onMeshLog(message)
        }
    }
}
