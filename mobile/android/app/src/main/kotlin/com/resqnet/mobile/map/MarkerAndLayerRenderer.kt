package com.resqnet.mobile.map

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import org.maplibre.android.style.sources.GeoJsonSource
import kotlin.math.cos
import kotlin.math.sin

class MarkerAndLayerRenderer(private val map: MapLibreMap) {

    companion object {
        private const val TAG = "MarkerAndLayerRenderer"
        private const val SHELTERS_SOURCE_ID = "shelters_source"
        private const val HOSPITALS_SOURCE_ID = "hospitals_source"
        private const val USER_LOCATION_SOURCE_ID = "user_location_source"
        private const val EMERGENCY_RADIUS_SOURCE_ID = "emergency_radius_source"
    }

    fun updateSheltersData(sheltersJsonArray: JSONArray) {
        val style = map.style ?: return
        val source = style.getSourceAs<GeoJsonSource>(SHELTERS_SOURCE_ID) ?: return

        val features = mutableListOf<String>()
        for (i in 0 until sheltersJsonArray.length()) {
            val s = sheltersJsonArray.getJSONObject(i)
            val id = s.optString("id", "shl_$i")
            val name = s.optString("name", "Shelter")
            val lat = s.optDouble("latitude", 0.0)
            val lon = s.optDouble("longitude", 0.0)
            val capacity = s.optInt("capacity", 100)
            val occupancy = s.optInt("current_occupancy", 0)
            val hazard = s.optInt("hazard_rating", 0)

            val featureJson = """
                {
                  "type": "Feature",
                  "id": "$id",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [$lon, $lat]
                  },
                  "properties": {
                    "id": "$id",
                    "name": "$name",
                    "type_category": "SHELTER",
                    "latitude": $lat,
                    "longitude": $lon,
                    "capacity": $capacity,
                    "current_occupancy": $occupancy,
                    "hazard_rating": $hazard
                  }
                }
            """.trimIndent()
            features.add(featureJson)
        }

        val collectionJson = """
            {
              "type": "FeatureCollection",
              "features": [${features.joinToString(",")}]
            }
        """.trimIndent()

        try {
            source.setGeoJson(collectionJson)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating shelters GeoJSON source: ${e.message}")
        }
    }

    fun updateHospitalsData(hospitalsJsonArray: JSONArray) {
        val style = map.style ?: return
        val source = style.getSourceAs<GeoJsonSource>(HOSPITALS_SOURCE_ID) ?: return

        val features = mutableListOf<String>()
        for (i in 0 until hospitalsJsonArray.length()) {
            val h = hospitalsJsonArray.getJSONObject(i)
            val id = h.optString("id", "med_$i")
            val name = h.optString("name", "Hospital")
            val lat = h.optDouble("latitude", 0.0)
            val lon = h.optDouble("longitude", 0.0)
            val type = h.optString("type", "HOSPITAL")
            val capacity = h.optInt("capacity", 50)

            val featureJson = """
                {
                  "type": "Feature",
                  "id": "$id",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [$lon, $lat]
                  },
                  "properties": {
                    "id": "$id",
                    "name": "$name",
                    "type_category": "MEDICAL",
                    "type": "$type",
                    "latitude": $lat,
                    "longitude": $lon,
                    "capacity": $capacity
                  }
                }
            """.trimIndent()
            features.add(featureJson)
        }

        val collectionJson = """
            {
              "type": "FeatureCollection",
              "features": [${features.joinToString(",")}]
            }
        """.trimIndent()

        try {
            source.setGeoJson(collectionJson)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating hospitals GeoJSON source: ${e.message}")
        }
    }

    fun updateUserLocation(lat: Double, lon: Double) {
        val style = map.style ?: return
        val source = style.getSourceAs<GeoJsonSource>(USER_LOCATION_SOURCE_ID) ?: return

        val featureJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [$lon, $lat]
                  },
                  "properties": {
                    "title": "Current Location"
                  }
                }
              ]
            }
        """.trimIndent()

        try {
            source.setGeoJson(featureJson)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating user location source: ${e.message}")
        }
    }

    fun updateEmergencyRadius(lat: Double, lon: Double, radiusKm: Double, visible: Boolean) {
        val style = map.style ?: return
        val source = style.getSourceAs<GeoJsonSource>(EMERGENCY_RADIUS_SOURCE_ID) ?: return

        if (!visible || radiusKm <= 0.0) {
            source.setGeoJson("""{"type":"FeatureCollection","features":[]}""")
            return
        }

        // Generate circle polygon coordinates for radius in km
        val points = 64
        val coordinates = mutableListOf<String>()
        val earthRadiusKm = 6371.0
        val latRad = Math.toRadians(lat)
        val lonRad = Math.toRadians(lon)
        val dRad = radiusKm / earthRadiusKm

        for (i in 0..points) {
            val bearing = 2 * Math.PI * i / points
            val pLatRad = Math.asin(
                Math.sin(latRad) * Math.cos(dRad) +
                        Math.cos(latRad) * Math.sin(dRad) * Math.cos(bearing)
            )
            val pLonRad = lonRad + Math.atan2(
                Math.sin(bearing) * Math.sin(dRad) * Math.cos(latRad),
                Math.cos(dRad) - Math.sin(latRad) * Math.sin(pLatRad)
            )
            val pLat = Math.toDegrees(pLatRad)
            val pLon = Math.toDegrees(pLonRad)
            coordinates.add("[$pLon, $pLat]")
        }

        val featureJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Polygon",
                    "coordinates": [[${coordinates.joinToString(",")}]]
                  },
                  "properties": {
                    "radius_km": $radiusKm
                  }
                }
              ]
            }
        """.trimIndent()

        try {
            source.setGeoJson(featureJson)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating emergency radius source: ${e.message}")
        }
    }
}
