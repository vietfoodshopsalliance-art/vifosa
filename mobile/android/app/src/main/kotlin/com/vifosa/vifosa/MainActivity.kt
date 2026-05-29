package com.vifosa.vifosa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    // Âm thanh thông báo gắn cứng vào NotificationChannel (Android 8+).
    // Phải tạo channel với custom sound để chuông kêu khi màn hình tắt / app chạy nền.
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val nm = getSystemService(NotificationManager::class.java) ?: return

        val audioAttrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val newOrder = NotificationChannel(
            CHANNEL_NEW_ORDER,
            "Đơn hàng mới",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Chuông báo khi có đơn hàng mới"
            setSound(rawUri("chuong"), audioAttrs)
            enableVibration(true)
        }

        val payment = NotificationChannel(
            CHANNEL_PAYMENT,
            "Cập nhật thanh toán",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Chuông báo khi thanh toán được cập nhật"
            setSound(rawUri("ding"), audioAttrs)
            enableVibration(true)
        }

        nm.createNotificationChannel(newOrder)
        nm.createNotificationChannel(payment)
    }

    private fun rawUri(name: String): Uri =
        Uri.parse("android.resource://$packageName/raw/$name")

    companion object {
        const val CHANNEL_NEW_ORDER = "new_order_v1"
        const val CHANNEL_PAYMENT = "payment_v1"
    }
}
