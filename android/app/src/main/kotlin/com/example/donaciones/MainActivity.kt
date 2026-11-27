package com.example.donaciones

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.location.Address
import android.location.Geocoder
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var documentPickerResult: MethodChannel.Result? = null

    private companion object {
        const val PICK_INTERMEDIARY_PDF = 4301
        const val MAX_DOCUMENT_BYTES = 5 * 1024 * 1024
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val sessionStore = getSharedPreferences("donaplus_auth", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "donaplus/session")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(sessionStore.getString("session", null))
                    "readRecoveryVerifier" -> result.success(
                        sessionStore.getString("recoveryPkceVerifier", null)
                    )
                    "saveRecoveryVerifier" -> {
                        val verifier = call.arguments as? String
                        val saved = sessionStore.edit()
                            .putString("recoveryPkceVerifier", verifier).commit()
                        if (saved) result.success(null)
                        else result.error("storage_failed", "Unable to save recovery verifier.", null)
                    }
                    "save" -> {
                        val session = call.arguments as? String
                        sessionStore.edit().putString("session", session).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "komuna/intermediary_document")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPdf" -> pickIntermediaryPdf(result)
                    "open" -> {
                        val url = (call.arguments as? String)?.let { Uri.parse(it) }
                        if (url?.scheme != "https") {
                            result.error("invalid_url", "Invalid document URL.", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, url))
                                result.success(null)
                            } catch (_: ActivityNotFoundException) {
                                result.error("no_viewer", "No document viewer is available.", null)
                            }
                        }
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

    private fun pickIntermediaryPdf(result: MethodChannel.Result) {
        if (documentPickerResult != null) {
            result.error("picker_busy", "A document picker is already open.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
        }
        try {
            documentPickerResult = result
            startActivityForResult(intent, PICK_INTERMEDIARY_PDF)
        } catch (_: ActivityNotFoundException) {
            documentPickerResult = null
            result.error("no_picker", "No document picker is available.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_INTERMEDIARY_PDF) return
        val result = documentPickerResult ?: return
        documentPickerResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val displayName = contentResolver.query(
                    uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
                )?.use { if (it.moveToFirst()) it.getString(0) else null }
                val name = displayName?.takeIf { it.endsWith(".pdf", ignoreCase = true) }
                    ?: "documento.pdf"
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (output.size() <= MAX_DOCUMENT_BYTES) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
                runOnUiThread {
                    if (bytes == null || bytes.isEmpty() || bytes.size > MAX_DOCUMENT_BYTES) {
                        result.error("document_size", "Invalid document size.", null)
                    } else {
                        result.success(mapOf("name" to name, "data" to bytes))
                    }
                }
            } catch (_: Exception) {
                runOnUiThread {
                    result.error("read_failed", "Unable to read the selected document.", null)
                }
            }
        }.start()
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
