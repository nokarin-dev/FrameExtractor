package com.nokarin.frameextractor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.net.toUri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nokarin.frameextractor/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNativeLibraryDir" -> {
                        result.success(applicationInfo.nativeLibraryDir)
                    }

                    "getPathFromUri" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString == null) {
                            result.error("INVALID_ARG", "uri is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = uriString.toUri()
                            val path = UriHelper.getPathFromUri(this, uri)
                            result.success(path)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }

                    "getExternalFilesDir" -> {
                        val type = call.argument<String>("type")
                        val dir = getExternalFilesDir(type)
                        result.success(dir?.absolutePath)
                    }

                    "copyFramesToUri" -> {
                        val sourceDir = call.argument<String>("sourceDir")
                        val targetUri = call.argument<String>("targetUri")
                        val subfolder = call.argument<String>("subfolder")
                        if (sourceDir == null || targetUri == null) {
                            result.error("INVALID_ARGS", "sourceDir and targetUri required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = targetUri.toUri()
                            val count = MediaStoreHelper.copyFramesToUri(
                                this, sourceDir, uri, subfolder
                            )
                            result.success(count)
                        } catch (e: Exception) {
                            result.error("COPY_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}