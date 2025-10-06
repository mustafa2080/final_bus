import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

/// Extension to add missing notification methods to DatabaseService
class NotificationDatabaseFix {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get parent notifications stream
  Stream<List<NotificationModel>> getParentNotifications(String parentId) {
    debugPrint('🔔 Getting notifications for parent: $parentId');
    
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: parentId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          debugPrint('📬 Found ${snapshot.docs.length} notifications for parent $parentId');
          
          return snapshot.docs.map((doc) {
            try {
              final data = doc.data();
              data['id'] = doc.id; // Ensure ID is included
              
              debugPrint('📧 Notification: ${data['title']} - isRead: ${data['isRead']}');
              
              return NotificationModel.fromMap(data);
            } catch (e) {
              debugPrint('❌ Error parsing notification ${doc.id}: $e');
              return null;
            }
          })
          .where((notification) => notification != null)
          .cast<NotificationModel>()
          .toList();
        })
        .handleError((error) {
          debugPrint('❌ Error in getParentNotifications: $error');
          return <NotificationModel>[];
        });
  }

  /// Get unread notifications count stream
  Stream<int> getParentNotificationsCount(String parentId) {
    debugPrint('🔢 Getting unread notifications count for parent: $parentId');
    
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: parentId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.docs.length;
          debugPrint('📊 Unread notifications count: $count');
          return count;
        })
        .handleError((error) {
          debugPrint('❌ Error in getParentNotificationsCount: $error');
          return 0;
        });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      debugPrint('✅ Marking notification as read: $notificationId');
      
      // Check if notification exists first
      final notificationDoc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (!notificationDoc.exists) {
        debugPrint('❌ Notification document not found: $notificationId');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Notification document does not exist',
        );
      }
      
      // Update notification to mark as read
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('✅ Notification marked as read successfully: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      throw e;
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      debugPrint('✅ Marking all notifications as read for user: $userId');
      
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (unreadNotifications.docs.isEmpty) {
        debugPrint('ℹ️ No unread notifications to mark');
        return;
      }
      
      final batch = _firestore.batch();
      
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      debugPrint('✅ Marked ${unreadNotifications.docs.length} notifications as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      throw e;
    }
  }

  /// Fix existing notifications - ensures all required fields exist
  Future<void> fixExistingNotifications() async {
    try {
      debugPrint('🔧 Starting to fix existing notifications...');
      
      final notifications = await _firestore
          .collection('notifications')
          .get();
      
      debugPrint('📊 Found ${notifications.docs.length} total notifications');
      
      final batch = _firestore.batch();
      int fixedCount = 0;
      
      for (final doc in notifications.docs) {
        final data = doc.data();
        final Map<String, dynamic> updates = {};
        
        // Ensure isRead field exists
        if (!data.containsKey('isRead')) {
          updates['isRead'] = false;
          fixedCount++;
        }
        
        // Ensure timestamp field exists
        if (!data.containsKey('timestamp')) {
          updates['timestamp'] = data['createdAt'] ?? FieldValue.serverTimestamp();
          fixedCount++;
        }
        
        // Ensure body field exists (use message or description as fallback)
        if (!data.containsKey('body') || (data['body'] as String?)?.isEmpty == true) {
          updates['body'] = data['message'] ?? data['description'] ?? 'إشعار جديد';
          fixedCount++;
        }
        
        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
        }
      }
      
      if (fixedCount > 0) {
        await batch.commit();
        debugPrint('✅ Fixed $fixedCount notification fields');
      } else {
        debugPrint('ℹ️ No notifications need fixing');
      }
    } catch (e) {
      debugPrint('❌ Error fixing notifications: $e');
      throw e;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      debugPrint('🗑️ Deleting notification: $notificationId');
      
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      debugPrint('✅ Notification deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      throw e;
    }
  }

  /// Get notification by ID
  Future<NotificationModel?> getNotificationById(String notificationId) async {
    try {
      debugPrint('🔍 Getting notification by ID: $notificationId');
      
      final doc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (!doc.exists) {
        debugPrint('⚠️ Notification not found: $notificationId');
        return null;
      }
      
      final data = doc.data()!;
      data['id'] = doc.id;
      
      return NotificationModel.fromMap(data);
    } catch (e) {
      debugPrint('❌ Error getting notification: $e');
      return null;
    }
  }
}
