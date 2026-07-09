# Trombl — Flutter app

The mobile app for the vibe-based Trombl concept. Feature-first architecture, Riverpod + GoRouter + Freezed, talking to the Supabase backend (already live) and the server-side LLM proxy.

## Run it

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Freezed/JSON
flutter run \
  --dart-define=SUPABASE_URL=https://stbiwzvaykwhdirwmwku.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

No keys are hardcoded — they come from `--dart-define`. The app shows a config screen if they're missing.

## Android release build (APK to share/sideload)

Config keys have to be passed at build time — `flutter build apk --release`
with no flags produces an APK where every installer sees the "missing
config" screen, since the values are baked in at compile time, not read at
runtime. Use the `dart_defines/*.json` files (gitignored — copy from the
matching `.example` and fill in real values once, locally) with `--flavor`:

```bash
flutter build apk --release --flavor prod --dart-define-from-file=dart_defines/prod.json
# output → build/app/outputs/flutter-apk/app-prod-release.apk
```

Swap `prod` for `dev`/`staging` (and the matching json file) to build those
flavors instead. To sanity-check a built APK actually has real config baked
in without installing it anywhere:

```bash
unzip -p build/app/outputs/flutter-apk/app-prod-release.apk lib/arm64-v8a/libapp.so \
  | strings | grep -c 'supabase.co'   # should be > 0
```

## Architecture

```
lib/
  core/
    ai/                  ← LLM abstraction
      llm_provider.dart        abstract interface (features depend ONLY on this)
      providers/proxy_llm_provider.dart  calls the Supabase edge function
      system_prompts.dart      trom's voice, centralised
    app_config.dart      env-based config
    providers.dart       supabase client, auth state, llm provider
    router/app_router.dart   auth-aware GoRouter
    theme/               the dark two-vibe palette
  features/
    onboarding/          login (magic-link auth)
    vibe/                the fomo/jomo fork — creates a real session
    menu/                category options (next build target)
    profile/             "trom's read on you" — reads real history
    plan/                shareable invite plans (future)
  shared/
    models/models.dart   Freezed models mirroring the DB tables
    repositories/        data access (no Supabase calls leak upward)
    result.dart          typed Result with trom-voice errors
```

### The key architectural decision

The architecture skill assumed the app calls Gemini/Claude/OpenAI SDKs directly. We don't. The app talks to ONE thing — the `llm-proxy` Supabase edge function — which holds the key and picks the model server-side. So:

- Feature code imports `core/ai/llm_provider.dart` (the interface) only.
- There's a single implementation, `ProxyLlmProvider`, hidden behind the interface.
- Switching Gemini ↔ Claude ↔ GPT is a server env change, never an app release.

This is simpler and safer than the three-SDK setup, and it means no API key ever ships in the binary.

## What's wired and real

- Magic-link + Google/Apple auth via Supabase, plus guest (anonymous) mode.
- Auth-aware routing (signed-out → /login, signed-in → /vibe).
- The vibe pick creates a real `sessions` row in the DB.
- Menu category grid + the action engine (WhatsApp drafts, Zomato/BookMyShow/Maps deep links, DND).
- Response screen — trom's reaction to a pick, writes the pick to the DB.
- **Wrap Up** (`/checkin`) — reviews everything decided today (menu picks + accepted AI picks) in one combined list with done/skipped status, then finalizes the session. One entry point (Home's "📦 wrap up" chip, carries a live unresolved count).
- **Task resume popup** (`TaskWrapupController`) — on app foreground, nudges once per task ("did u actually do it?") for anything still unresolved; only fires for tasks with no other UI already asking the same question.
- **Make Plan** (`/make-plan`) — its own multi-step flow (Choose Activity → Choose Options → Date & Time → Location → Invite Friends → Preview → Create), separate from the response/detail screen. Invite Friends searches existing Trombl users directly (no separate friends/contacts model); Plan Details shows Accepted/Pending/Declined live via Supabase Realtime on `plan_members`.
- The profile reads real session history and computes a basic "read."
- The LLM provider is wired to the proxy (used by reactions/weekly read).

## Known gaps

- `test/action_engine_test.dart` has pre-existing drift against the current `action_engine.dart` keyword-matching (12 failing tests) — tracked separately, not yet fixed.
- AI-generated pick tags ('social'/'food'/'explore') don't all match `MenuTag.fromString`'s vocabulary, so some AI suggestions show a false "coming soon" — tracked separately.
- Search-and-invite in Make Plan creates a `pending` plan_members row and notifies the invitee (DB trigger), but there's no in-app UI yet to invite someone to a plan *after* it's already been created — only at creation time.

## Web build

### Dev server

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://stbiwzvaykwhdirwmwku.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

### Production build

```bash
flutter build web --release --base-href /
# output → build/web/
```

The `[[redirects]]`
rule in `netlify.toml` ensures all GoRouter paths (including `/p/:token` plan links)
serve `index.html` so deep-link navigation works correctly.

### Netlify

`netlify.toml` is pre-configured. Connect the repo, then set these env vars in
**Netlify → Build → Environment**:

| Variable | Value |
|---|---|
| `SUPABASE_URL` | `https://stbiwzvaykwhdirwmwku.supabase.co` |
| `SUPABASE_ANON_KEY` | your anon key |

For magic-link auth on the hosted domain, add it to Supabase:
**Authentication → URL Configuration → Redirect URLs → `https://your-site.netlify.app/**`**

### Push notifications on web

Push notifications (FCM) are **not available on the web build** — `firebase_messaging`
requires a service worker setup that conflicts with Flutter web's own SW. The full
vibe → menu → response flow works on web; only the nudge layer is absent.

## Firebase setup (required for push notifications on native)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. **Android:** add app with package `com.example.trombl`, download `google-services.json`
   → place at `android/app/google-services.json`
3. **iOS:** add app, download `GoogleService-Info.plist`
   → place at `ios/Runner/GoogleService-Info.plist`
4. In `android/app/build.gradle.kts` add `id("com.google.gms.google-services")` to plugins
5. In `android/build.gradle.kts` add the plugin classpath (version `4.4.0`)

## Backend

- Supabase project: `stbiwzvaykwhdirwmwku`
- Edge functions: `llm-proxy` (Gemini), `send-nudge` (FCM nudges)
- Apply migration `0002_push_tokens.sql` via dashboard or `supabase db push`
- Deploy nudge function: `supabase functions deploy send-nudge`
- Set `FCM_SERVER_KEY` secret in Supabase → Edge Functions → Secrets
- Add `io.trombl://login-callback` to Supabase → Authentication → Redirect URLs

## Notes

- Run `build_runner` before first launch — `models.freezed.dart` and `models.g.dart` are generated, not committed.
- Configure the magic-link redirect (`io.trombl://login-callback`) in Supabase Auth settings and as a deep link in iOS/Android.
- The backend (schema + RLS) is already applied to project `stbiwzvaykwhdirwmwku`. The LLM proxy function still needs deploying (`supabase functions deploy llm-proxy`) and its secrets set.
