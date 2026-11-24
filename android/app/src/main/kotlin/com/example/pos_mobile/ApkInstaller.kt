package com.example.pos_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Pemasangan APK update lewat PackageInstaller session (pengganti membuka link di browser).
 *  - Update pertama: Android menampilkan dialog konfirmasi "Pasang" di atas aplikasi (wajib oleh sistem).
 *  - Android 12+: setelah aplikasi ini sekali memasang dirinya sendiri (jadi "installer of record"), update
 *    berikutnya bisa terpasang tanpa konfirmasi (USER_ACTION_NOT_REQUIRED).
 * Proses aplikasi dihentikan sistem saat paketnya diganti; pembukaan ulang dilakukan UpdateRelaunchReceiver.
 */
object ApkInstaller {
    var channel: MethodChannel? = null
    private const val ACTION_STATUS = "com.example.pos_mobile.INSTALL_STATUS"

    fun install(context: Context, apk: File) {
        require(apk.exists() && apk.length() > 0) { "File APK tidak ditemukan" }
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("qpos.apk", 0, apk.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val intent = Intent(context, InstallResultReceiver::class.java).setAction(ACTION_STATUS)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
    }

    /** Kirim hasil ke Flutter (bila prosesnya masih hidup; saat sukses proses biasanya sudah dihentikan). */
    fun report(status: String, message: String?) {
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod("installResult", mapOf("status" to status, "message" to message))
        }
    }
}

/** Status sesi PackageInstaller: minta konfirmasi user, sukses, atau gagal. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                }
                ApkInstaller.report("pending_user_action", null)
            }
            PackageInstaller.STATUS_SUCCESS -> ApkInstaller.report("success", null)
            else -> {
                val msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                ApkInstaller.report(if (status == PackageInstaller.STATUS_FAILURE_ABORTED) "aborted" else "failure", msg)
            }
        }
    }
}

/**
 * Dipanggil sistem setelah aplikasi ini diperbarui (MY_PACKAGE_REPLACED): buka kembali aplikasi. Android 10+ bisa
 * memblokir pembukaan layar dari latar belakang, jadi selalu dipasang juga notifikasi "Pembaruan selesai" yang
 * membuka aplikasi saat diketuk.
 */
class UpdateRelaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        } ?: return
        notifySelesai(context, launch)
        try {
            context.startActivity(launch)
        } catch (_: Exception) {
            // Diblokir sistem (pembatasan buka dari latar belakang): pengguna memakai notifikasi.
        }
    }

    private fun notifySelesai(context: Context, launch: Intent) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Pembaruan aplikasi", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val pi = PendingIntent.getActivity(
            context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }
        val n = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Pembaruan Q-Pos selesai")
            .setContentText("Ketuk untuk membuka aplikasi")
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(NOTIF_ID, n)
        } catch (_: SecurityException) {
            // Izin notifikasi (Android 13+) belum diberikan.
        }
    }

    companion object {
        private const val CHANNEL_ID = "qpos_update"
        private const val NOTIF_ID = 1002
    }
}
