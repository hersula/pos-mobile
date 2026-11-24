package com.example.pos_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Channel `qpos/app_update` untuk update di dalam aplikasi (tanpa membuka browser):
 *  - updateDir: folder unduhan APK (cache aplikasi, tanpa izin storage)
 *  - canInstall / openInstallPermission: izin "Instal aplikasi tak dikenal" (Android 8+)
 *  - install(path): pasang lewat PackageInstaller (lihat ApkInstaller), hasil dikirim balik
 *    ke Flutter lewat method `installResult` {status, message}.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ApkInstaller.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateDir" -> {
                    val dir = File(cacheDir, "update").apply { mkdirs() }
                    result.success(dir.absolutePath)
                }
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "openInstallPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                        )
                    }
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("NO_PATH", "Path APK kosong", null)
                    } else {
                        try {
                            ApkInstaller.install(this, File(path))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message ?: "Gagal memulai pemasangan", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        ApkInstaller.channel = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "qpos/app_update"
    }
}
