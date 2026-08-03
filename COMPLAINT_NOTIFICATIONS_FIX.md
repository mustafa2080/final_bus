# إصلاح مشكلة إشعارات الشكاوى في صفحة ولي الأمر

## المشكلة
كانت إشعارات الشكاوى تظهر في قائمة الإشعارات لكن عند الضغط عليها:
- لا تعطي تفاصيل واضحة
- لا تُحدد كمقروءة
- لا يوجد تفاعل واضح مع المستخدم

## الحل المطبق

### 1. إضافة معالج للضغط على الإشعارات
تم إضافة `InkWell` حول كل إشعار مع دالة `_handleNotificationTap` التي:
- تحدد الإشعار كمقروء تلقائياً عند الضغط عليه
- تفرق بين إشعارات الشكاوى والإشعارات الأخرى
- إشعارات الشكاوى: تنقل المستخدم إلى صفحة الشكاوى مباشرة
- الإشعارات الأخرى: تعرض حوار بالتفاصيل الكاملة

### 2. إضافة ألوان وأيقونات مخصصة للشكاوى

#### الألوان:
- **complaintSubmitted**: أحمر (`#E53E3E`) - للشكوى الجديدة
- **complaintResponded**: أخضر (`#38A169`) - للرد على الشكوى

#### الأيقونات:
- **complaintSubmitted**: `Icons.feedback` - للشكوى الجديدة
- **complaintResponded**: `Icons.mark_chat_read` - للرد على الشكوى

### 3. تحديث نظام تحليل أنواع الإشعارات
تم تحديث `NotificationModel._parseNotificationType()` لتتعرف على:
- `complaintSubmitted`
- `complaintResponded`

### 4. إزالة زر "تحديد كمقروء" الزائد
تم حذف الزر من الحوار لأن الإشعار يُحدد تلقائياً عند فتحه.

## الملفات المعدلة

1. **lib/screens/parent/parent_notifications_screen.dart**
   - إضافة `InkWell` للبطاقات
   - إضافة دالة `_handleNotificationTap()`
   - تحديث `_getNotificationColor()` 
   - تحديث `_getNotificationIcon()`
   - تبسيط `_showFullNotificationDialog()`

2. **lib/models/notification_model.dart**
   - تحديث `_parseNotificationType()` لإضافة أنواع الشكاوى

## كيفية الاستخدام

### للمستخدم (ولي الأمر):
1. افتح صفحة الإشعارات
2. إشعارات الشكاوى ستظهر بألوان مميزة:
   - أحمر للشكاوى الجديدة
   - أخضر للردود على الشكاوى
3. اضغط على أي إشعار شكوى:
   - سيتم تحديده كمقروء تلقائياً
   - سيتم نقلك إلى صفحة الشكاوى لرؤية التفاصيل الكاملة

### للمطورين:
```dart
// مثال على إنشاء إشعار شكوى جديدة
NotificationModel notification = NotificationModel(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: 'شكوى جديدة',
  body: 'تم تقديم شكوى جديدة',
  recipientId: parentId,
  type: NotificationType.complaintSubmitted,
  timestamp: DateTime.now(),
  isRead: false,
);

// مثال على إنشاء إشعار رد على شكوى
NotificationModel notification = NotificationModel(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: 'رد على شكوى',
  body: 'تم الرد على شكواك',
  recipientId: parentId,
  type: NotificationType.complaintResponded,
  timestamp: DateTime.now(),
  isRead: false,
);
```

## الميزات الجديدة

✅ الضغط على الإشعار يحدده كمقروء تلقائياً
✅ إشعارات الشكاوى تنقل للصفحة الصحيحة مباشرة
✅ ألوان وأيقونات مميزة لإشعارات الشكاوى
✅ تجربة مستخدم محسّنة وأكثر وضوحاً
✅ لا حاجة لأزرار إضافية غير ضرورية

## اختبار التعديلات

1. قم بتشغيل التطبيق
2. سجل دخول كولي أمر
3. أرسل شكوى جديدة من صفحة الشكاوى
4. انتظر رد الإدارة على الشكوى
5. افتح صفحة الإشعارات
6. تحقق من:
   - ظهور الإشعار بالألوان الصحيحة
   - الضغط على الإشعار يحدده كمقروء
   - الضغط على الإشعار ينقلك لصفحة الشكاوى
   - تظهر تفاصيل الشكوى بشكل صحيح

## ملاحظات مهمة

- تأكد من أن مسار التوجيه `/parent/complaints` موجود في GoRouter
- الإشعارات الأخرى (غير الشكاوى) لا تزال تعمل بنفس الطريقة القديمة
- يمكن توسيع هذا النظام لأنواع أخرى من الإشعارات مستقبلاً

## تاريخ التعديل
التاريخ: 05/10/2025
المطور: Claude AI Assistant
