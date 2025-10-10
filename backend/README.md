# MyBus Backend Server 🚌

Backend server for MyBus tracking system with real-time notifications and Socket.IO support.

## Features 🌟

- ✅ Firebase Admin SDK integration
- ✅ Real-time bus tracking with Socket.IO
- ✅ FCM push notifications
- ✅ REST API endpoints
- ✅ Firestore listeners for automatic notifications
- ✅ CORS support

## Prerequisites 📋

- Node.js 14+ 
- Firebase Project
- Service Account Key from Firebase

## Local Development 🔧

### 1. Install Dependencies

```bash
npm install
```

### 2. Setup Environment Variables

Create a `.env` file:

```bash
cp .env.example .env
```

Edit `.env` and add:

```env
FIREBASE_DATABASE_URL=https://mybus-5a992.firebaseio.com
PORT=3000
ALLOWED_ORIGINS=*
```

### 3. Add Service Account Key

Get your `serviceAccountKey.json` from:
- Firebase Console → Project Settings → Service Accounts → Generate New Private Key

Place the file in the `backend` folder.

### 4. Run Development Server

```bash
npm run dev
```

Or production mode:

```bash
npm start
```

## Deployment to Railway 🚀

### Method 1: GitHub (Recommended)

1. **Push to GitHub:**
   ```bash
   git add .
   git commit -m "Backend ready for Railway"
   git push origin main
   ```

2. **Connect Railway:**
   - Go to [railway.app](https://railway.app)
   - Click "New Project" → "Deploy from GitHub"
   - Select your repo and `backend` folder

3. **Add Environment Variables in Railway:**
   ```
   FIREBASE_DATABASE_URL=https://mybus-5a992.firebaseio.com
   PORT=${{PORT}}
   ALLOWED_ORIGINS=https://your-frontend-url.com
   SERVICE_ACCOUNT_KEY=<paste entire serviceAccountKey.json content here>
   ```

### Method 2: Railway CLI

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize and deploy
cd backend
railway init
railway up

# Add environment variables
railway variables set FIREBASE_DATABASE_URL="https://mybus-5a992.firebaseio.com"
railway variables set SERVICE_ACCOUNT_KEY="<paste content>"
```

## Environment Variables 🔐

| Variable | Description | Required |
|----------|-------------|----------|
| `FIREBASE_DATABASE_URL` | Firebase Realtime Database URL | ✅ Yes |
| `PORT` | Server port (auto-assigned in Railway) | ✅ Yes |
| `SERVICE_ACCOUNT_KEY` | Firebase service account JSON (as string) | ✅ Yes (Production) |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | ⚠️ Recommended |

## API Endpoints 📡

### Health Check
```
GET /health
```

### Logout (Delete FCM Token)
```
POST /api/logout
Body: { "userId": "user123" }
```

### Update FCM Token
```
POST /api/updateToken
Body: { 
  "userId": "user123",
  "fcmToken": "fcm_token_here"
}
```

## Socket.IO Events 🔌

### Supervisor Events
- `supervisor:startTracking` - Start bus tracking
- `supervisor:updateLocation` - Update bus location
- `supervisor:stopTracking` - Stop bus tracking

### Parent Events
- `parent:subscribeToBus` - Subscribe to bus tracking
- `parent:unsubscribeFromBus` - Unsubscribe from bus
- `bus:locationUpdate` - Receive location updates
- `bus:trackingStarted` - Bus tracking started
- `bus:trackingStopped` - Bus tracking stopped

## Firestore Listeners 👀

The server automatically listens to:
1. **fcm_queue** - Send FCM notifications
2. **trips** - Student trip updates
3. **absences** - Absence requests
4. **complaints** - Parent complaints
5. **students** - Student data updates

## Security Notes 🔒

- ⚠️ **NEVER** commit `serviceAccountKey.json` to Git
- ⚠️ Use `.gitignore` to exclude sensitive files
- ⚠️ Use environment variables for production
- ⚠️ Configure CORS properly for production

## Troubleshooting 🔍

### Common Issues

**1. Firebase Admin SDK Error**
- Check `SERVICE_ACCOUNT_KEY` is valid JSON
- Verify Firebase project permissions

**2. Port Already in Use**
- Change `PORT` in `.env`
- Kill existing process: `kill -9 $(lsof -ti:3000)`

**3. FCM Notifications Not Sending**
- Verify FCM tokens are valid
- Check Firestore Rules allow read/write
- Ensure service account has FCM permissions

## License 📄

Private project - All rights reserved
