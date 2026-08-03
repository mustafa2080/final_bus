// إضافة هذه الدوال إلى database_service.dart في النهاية قبل آخر قوس

  /// Get parent notifications
  Stream<List<NotificationModel>> getParentNotifications(String parentId) {
    if (parentId.isEmpty) {
      return Stream.value([]);
    }

    debugPrint('🔔 Getting notifications for parent: $parentId');

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: parentId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          debugPrint('📊 Found ${snapshot.docs.length} notifications for parent');
          return snapshot.docs
              .map((doc) {
                try {
                  final notification = NotificationModel.fromMap(doc.data());
                  debugPrint('🔔 Notification: ${notification.title} - Type: ${notification.type} - Body length: ${notification.body.length}');
                  return notification;
                } catch (e) {
                  debugPrint('❌ Error parsing notification: $e');
                  debugPrint('📄 Document data: ${doc.data()}');
                  return null;
                }
              })
              .where((notification) => notification != null)
              .cast<NotificationModel>()
              .toList();
        });
  }

  /// Get parent notifications count (unread only)
  Stream<int> getParentNotificationsCount(String parentId) {
    if (parentId.isEmpty) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: parentId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark all parent notifications as read
  Future<void> markAllParentNotificationsAsRead(String parentId) async {
    try {
      debugPrint('📧 Marking all notifications as read for parent: $parentId');

      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: parentId)
          .where('isRead', isEqualTo: false)
          .get();

      debugPrint('📊 Found ${snapshot.docs.length} unread notifications');

      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ No unread notifications to mark');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      debugPrint('✅ All notifications marked as read for parent $parentId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Fix existing notifications (add missing body field)
  Future<void> fixExistingNotifications() async {
    try {
      debugPrint('🔧 Fixing existing notifications...');

      final snapshot = await _firestore.collection('notifications').get();
      debugPrint('📊 Found ${snapshot.docs.length} notifications to check');

      int fixedCount = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final body = data['body'] ?? '';

        // إذا كان body فارغ ولكن هناك message في data
        if (body.isEmpty && data['data'] != null) {
          final dataMap = data['data'] as Map<String, dynamic>?;
          if (dataMap != null) {
            final message = dataMap['message'] ?? dataMap['body'] ?? '';
            if (message.isNotEmpty) {
              batch.update(doc.reference, {'body': message});
              fixedCount++;
              debugPrint('🔧 Fixed notification ${doc.id}: added body from data.message');
            }
          }
        }

        // Commit batch every 500 operations (Firestore limit)
        if (fixedCount % 500 == 0 && fixedCount > 0) {
          await batch.commit();
          debugPrint('✅ Committed batch of 500 fixes');
        }
      }

      // Commit remaining operations
      if (fixedCount % 500 != 0) {
        await batch.commit();
      }

      debugPrint('✅ Fixed $fixedCount notifications');
    } catch (e) {
      debugPrint('❌ Error fixing notifications: $e');
      rethrow;
    }
  }
