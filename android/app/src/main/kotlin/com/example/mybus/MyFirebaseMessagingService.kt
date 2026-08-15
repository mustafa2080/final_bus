package com.example.mybus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlin.random.Random

/**
 * خدمة استقبال رسائل FCM في الخلفية (background / killed) وعرضها كإشعار نظام.
 *
 * الباك إند (backend/utils/sendNotification.js) يرسل الرسائل كـ data-only
 * message (بدون notification key) عمدًا، حتى لا يعرض نظام التشغيل نسخة
 * تلقائية بجانب النسخة اللي بيعرضها SimpleFCMService في foreground، فيحصل
 * تكرار. بمعنى: هذه الخدمة هي المسؤول الوحيد عن عرض الإشعار وقت ما يكون
 * التطبيق في الخلفية أو مغلق تمامًا. في foreground، SimpleFCMService
 * (Flutter) هو اللي بيعرض الإشعار عن طريق flutter_local_notifications.
 */
class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // مفيش أي معالجة لازمة لو التطبيق كان فاتح فورجراوند وقت الاستلام؛
        // Flutter (SimpleFCMService) بيتكفل بالعرض في الحالة دي. الخدمة دي
        // بتشتغل أساسًا وقت ما Flutter engine مش شغال (background/killed).
        val data = remoteMessage.data
        if (data.isEmpty()) return

        val title = data["title"] ?: remoteMessage.notification?.title ?: "إشعار جديد"
        val body = data["body"] ?: remoteMessage.notification?.body ?: ""
        val channelId = data["channelId"] ?: "mybus_notifications"
        val colorHex = data["color"]

        showNotification(title, body, channelId, colorHex, data)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // تحديث الـ token بيتم من Flutter (SimpleFCMService._listenToTokenRefresh)
        // عن طريق FirebaseMessaging.instance.onTokenRefresh، فلا داعي لتكرار
        // منطق الحفظ هنا.
    }

    private fun showNotification(
        title: String,
        body: String,
        channelId: String,
        colorHex: String?,
        data: Map<String, String>,
    ) {
        val notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        ensureChannelExists(notificationManager, channelId)

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "FLUTTER_NOTIFICATION_CLICK"
            data.forEach { (key, value) -> putExtra(key, value) }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            Random.nextInt(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val color = try {
            if (colorHex != null) Color.parseColor(colorHex) else Color.parseColor("#1E88E5")
        } catch (e: IllegalArgumentException) {
            Color.parseColor("#1E88E5")
        }

        val largeIcon = try {
            BitmapFactory.decodeResource(resources, R.mipmap.launcher_icon)
        } catch (e: Exception) {
            null
        }

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setColor(color)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 400, 200, 400))
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (largeIcon != null) {
            builder.setLargeIcon(largeIcon)
        }

        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, builder.build())
    }

    /**
     * ينشئ القناة عند الحاجة فقط (احتياطًا)، حتى لو الإشعار وصل لجهاز لسه
     * ما فتحش التطبيق قبل كده ومروّتش عليه القنوات المسجلة في MainActivity
     * أو SimpleFCMService.
     */
    private fun ensureChannelExists(notificationManager: NotificationManager, channelId: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (notificationManager.getNotificationChannel(channelId) != null) return

        val (name, description, importance) = when (channelId) {
            "student_notifications" -> Triple(
                "إشعارات الطلاب", "إشعارات متعلقة بالطلاب وأنشطتهم", NotificationManager.IMPORTANCE_HIGH
            )
            "bus_notifications" -> Triple(
                "إشعارات الباص", "إشعارات ركوب ونزول الباص", NotificationManager.IMPORTANCE_HIGH
            )
            "emergency_notifications" -> Triple(
                "تنبيهات الطوارئ", "تنبيهات طوارئ مهمة وعاجلة", NotificationManager.IMPORTANCE_HIGH
            )
            "complaints_channel" -> Triple(
                "إشعارات الشكاوى", "إشعارات متعلقة بالشكاوى وردودها", NotificationManager.IMPORTANCE_HIGH
            )
            else -> Triple(
                "كيدز باص - الإشعارات العامة", "إشعارات عامة من تطبيق كيدز باص", NotificationManager.IMPORTANCE_HIGH
            )
        }

        val channel = NotificationChannel(channelId, name, importance).apply {
            this.description = description
            enableVibration(true)
            enableLights(true)
            lightColor = Color.parseColor("#1E88E5")
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }
}
