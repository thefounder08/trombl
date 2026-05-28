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

- Magic-link auth via Supabase (no passwords handled in-app).
- Auth-aware routing (signed-out → /login, signed-in → /vibe).
- The vibe pick creates a real `sessions` row in the DB.
- The profile reads real session history and computes a basic "read."
- The LLM provider is wired to the proxy (used by reactions/weekly read).

## What's stubbed (next build targets, in order)

1. **Menu** — port the prototype's category grid + the working action engine (WhatsApp draft, Zomato/BookMyShow deep links, DND). The screen currently confirms the live session and routes on.
2. **Response screen** — trom's reaction to a pick (calls the LLM proxy via `SystemPrompts.reaction`), writes the pick to the DB.
3. **Check-in + day summary** — set `picks.done`, then the summary.
4. **Profile read** — richer derivation (go-to move, history scrapbook) matching the prototype's `deriveRead`.
5. **Plan / invite loop** — the shareable plan page (needs the `plans` public-read path already in the DB).

## Notes

- Run `build_runner` before first launch — `models.freezed.dart` and `models.g.dart` are generated, not committed.
- Configure the magic-link redirect (`io.trombl://login-callback`) in Supabase Auth settings and as a deep link in iOS/Android.
- The backend (schema + RLS) is already applied to project `stbiwzvaykwhdirwmwku`. The LLM proxy function still needs deploying (`supabase functions deploy llm-proxy`) and its secrets set.
