# Trombl — Pending Setup

> Last updated: 2026-05-29  
> Status: parked — waiting on customer's Google account access.

These steps are **not in the codebase yet** — they require external accounts or dashboard access.  
Everything below is blocked until the customer's Google account is accessible.

---

## 🔴 BLOCKED — Firebase / Google Account

**Why blocked:** Customer doesn't have Google account access right now.  
**Unblocks:** FCM push notifications + production sign-in on real devices.

### Steps to do once Google access is restored

1. **Create Firebase project**
   - Go to [console.firebase.google.com](https://console.firebase.google.com)
   - Create a new project (name: `trombl` or similar)
   - Enable Analytics is optional — not needed for push

2. **Add Android app to Firebase**
   - Package name: `com.example.trombl`
   - Download `google-services.json`
   - Place it at: `android/app/google-services.json`
   - Add Google Services plugin to `android/app/build.gradle.kts`:
     ```kotlin
     plugins {
       id("com.android.application")
       id("kotlin-android")
       id("dev.flutter.flutter-gradle-plugin")
       id("com.google.gms.google-services")   // ← add this line
     }
     ```
   - Add plugin classpath to `android/build.gradle.kts`:
     ```kotlin
     plugins {
       id("com.android.application") version "8.1.0" apply false
       id("com.android.library") version "8.1.0" apply false
       id("org.jetbrains.kotlin.android") version "1.8.22" apply false
       id("com.google.gms.google-services") version "4.4.0" apply false  // ← add
     }
     ```

3. **Add iOS app to Firebase**
   - Bundle ID: `com.example.trombl` (or whatever is set in Xcode)
   - Download `GoogleService-Info.plist`
   - Place it at: `ios/Runner/GoogleService-Info.plist`
   - Open `ios/Runner.xcworkspace` in Xcode
   - Add the plist file to the Runner target (drag into Xcode project navigator)

4. **Get the FCM Server Key**
   - Firebase Console → Project Settings → Cloud Messaging → Cloud Messaging API (Legacy)
   - Copy the Server Key
   - Go to: Supabase → `stbiwzvaykwhdirwmwku` → Edge Functions → Secrets
   - Add secret: `FCM_SERVER_KEY = <paste server key>`

5. **Deploy the send-nudge edge function**
   ```bash
   cd trombl-backend
   supabase functions deploy send-nudge --project-ref stbiwzvaykwhdirwmwku
   ```

6. **Apply the push_tokens DB migration**
   ```bash
   supabase db push --project-ref stbiwzvaykwhdirwmwku
   ```
   Or manually run `supabase/migrations/0002_push_tokens.sql` in the Supabase dashboard SQL editor.

---

## 🟡 SUPABASE — Can do anytime (no Google account needed)

These don't need Google. Can be done now or later.

### Add deep-link redirect URL

- Supabase dashboard → `stbiwzvaykwhdirwmwku` → Authentication → URL Configuration
- Under **Redirect URLs**, add:
  ```
  io.trombl://login-callback
  ```
- This enables magic-link auth to work on real Android/iOS devices.

### Apply push_tokens migration (if not using CLI)

- Supabase dashboard → SQL Editor → paste contents of:
  `trombl-backend/supabase/migrations/0002_push_tokens.sql`

---

## 🟢 NETLIFY — When ready to host web build

These unblock the web client flow-test URL.

1. Connect the `thefounder08/trombl` GitHub repo to Netlify
2. Build settings are pre-configured in `netlify.toml` — no manual setup needed
3. Set these environment variables in Netlify → Build → Environment:
   ```
   SUPABASE_URL  = https://stbiwzvaykwhdirwmwku.supabase.co
   SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
4. After first deploy, add the Netlify domain to Supabase redirect URLs:
   ```
   https://your-site.netlify.app/**
   ```

---

## Summary table

| Task | Needs | Status |
|---|---|---|
| Firebase project + `google-services.json` | Google account | 🔴 Blocked |
| `GoogleService-Info.plist` (iOS) | Google account | 🔴 Blocked |
| Add Google Services plugin to `build.gradle.kts` | Local + google-services.json | 🔴 Blocked |
| `FCM_SERVER_KEY` secret in Supabase | Firebase project | 🔴 Blocked |
| Deploy `send-nudge` edge function | Supabase CLI access | 🔴 Blocked |
| `io.trombl://login-callback` redirect URL | Supabase dashboard | 🟡 Do now |
| Apply `0002_push_tokens.sql` migration | Supabase dashboard | 🟡 Do now |
| Netlify deploy + env vars | Netlify account | 🟢 When ready |
| Add Netlify domain to Supabase redirects | Netlify URL + Supabase dashboard | 🟢 When ready |
