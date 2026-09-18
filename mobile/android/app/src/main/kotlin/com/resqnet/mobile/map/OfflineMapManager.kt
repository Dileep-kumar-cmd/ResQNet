package com.resqnet.mobile.map

import android.content.Context
import android.util.Log
import org.json.JSONObject
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.offline.OfflineManager
import org.maplibre.android.offline.OfflineRegion
import org.maplibre.android.offline.OfflineRegionDefinition
import org.maplibre.android.offline.OfflineTilePyramidRegionDefinition

class OfflineMapManager(private val context: Context) {

    companion object {
        private const val TAG = "OfflineMapManager"
    }

    interface DownloadCallback {
        fun onProgress(percentage: Int, completedResourceCount: Long, requiredResourceCount: Long)
        fun onSuccess(regionName: String)
        fun onError(error: String)
    }

    interface ListRegionsCallback {
        fun onRegionsRetrieved(regions: List<Map<String, Any>>)
        fun onError(error: String)
    }

    interface DeleteCallback {
        fun onSuccess(regionId: Long)
        fun onError(error: String)
    }

    private val offlineManager: OfflineManager = OfflineManager.getInstance(context.applicationContext).apply {
        setOfflineMapboxTileCountLimit(50000L)
    }

    fun downloadRegion(
        styleUrl: String,
        minLat: Double,
        minLon: Double,
        maxLat: Double,
        maxLon: Double,
        minZoom: Double,
        maxZoom: Double,
        regionName: String,
        callback: DownloadCallback
    ) {
        val bounds = LatLngBounds.from(maxLat, maxLon, minLat, minLon)
        val pixelRatio = context.resources.displayMetrics.density

        val definition: OfflineRegionDefinition = OfflineTilePyramidRegionDefinition(
            styleUrl,
            bounds,
            minZoom,
            maxZoom,
            pixelRatio
        )

        val metadata: ByteArray = try {
            val json = JSONObject()
            json.put("name", regionName)
            json.put("created_at", System.currentTimeMillis())
            json.toString().toByteArray(Charsets.UTF_8)
        } catch (e: Exception) {
            regionName.toByteArray(Charsets.UTF_8)
        }

        offlineManager.createOfflineRegion(
            definition,
            metadata,
            object : OfflineManager.CreateOfflineRegionCallback {
                override fun onCreate(offlineRegion: OfflineRegion) {
                    offlineRegion.setDownloadState(OfflineRegion.STATE_ACTIVE)

                    offlineRegion.setObserver(object : OfflineRegion.OfflineRegionObserver {
                        override fun onStatusChanged(status: org.maplibre.android.offline.OfflineRegionStatus) {
                            val percentage = if (status.requiredResourceCount > 0) {
                                (100.0 * status.completedResourceCount / status.requiredResourceCount).toInt()
                            } else {
                                0
                            }

                            callback.onProgress(
                                percentage,
                                status.completedResourceCount,
                                status.requiredResourceCount
                            )
                            Log.d(TAG, "Download progress: $percentage% (${status.completedResourceCount}/${status.requiredResourceCount})")

                            if (status.isComplete) {
                                Log.d(TAG, "Region $regionName download complete.")
                                callback.onSuccess(regionName)
                            }
                        }

                        override fun onError(error: org.maplibre.android.offline.OfflineRegionError) {
                            Log.e(TAG, "Offline region error: ${error.reason} - ${error.message}")
                            callback.onError(error.message ?: "Unknown offline download error")
                        }

                        override fun mapboxTileCountLimitExceeded(limit: Long) {
                            Log.w(TAG, "Tile count limit exceeded: $limit")
                            callback.onError("Tile download count limit exceeded ($limit tiles)")
                        }
                    })
                }

                override fun onError(error: String) {
                    Log.e(TAG, "Error creating offline region: $error")
                    callback.onError(error)
                }
            }
        )
    }

    fun listRegions(callback: ListRegionsCallback) {
        offlineManager.listOfflineRegions(object : OfflineManager.ListOfflineRegionsCallback {
            override fun onList(offlineRegions: Array<OfflineRegion>?) {
                val regionList = mutableListOf<Map<String, Any>>()

                offlineRegions?.forEach { region ->
                    val metadataString = String(region.metadata, Charsets.UTF_8)
                    val name = try {
                        JSONObject(metadataString).optString("name", "Region #${region.id}")
                    } catch (e: Exception) {
                        metadataString.ifEmpty { "Region #${region.id}" }
                    }

                    regionList.add(
                        mapOf<String, Any>(
                            "id" to region.id,
                            "name" to name,
                            "styleUrl" to (region.definition.styleURL ?: "")
                        )
                    )
                }

                callback.onRegionsRetrieved(regionList)
            }

            override fun onError(error: String) {
                callback.onError(error)
            }
        })
    }

    fun deleteRegion(regionId: Long, callback: DeleteCallback) {
        offlineManager.listOfflineRegions(object : OfflineManager.ListOfflineRegionsCallback {
            override fun onList(offlineRegions: Array<OfflineRegion>?) {
                val targetRegion = offlineRegions?.find { it.id == regionId }
                if (targetRegion != null) {
                    targetRegion.delete(object : OfflineRegion.OfflineRegionDeleteCallback {
                        override fun onDelete() {
                            callback.onSuccess(regionId)
                        }

                        override fun onError(error: String) {
                            callback.onError(error)
                        }
                    })
                } else {
                    callback.onError("Region ID $regionId not found")
                }
            }

            override fun onError(error: String) {
                callback.onError(error)
            }
        })
    }
}
