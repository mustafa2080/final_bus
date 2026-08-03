package com.example.mybus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "MyFirebaseMsgService"
        private const val CHANNEL_ID = "mybus_notifications"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "==============================================")
        Log.d(TAG, "📱 FCM Message received from: ${remoteMessage.from}")
        Log.d(TAG, "📱 Message ID: ${remoteMessage.messageId}")
        Log.d(TAG, "📱 Message sent time: ${remoteMessage.sentTime}")
        Log.d(TAG, "==============================================")

        // Log all data for debugging
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "📦 Message data payload:")
            remoteMessage.data.forEach { (key, value) ->
                Log.d(TAG, "   $key: $value")
            }
        }

        // Log notification payload if exists
        remoteMessage.notification?.let {
            Log.d(TAG, "🔔 Notification payload:")
            Log.d(TAG, "   Title: ${it.title}")
            Log.d(TAG, "   Body: ${it.body}")
            Log.d(TAG, "   Sound: ${it.sound}")
            Log.d(TAG, "   ChannelId: ${it.channelId}")
        }

        // Extract title and body
        var title = "إشعار جديد"
        var body = "لديك إشعار جديد"

        // Priority 1: Use notification payload if exists
        remoteMessage.notification?.let { notification ->
            Log.d(TAG, "✅ Using notification payload")
            title = notification.title ?: title
            body = notification.body ?: body
        }

        // Priority 2: Use data payload if no notification payload
        if (remoteMessage.notification == null && remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "✅ Using data payload")
            title = remoteMessage.data["title"] ?: title
            body = remoteMessage.data["body"] ?: body
        }

        Log.d(TAG, "📤 Final notification:")
        Log.d(TAG, "   Title: $title")
        Log.d(TAG, "   Body: $body")

        // CRITICAL: Always send notification regardless of app state
        try {
            sendNotification(title, body, remoteMessage.data)
            Log.d(TAG, "✅ Notification sent successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send notification: ${e.message}", e)
        }

        Log.d(TAG, "==============================================")
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "🔄 FCM Token refreshed")
        Log.d(TAG, "Token: ${token.substring(0, 20)}...")
        sendRegistrationToServer(token)
    }

    private fun sendRegistrationToServer(token: String?) {
        Log.d(TAG, "📤 Sending token to server: ${token?.substring(0, 20)}...")
        // TODO: Send token to your server
    }

    private fun sendNotification(title: String, messageBody: String, data: Map<String, String>) {
        Log.d(TAG, "🔨 Creating notification...")

        try {
            // Create intent to open app
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                
                // Add all data to intent
                data.forEach { (key, value) ->
                    putExtra(key, value)
                }
            }

            // Create pending intent
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_ONE_SHOT
            }

            val pendingIntent = PendingIntent.getActivity(
                this, 
                System.currentTimeMillis().toInt(), 
                intent, 
                pendingIntentFlags
            )

            // Get notification sound
            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            // Determine channel ID
            val channelId = data["channelId"] ?: data["channel_id"] ?: CHANNEL_ID
            Log.d(TAG, "📺 Using channel: $channelId")

            // Create notification builder with ALL features enabled
            val notificationBuilder = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(messageBody)
                .setAutoCancel(true)
                .setSound(defaultSoundUri)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_MAX) // MAXIMUM priority
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setDefaults(NotificationCompat.DEFAULT_ALL) // All defaults
                .setVibrate(longArrayOf(0, 1000, 500, 1000)) // Vibration pattern
                .setLights(0xFF1E88E5.toInt(), 3000, 3000) // LED lights
                .setStyle(NotificationCompat.BigTextStyle().bigText(messageBody)) // Big text style
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis())
                .setOnlyAlertOnce(false) // Always alert
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // Show on lock screen
                .setFullScreenIntent(pendingIntent, false) // Full screen on high priority

            // Get notification manager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Create notification channels for Android O+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                createAllNotificationChannels(notificationManager)
            }

            // Generate unique notification ID
            val notificationId = System.currentTimeMillis().toInt()

            // Display notification
            notificationManager.notify(notificationId, notificationBuilder.build())

            Log.d(TAG, "✅ Notification displayed successfully!")
            Log.d(TAG, "   ID: $notificationId")
            Log.d(TAG, "   Title: $title")
            Log.d(TAG, "   Channel: $channelId")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating/displaying notification", e)
            Log.e(TAG, "Error details: ${e.message}")
            Log.e(TAG, "Stack trace:", e)
        }
    }

    private fun createAllNotificationChannels(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Log.d(TAG, "🔧 Creating notification channels for Android O+...")

            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            // Main channel
            val mainChannel = NotificationChannel(
                CHANNEL_ID,
                "إشعارات كيدز باص",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات عامة من تطبيق كيدز باص"
                enableLights(true)
                lightColor = 0xFF1E88E5.toInt()
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                setSound(defaultSoundUri, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(false)
            }

            // Student notifications channel
            val studentChannel = NotificationChannel(
                "student_notifications",
                "إشعارات الطلاب",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات متعلقة بالطلاب وأنشطتهم"
                enableLights(true)
                lightColor = 0xFF4CAF50.toInt()
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                setSound(defaultSoundUri, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            // Bus notifications channel
            val busChannel = NotificationChannel(
                "bus_notifications",
                "إشعارات الباص",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات ركوب ونزول الباص"
                enableLights(true)
                lightColor = 0xFFFF9800.toInt()
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                setSound(defaultSoundUri, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            // Emergency notifications channel
            val emergencyChannel = NotificationChannel(
                "emergency_notifications",
                "تنبيهات الطوارئ",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "تنبيهات طوارئ مهمة وعاجلة"
                enableLights(true)
                lightColor = 0xFFF44336.toInt()
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setSound(defaultSoundUri, audioAttributes)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Bypass Do Not Disturb
            }

            // Create all channels
            notificationManager.createNotificationChannel(mainChannel)
            notificationManager.createNotificationChannel(studentChannel)
            notificationManager.createNotificationChannel(busChannel)
            notificationManager.createNotificationChannel(emergencyChannel)

            Log.d(TAG, "✅ All notification channels created successfully")
        }
    }

    override fun onDeletedMessages() {
        super.onDeletedMessages()
        Log.d(TAG, "⚠️ Some messages were deleted on the server")
    }

    override fun onMessageSent(msgId: String) {
        super.onMessageSent(msgId)
        Log.d(TAG, "✅ Message sent successfully: $msgId")
    }

    override fun onSendError(msgId: String, exception: Exception) {
        super.onSendError(msgId, exception)
        Log.e(TAG, "❌ Error sending message $msgId: ${exception.message}", exception)
    }
}
