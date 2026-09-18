package com.resqnet.mobile.map

import android.content.Context
import android.graphics.RectF
import android.util.Log
import android.view.View
import java.io.File
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style

class MapPlatformView(
    private val context: Context,
    viewId: Int,
    args: Map<String, Any>?,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "MapPlatformView"
        private const val METHOD_CHANNEL_NAME = "com.resqnet.mobile/vector_map_channel"
        private const val EVENT_CHANNEL_NAME = "com.resqnet.mobile/vector_map_events"
    }

    // Configure TextureView mode for composition inside Flutter AndroidView
    private val mapViewOptions: MapLibreMapOptions = MapLibreMapOptions.createFromAttributes(context)
        .textureMode(true)
    private val mapView: MapView = MapView(context, mapViewOptions)

    private var mapLibreMap: MapLibreMap? = null
    private var renderer: MarkerAndLayerRenderer? = null
    private val offlineMapManager: OfflineMapManager = OfflineMapManager(context)
    private var locationManager: LocationManager? = null
    private var pendingStyle: String? = null

    private val methodChannel: MethodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val eventChannel: EventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
    private var eventSink: EventChannel.EventSink? = null

    private var currentLat: Double = 37.7749
    private var currentLon: Double = -122.4194

    private var lastSheltersArray: JSONArray? = null
    private var lastHospitalsArray: JSONArray? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)

        mapView.onCreate(null)
        mapView.onStart()
        mapView.onResume()

        val initialLat = (args?.get("initialLat") as? Number)?.toDouble() ?: 37.7749
        val initialLon = (args?.get("initialLon") as? Number)?.toDouble() ?: -122.4194
        val initialZoom = (args?.get("initialZoom") as? Number)?.toDouble() ?: 12.0
        val sheltersJsonStr = args?.get("sheltersJson") as? String ?: "[]"
        val hospitalsJsonStr = args?.get("hospitalsJson") as? String ?: "[]"

        currentLat = initialLat
        currentLon = initialLon

        try {
            lastSheltersArray = JSONArray(sheltersJsonStr)
            lastHospitalsArray = JSONArray(hospitalsJsonStr)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing initial features JSON: ${e.message}")
        }

        mapView.getMapAsync { map ->
            mapLibreMap = map
            map.uiSettings.isAttributionEnabled = false
            map.uiSettings.isLogoEnabled = false

            map.moveCamera(
                CameraUpdateFactory.newCameraPosition(
                    CameraPosition.Builder()
                        .target(LatLng(initialLat, initialLon))
                        .zoom(initialZoom)
                        .build()
                )
            )

            val initialStyle = pendingStyle ?: "style_vector.json"
            loadMapStyleAsset(initialStyle)
        }

        locationManager = LocationManager(context, object : LocationManager.LocationListener {
            override fun onLocationUpdated(lat: Double, lon: Double, altitude: Double, accuracy: Float, speed: Float) {
                currentLat = lat
                currentLon = lon
                renderer?.updateUserLocation(lat, lon)
                sendEvent(
                    "locationUpdate",
                    mapOf(
                        "latitude" to lat,
                        "longitude" to lon,
                        "altitude" to altitude,
                        "accuracy" to accuracy,
                        "speed" to speed
                    )
                )
            }

            override fun onPermissionDenied() {
                sendEvent("mapError", mapOf("code" to "LOCATION_PERMISSION_DENIED", "message" to "Location permission denied"))
            }
        })
    }

    private fun getStyleFile(assetFileName: String): File {
        val file = File(context.filesDir, assetFileName)
        try {
            val content = context.assets.open("flutter_assets/assets/map/$assetFileName")
                .bufferedReader()
                .use { it.readText() }
            file.writeText(content)
        } catch (e: Exception) {
            Log.e(TAG, "Error copying style asset $assetFileName to filesDir: ${e.message}")
        }
        return file
    }

    private fun loadMapStyleAsset(assetFileName: String) {
        val map = mapLibreMap
        if (map == null) {
            pendingStyle = assetFileName
            Log.d(TAG, "mapLibreMap not ready yet, stored pendingStyle=$assetFileName")
            return
        }

        val styleFile = getStyleFile(assetFileName)
        val styleJsonString = if (styleFile.exists() && styleFile.length() > 0) {
            try { styleFile.readText() } catch (e: Exception) { null }
        } else {
            try {
                context.assets.open("flutter_assets/assets/map/$assetFileName")
                    .bufferedReader()
                    .use { it.readText() }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read style JSON asset $assetFileName: ${e.message}")
                null
            }
        }

        val styleBuilder = Style.Builder()
        if (styleJsonString != null) {
            styleBuilder.fromJson(styleJsonString)
        } else if (styleFile.exists()) {
            styleBuilder.fromUri(styleFile.toURI().toString())
        } else {
            styleBuilder.fromUri("asset://flutter_assets/assets/map/$assetFileName")
        }

        Log.d(TAG, "Applying style builder for $assetFileName...")
        map.setStyle(styleBuilder) { style ->
            Log.d(TAG, "Style applied successfully: $assetFileName")
            renderer = MarkerAndLayerRenderer(map)
            setupMapListeners(map)

            try {
                if (lastSheltersArray != null) renderer?.updateSheltersData(lastSheltersArray!!)
                if (lastHospitalsArray != null) renderer?.updateHospitalsData(lastHospitalsArray!!)
                renderer?.updateUserLocation(currentLat, currentLon)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating features on style change: ${e.message}")
            }

            sendEvent("mapLoaded", mapOf("status" to "ready", "style" to assetFileName))
        }
    }

    private fun setupMapListeners(map: MapLibreMap) {
        map.addOnMapClickListener { point ->
            val screenPoint = map.projection.toScreenLocation(point)
            val rect = RectF(
                screenPoint.x - 25,
                screenPoint.y - 25,
                screenPoint.x + 25,
                screenPoint.y + 25
            )

            // Query shelters or hospitals
            val features = map.queryRenderedFeatures(
                rect,
                "shelter_unclustered",
                "hospital_unclustered",
                "shelter_clusters",
                "hospital_clusters"
            )

            if (features.isNotEmpty()) {
                val feature = features[0]
                val props = feature.properties()

                if (props != null) {
                    if (props.has("point_count")) {
                        // Cluster clicked -> zoom in
                        val currentZoom = map.cameraPosition.zoom
                        map.animateCamera(CameraUpdateFactory.newLatLngZoom(point, currentZoom + 2.0))
                    } else {
                        // Marker clicked -> emit markerSelected event
                        val propsMap = mutableMapOf<String, Any>()
                        val keys = props.keySet()
                        for (key in keys) {
                            val element = props.get(key)
                            if (element != null && !element.isJsonNull) {
                                propsMap[key] = element.asString
                            }
                        }
                        sendEvent("markerSelected", propsMap)
                    }
                }
                true
            } else {
                sendEvent("markerSelected", emptyMap<String, Any>())
                false
            }
        }
    }

    override fun getView(): View {
        return mapView
    }

    override fun dispose() {
        locationManager?.stopLocationUpdates()
        try {
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing MapView: ${e.message}")
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "centerMap" -> {
                val lat = call.argument<Double>("latitude") ?: 37.7749
                val lon = call.argument<Double>("longitude") ?: -122.4194
                val zoom = call.argument<Double>("zoom") ?: 12.0

                mapLibreMap?.animateCamera(
                    CameraUpdateFactory.newCameraPosition(
                        CameraPosition.Builder()
                            .target(LatLng(lat, lon))
                            .zoom(zoom)
                            .build()
                    )
                )
                result.success(true)
            }
            "setZoom" -> {
                val zoom = call.argument<Double>("zoom") ?: 12.0
                mapLibreMap?.animateCamera(CameraUpdateFactory.zoomTo(zoom))
                result.success(true)
            }
            "setMapStyle" -> {
                val styleName = call.argument<String>("style") ?: "vector"
                val fileName = when (styleName.lowercase()) {
                    "satellite" -> "style_satellite.json"
                    "topographic", "relief" -> "style_relief.json"
                    else -> "style_vector.json"
                }

                loadMapStyleAsset(fileName)
                result.success(true)
            }
            "locateUser" -> {
                val act = (context as? android.app.Activity)
                if (locationManager?.hasLocationPermission() == true) {
                    locationManager?.startLocationUpdates()
                    mapLibreMap?.animateCamera(
                        CameraUpdateFactory.newCameraPosition(
                            CameraPosition.Builder()
                                .target(LatLng(currentLat, currentLon))
                                .zoom(14.0)
                                .build()
                        )
                    )
                    result.success(true)
                } else {
                    if (act != null) {
                        locationManager?.requestPermissions(act)
                    }
                    result.error("PERMISSION_DENIED", "Location permission not granted. Requested runtime permission prompt.", null)
                }
            }
            "setFeaturesData" -> {
                val sheltersJsonStr = call.argument<String>("sheltersJson") ?: "[]"
                val hospitalsJsonStr = call.argument<String>("hospitalsJson") ?: "[]"

                try {
                    val sheltersArray = JSONArray(sheltersJsonStr)
                    val hospitalsArray = JSONArray(hospitalsJsonStr)

                    lastSheltersArray = sheltersArray
                    lastHospitalsArray = hospitalsArray

                    renderer?.updateSheltersData(sheltersArray)
                    renderer?.updateHospitalsData(hospitalsArray)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("PARSE_ERROR", "Error parsing features JSON: ${e.message}", null)
                }
            }
            "setEmergencyRadius" -> {
                val lat = call.argument<Double>("latitude") ?: currentLat
                val lon = call.argument<Double>("longitude") ?: currentLon
                val radiusKm = call.argument<Double>("radiusKm") ?: 5.0
                val visible = call.argument<Boolean>("visible") ?: false

                renderer?.updateEmergencyRadius(lat, lon, radiusKm, visible)
                result.success(true)
            }
            "startOfflineDownload" -> {
                val minLat = call.argument<Double>("minLat") ?: 37.70
                val minLon = call.argument<Double>("minLon") ?: -122.52
                val maxLat = call.argument<Double>("maxLat") ?: 37.85
                val maxLon = call.argument<Double>("maxLon") ?: -122.35
                val regionName = call.argument<String>("regionName") ?: "Offline Region"

                val styleFile = getStyleFile("style_vector.json")
                val styleUri = styleFile.toURI().toString()

                offlineMapManager.downloadRegion(
                    styleUri,
                    minLat, minLon, maxLat, maxLon,
                    10.0, 14.0,
                    regionName,
                    object : OfflineMapManager.DownloadCallback {
                        override fun onProgress(percentage: Int, completedResourceCount: Long, requiredResourceCount: Long) {
                            sendEvent(
                                "offlineDownloadProgress",
                                mapOf(
                                    "regionName" to regionName,
                                    "percentage" to percentage,
                                    "completed" to completedResourceCount,
                                    "total" to requiredResourceCount
                                )
                            )
                        }

                        override fun onSuccess(regionName: String) {
                            sendEvent("offlineMapReady", mapOf("regionName" to regionName, "status" to "ready"))
                        }

                        override fun onError(error: String) {
                            sendEvent("downloadFailure", mapOf("regionName" to regionName, "error" to error))
                        }
                    }
                )
                result.success(true)
            }
            "listOfflineRegions" -> {
                offlineMapManager.listRegions(object : OfflineMapManager.ListRegionsCallback {
                    override fun onRegionsRetrieved(regions: List<Map<String, Any>>) {
                        result.success(regions)
                    }

                    override fun onError(error: String) {
                        result.error("OFFLINE_ERROR", error, null)
                    }
                })
            }
            "deleteOfflineRegion" -> {
                val regionId = (call.argument<Number>("regionId"))?.toLong() ?: 0L
                offlineMapManager.deleteRegion(regionId, object : OfflineMapManager.DeleteCallback {
                    override fun onSuccess(regionId: Long) {
                        result.success(true)
                    }

                    override fun onError(error: String) {
                        result.error("DELETE_ERROR", error, null)
                    }
                })
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (mapLibreMap != null) {
            sendEvent("mapLoaded", mapOf("status" to "ready", "style" to (pendingStyle ?: "style_vector.json")))
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun sendEvent(eventType: String, data: Map<String, Any>) {
        val payload = mutableMapOf<String, Any>("eventType" to eventType)
        payload.putAll(data)
        eventSink?.success(payload)
    }
}
