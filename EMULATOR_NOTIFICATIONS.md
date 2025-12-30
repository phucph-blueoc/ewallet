# Push Notifications on Android Emulators

## Why Notifications Don't Work on Most Emulators

Firebase Cloud Messaging (FCM) requires **Google Play Services** to work. Most Android emulators created with standard AVD images **do not include Google Play Services**, which means:

- ❌ FCM tokens cannot be generated
- ❌ Push notifications cannot be received
- ❌ The app will silently fail when trying to get FCM tokens

## Solutions

### Option 1: Use an Emulator with Google Play Services (Recommended for Testing)

1. **Create a new AVD with Google APIs:**
   - Open Android Studio → Tools → Device Manager
   - Click "Create Device"
   - Select a device (e.g., Pixel 5)
   - **Important:** Select a system image that shows **"Google APIs"** or **"Google Play"** (not just "x86 Images")
   - Examples:
     - ✅ `Tiramisu API 33 (Google APIs)`
     - ✅ `Tiramisu API 33 (Google Play)`
     - ❌ `Tiramisu API 33` (without Google APIs)

2. **Verify Google Play Services:**
   - After emulator boots, check if Google Play Store is available
   - If Play Store exists, Google Play Services is installed

3. **Test FCM:**
   - Run the app and check logs for "FCM Token: ..."
   - If you see a token, notifications should work

### Option 2: Test on a Physical Device (Most Reliable)

Physical Android devices always have Google Play Services:
- ✅ Guaranteed to work
- ✅ Real-world testing environment
- ✅ Better performance

### Option 3: Check Current Emulator Setup

**Check if your current emulator has Google Play Services:**

```bash
# Run this in your emulator's adb shell
adb shell pm list packages | grep -i "google"
```

If you see packages like:
- `com.google.android.gms` (Google Play Services)
- `com.android.vending` (Google Play Store)

Then your emulator has Google Play Services and should work.

## Debugging FCM on Emulators

### Check Logs

When the app starts, look for these logs in Flutter:

```
✅ Good signs:
- "Firebase initialized successfully"
- "FCM Token: <long-token-string>"
- "FCM token registered with backend"

❌ Bad signs:
- "FCM token is null"
- "Failed to get FCM token"
- "ERROR: Failed to get FCM token"
```

### Manual Token Check

1. Open the app in emulator
2. Login to your account
3. Check Flutter logs for FCM token
4. If token is null, the emulator doesn't have Google Play Services

### Verify Backend Registration

Check if the token was registered with backend:

```bash
# Connect to your database and check
SELECT device_token FROM notification_settings WHERE user_id = 'your-user-id';
```

If `device_token` is NULL or empty, the token wasn't registered (likely because it's null).

## Quick Fix: Create New Emulator with Google APIs

If you want to quickly test notifications:

1. **Android Studio → Device Manager → Create Device**
2. **Select System Image:** Choose one with "Google APIs" or "Google Play"
3. **Finish and start the emulator**
4. **Run your Flutter app**
5. **Check logs for FCM token**

## Note on iOS Simulators

iOS Simulators **do support** push notifications, but you need to:
- Request notification permissions
- Have proper APNs certificates configured
- The simulator receives notifications differently than real devices

## Summary

| Platform | Supports FCM? | Requirements |
|----------|--------------|--------------|
| Android Emulator (Standard) | ❌ No | Missing Google Play Services |
| Android Emulator (Google APIs) | ✅ Yes | Includes Google Play Services |
| Physical Android Device | ✅ Yes | Always has Google Play Services |
| iOS Simulator | ✅ Yes | Requires APNs setup |
| Physical iOS Device | ✅ Yes | Requires APNs setup |

**For Android development, always use an emulator with Google APIs or test on a physical device to ensure push notifications work correctly.**

