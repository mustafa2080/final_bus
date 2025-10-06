# خطوات نشر Backend على Railway

## 1️⃣ تجهيز المشروع

### إضافة ملف `railway.json`:
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "node index.js",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### تعديل `.env` (سيتم رفعه كـ Environment Variables):
```env
FIREBASE_DATABASE_URL=https://mybus-5a992.firebaseio.com
SERVICE_ACCOUNT_KEY={"type":"service_account",...}
```

---

## 2️⃣ خطوات النشر على Railway

### الطريقة 1: من خلال GitHub (الأسهل)

1. **سجل في Railway:**
   - اذهب إلى https://railway.app
   - سجل باستخدام GitHub

2. **أنشئ مشروع جديد:**
   - اضغط "New Project"
   - اختر "Deploy from GitHub repo"
   - اختر repository الخاص بـ mybus

3. **إعداد Environment Variables:**
   - اذهب إلى Settings → Variables
   - أضف:
     ```
     FIREBASE_DATABASE_URL=https://mybus-5a992.firebaseio.com
     SERVICE_ACCOUNT_KEY=<محتوى serviceAccountKey.json كامل>
     ```

4. **Deploy:**
   - Railway سيبدأ في بناء ونشر السيرفر تلقائياً
   - انتظر حتى يصبح Status "Active"

---

## 3️⃣ خطوات النشر على Render

1. **سجل في Render:**
   - اذهب إلى https://render.com
   - سجل باستخدام GitHub

2. **أنشئ Web Service:**
   - اضغط "New +" → "Web Service"
   - اختر repository الخاص بـ mybus/backend
   - املأ البيانات:
     - Name: mybus-backend
     - Environment: Node
     - Build Command: `npm install`
     - Start Command: `node index.js`

3. **إعداد Environment Variables:**
   - في صفحة الإعدادات، أضف:
     ```
     FIREBASE_DATABASE_URL=https://mybus-5a992.firebaseio.com
     SERVICE_ACCOUNT_KEY=<محتوى serviceAccountKey.json>
     ```

4. **Deploy:**
   - اضغط "Create Web Service"
   - Render سيبدأ في النشر تلقائياً

---

## 4️⃣ خطوات النشر على VPS (DigitalOcean مثلاً)

### إنشاء Droplet:
```bash
1. سجل في DigitalOcean.com
2. أنشئ Droplet جديد:
   - OS: Ubuntu 22.04 LTS
   - Plan: Basic ($5/month)
   - Region: قريب من موقعك
```

### الاتصال بالسيرفر:
```bash
ssh root@your-server-ip
```

### تثبيت Node.js:
```bash
# تحديث النظام
apt update && apt upgrade -y

# تثبيت Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# التحقق من التثبيت
node -v
npm -v
```

### رفع المشروع:
```bash
# تثبيت Git
apt install -y git

# استنساخ المشروع
cd /opt
git clone https://github.com/your-username/mybus.git
cd mybus/backend

# تثبيت Dependencies
npm install

# إعداد .env
nano .env
# الصق محتوى .env واحفظ (Ctrl+X → Y → Enter)

# إعداد serviceAccountKey.json
nano serviceAccountKey.json
# الصق محتوى الملف واحفظ
```

### تشغيل السيرفر بشكل دائم باستخدام PM2:
```bash
# تثبيت PM2
npm install -g pm2

# تشغيل السيرفر
pm2 start index.js --name mybus-backend

# جعل PM2 يعمل عند إعادة التشغيل
pm2 startup
pm2 save

# مراقبة السيرفر
pm2 logs mybus-backend
pm2 status
```

---

## 5️⃣ التحقق من عمل السيرفر

### بعد النشر، تحقق من:

1. **السيرفر يعمل:**
   ```bash
   # في Railway/Render: شوف Logs
   # في VPS:
   pm2 logs mybus-backend
   ```

2. **الإشعارات تصل:**
   - جرب إرسال شكوى من التطبيق
   - شوف اللوجات في السيرفر
   - تأكد من وصول الإشعار

---

## 6️⃣ المميزات حسب الخدمة

| الخدمة | السعر | المميزات | العيوب |
|--------|-------|----------|--------|
| **Railway** | مجاني للبداية | سهل جداً، Auto-deploy | محدود في الموارد المجانية |
| **Render** | مجاني | موثوق، سهل | قد ينام بعد عدم الاستخدام |
| **VPS** | $5/شهر | تحكم كامل، أداء ممتاز | يحتاج خبرة |
| **AWS EC2** | مجاني أول سنة | احترافي، قابل للتوسع | معقد للمبتدئين |

---

## 🎯 التوصية:

### للتجربة والتطوير:
✅ **Railway** أو **Render** (مجاني وسهل)

### للإنتاج الفعلي:
✅ **VPS** (DigitalOcean/Vultr) - $5/شهر
- أداء ثابت
- تحكم كامل
- لا توقف

---

## 📊 ملخص:

✅ السيرفر المحلي يعمل مع التطبيق في أي بلد  
⚠️ لكن يحتاج لعمل 24/7  
🚀 الحل الأمثل: نشر على Railway أو VPS  
💰 Railway مجاني للبداية، VPS $5/شهر للاحترافية
