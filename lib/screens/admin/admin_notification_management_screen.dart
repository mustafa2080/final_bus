import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/unified_notification_service.dart';
import '../../services/global_notification_monitor.dart';

/// شاشة إدارة الإشعارات للمدير
class AdminNotificationManagementScreen extends StatefulWidget {
  const AdminNotificationManagementScreen({super.key});

  @override
  State<AdminNotificationManagementScreen> createState() => _AdminNotificationManagementScreenState();
}

class _AdminNotificationManagementScreenState extends State<AdminNotificationManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final UnifiedNotificationService _notificationService = UnifiedNotificationService();
  final GlobalNotificationMonitor _monitor = GlobalNotificationMonitor();
  
  bool _isLoading = false;
  Map<String, int> _queueStats = {};
  Map<String, dynamic> _systemReport = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await _monitor.getQueueStats();
      final report = await _monitor.generateQueueReport();
      
      setState(() {
        _queueStats = stats;
        _systemReport = report;
      });
    } catch (e) {
      print('خطأ في تحميل الإحصائيات: $e');
      _showErrorSnackBar('فشل في تحميل الإحصائيات');
    }
    
    setState(() => _isLoading = false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الإشعارات'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.send), text: 'إرسال'),
            Tab(icon: Icon(Icons.analytics), text: 'الإحصائيات'),
            Tab(icon: Icon(Icons.queue), text: 'الطابور'),
            Tab(icon: Icon(Icons.settings), text: 'الإعدادات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendNotificationTab(),
          _buildStatisticsTab(),
          _buildQueueTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // تبويب إرسال الإشعارات
  Widget _buildSendNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuickNotificationCard(),
          const SizedBox(height: 16),
          _buildBulkNotificationCard(),
          const SizedBox(height: 16),
          _buildScheduledNotificationCard(),
        ],
      ),
    );
  }

  // كارت الإشعار السريع
  Widget _buildQuickNotificationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إرسال إشعار سريع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickNotificationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNotificationButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickButton(
          'إشعار للكل',
          Icons.campaign,
          Colors.blue,
          () => _showSendNotificationDialog('all'),
        ),
        _buildQuickButton(
          'للمشرفين',
          Icons.supervisor_account,
          Colors.indigo,
          () => _showSendNotificationDialog('supervisor'),
        ),
        _buildQuickButton(
          'لأولياء الأمور',
          Icons.family_restroom,
          Colors.teal,
          () => _showSendNotificationDialog('parent'),
        ),
        _buildQuickButton(
          'طوارئ',
          Icons.warning,
          Colors.red,
          () => _showSendNotificationDialog('emergency'),
        ),
      ],
    );
  }

  Widget _buildQuickButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // باقي المحتوى... (سأضع الباقي في التحديث التالي نظراً لطول الملف)

  // الحوارات والوظائف المساعدة
  
  void _showSendNotificationDialog(String type) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedType = type == 'all' ? 'general' : type;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إرسال إشعار ${_getTypeDisplayName(type)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'المحتوى',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || bodyController.text.isEmpty) {
                _showErrorSnackBar('يرجى ملء جميع الحقول');
                return;
              }
              
              Navigator.pop(context);
              await _sendNotification(
                type: selectedType,
                title: titleController.text,
                body: bodyController.text,
                targetType: type,
              );
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification({
    required String type,
    required String title,
    required String body,
    required String targetType,
  }) async {
    setState(() => _isLoading = true);
    
    try {
      int sentCount = 0;
      
      if (targetType == 'all') {
        // إرسال للجميع
        final roles = ['admin', 'supervisor', 'parent'];
        for (String role in roles) {
          final count = await _notificationService.sendNotificationByRole(
            role: role,
            title: title,
            body: body,
            type: type,
          );
          sentCount += count;
        }
      } else {
        // إرسال لدور محدد
        sentCount = await _notificationService.sendNotificationByRole(
          role: targetType,
          title: title,
          body: body,
          type: type,
        );
      }
      
      _showSuccessSnackBar('تم إرسال $sentCount إشعار بنجاح');
      _loadStats(); // تحديث الإحصائيات
    } catch (e) {
      _showErrorSnackBar('فشل في إرسال الإشعار: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testNotificationSystem() async {
    setState(() => _isLoading = true);
    
    try {
      // إرسال إشعار تجريبي للمدير الحالي
      await _notificationService.showLocalNotification(
        title: 'اختبار النظام ✅',
        body: 'هذا إشعار تجريبي للتأكد من عمل النظام بشكل صحيح',
        channelId: UnifiedNotificationService.channelAdmin,
        data: {
          'type': 'test',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      _showSuccessSnackBar('تم إرسال الإشعار التجريبي بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل الاختبار: $e');
    }
    
    setState(() => _isLoading = false);
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'all':
        return 'للجميع';
      case 'supervisor':
        return 'للمشرفين';
      case 'parent':
        return 'لأولياء الأمور';
      case 'emergency':
        return 'طوارئ';
      default:
        return 'عام';
    }
  }

  // الوظائف المؤقتة (ستتم إضافة التفاصيل لاحقاً)
  Widget _buildBulkNotificationCard() => const Card(child: Text('إشعارات جماعية - قيد التطوير'));
  Widget _buildScheduledNotificationCard() => const Card(child: Text('إشعارات مجدولة - قيد التطوير'));
  Widget _buildStatisticsTab() => const Center(child: Text('الإحصائيات - قيد التطوير'));
  Widget _buildQueueTab() => const Center(child: Text('الطابور - قيد التطوير'));
  Widget _buildSettingsTab() => const Center(child: Text('الإعدادات - قيد التطوير'));
}
