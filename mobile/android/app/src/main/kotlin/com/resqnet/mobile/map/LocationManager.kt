package com.resqnet.mobile.map

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

class LocationManager(private val context: Context, private val listener: LocationListener) {

    interface LocationListener {
        fun onLocationUpdated(lat: Double, lon: Double, altitude: Double, accuracy: Float, speed: Float)
        fun onPermissionDenied()
    }

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private var locationCallback: LocationCallback? = null
    var isTracking: Boolean = false
        private set

    fun hasLocationPermission(): Boolean {
        val finePerm = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarsePerm = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return finePerm || coarsePerm
    }

    fun requestPermissions(activity: Activity) {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            1001
        )
    }

    fun startLocationUpdates(activity: Activity? = null) {
        if (!hasLocationPermission()) {
            val act = activity ?: (context as? Activity)
            if (act != null) {
                requestPermissions(act)
            }
            listener.onPermissionDenied()
            return
        }

        if (isTracking) return

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY, 3000
        ).setMinUpdateIntervalMillis(1000).build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (location in result.locations) {
                    listener.onLocationUpdated(
                        location.latitude,
                        location.longitude,
                        location.altitude,
                        location.accuracy,
                        location.speed
                    )
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            isTracking = true
            
            // Get last location immediately if available
            fusedLocationClient.lastLocation.addOnSuccessListener { loc: Location? ->
                if (loc != null) {
                    listener.onLocationUpdated(
                        loc.latitude,
                        loc.longitude,
                        loc.altitude,
                        loc.accuracy,
                        loc.speed
                    )
                }
            }
        } catch (e: SecurityException) {
            listener.onPermissionDenied()
        }
    }

    fun stopLocationUpdates() {
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
        }
        isTracking = false
        locationCallback = null
    }
}
