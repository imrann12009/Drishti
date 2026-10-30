package com.example.drishti

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.drishti/update_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleUpdateCall(call, result) }
    }

    private fun handleUpdateCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else true)
                }
                "openUnknownAppsSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        })
                    }
                    result.success(null)
                }
                "inspectApk" -> result.success(inspectApk(requirePath(call)))
                "installApk" -> {
                    val apk = File(requirePath(call))
                    if (!apk.isFile) throw IllegalArgumentException("APK is missing")
                    val uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.updateprovider",
                        apk
                    )
                    startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            // No path, file metadata, or internal exception text reaches Dart.
            result.error("update_operation_failed", "Android update operation failed.", null)
        }
    }

    private fun requirePath(call: MethodCall): String =
        call.argument<String>("path")?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Missing path")

    private fun inspectApk(path: String): Map<String, Any> {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES
        }
        @Suppress("DEPRECATION")
        val info: PackageInfo = packageManager.getPackageArchiveInfo(path, flags)
            ?: throw IllegalArgumentException("Invalid APK")
        val signer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
        } else {
            @Suppress("DEPRECATION") info.signatures?.firstOrNull()?.toByteArray()
        } ?: throw IllegalArgumentException("Unsigned APK")
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION") info.versionCode.toLong()
        }
        return mapOf(
            "packageName" to info.packageName,
            "versionCode" to versionCode,
            "signingCertificateSha256" to sha256(signer)
        )
    }

    private fun sha256(bytes: ByteArray): String = MessageDigest
        .getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { "%02x".format(it) }
}
