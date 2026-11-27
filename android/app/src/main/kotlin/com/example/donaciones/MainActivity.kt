package com.example.donaciones

import android.location.Address
import android.location.Geocoder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val sessionStore = getSharedPreferences("donaplus_auth", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "donaplus/session")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(sessionStore.getString("session", null))
                    "save" -> {
                        val session = call.arguments as? String
                        sessionStore.edit().putString("session", session).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "komuna/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "postalCode" -> {
                        val latitude = call.argument<Double>("latitude")
                        val longitude = call.argument<Double>("longitude")
                        if (latitude == null || longitude == null ||
                            latitude !in -90.0..90.0 || longitude !in -180.0..180.0
                        ) {
                            result.error("invalid_coordinates", "Invalid location coordinates.", null)
                            return@setMethodCallHandler
                        }
                        findPostalCode(latitude, longitude, result)
                    }
                    "coordinates" -> {
                        val label = call.argument<String>("label")
                        if (label.isNullOrBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        findCoordinates(label, call.argument<String>("postalCode"), result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun findPostalCode(latitude: Double, longitude: Double, result: MethodChannel.Result) {
        if (!Geocoder.isPresent()) {
            result.success(null)
            return
        }
        val geocoder = Geocoder(applicationContext)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    result.success(addresses.firstOrNull()?.postalCode)
                }

                override fun onError(errorMessage: String?) {
                    result.success(null)
                }
            })
        } else {
            // The older API blocks while the Android geocoding service responds.
            Thread {
                val postalCode = try {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()?.postalCode
                } catch (_: IOException) {
                    null
                }
                result.success(postalCode)
            }.start()
        }
    }

    private fun findCoordinates(label: String, postalCode: String?, result: MethodChannel.Result) {
        if (!Geocoder.isPresent()) {
            result.success(null)
            return
        }
        val geocoder = Geocoder(applicationContext)
        fun sendCoordinates(addresses: List<Address>?) {
            val address = addresses?.firstOrNull {
                it.countryCode == "MX" && it.hasLatitude() && it.hasLongitude() &&
                    (postalCode == null || it.postalCode == postalCode)
            }
            result.success(address?.let {
                mapOf("latitude" to it.latitude, "longitude" to it.longitude)
            })
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            geocoder.getFromLocationName(label, 3, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) = sendCoordinates(addresses)
                override fun onError(errorMessage: String?) = result.success(null)
            })
        } else {
            Thread {
                val addresses = try {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocationName(label, 3)
                } catch (_: IOException) {
                    null
                }
                sendCoordinates(addresses)
            }.start()
        }
    }
}
