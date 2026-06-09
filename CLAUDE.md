# trombl-app — Claude Instructions

## Project overview

Flutter web app (trombl). Gen-Z decision helper with fomo/jomo vibes.
Backend: Supabase. State: Riverpod. Navigation: GoRouter.
Deployment: Netlify (production → trombl.com).

---

## Hard rules — never break these

- **Never commit directly to `main`**
- **Never force-push to `development`**
- **Never run migrations or schema changes** without explicit user confirmation
- **Never hardcode secrets** (Supabase URL, anon key, etc.) — always use `--dart-define`
- **Never modify Netlify settings** without explicit instruction
- **Never move `main`** without explicit confirmation

---

## Git workflow (always follow)

### Branch naming

| Branch | Purpose |
|---|---|
| `main` | Production only — never commit directly |
| `development` | Integration branch — always deployable |
| `release/vX.Y.Z` | Release candidate — created from `development` |
| `feature/*` | One feature — branched from `development` |
| `hotfix/*` | Urgent fix — branched from `main` |

### Commit target

All feature commits go to `development` (or a `feature/*` branch off it).
`main` is release-only.

### Release process

1. `feature/*` → merge to `development` (via PR)
2. `development` → create `release/vX.Y.Z` branch
3. Test release branch on preview URL
4. `release/vX.Y.Z` → merge to `main` (`--no-ff`)
5. Tag `main` with `vX.Y.Z`
6. Merge `main` back to `development`
7. Delete release branch

### Versioning: `MAJOR.MINOR.PATCH`

- `PATCH` = bug fix (e.g. `v1.0.1`)
- `MINOR` = new feature (e.g. `v1.1.0`)
- `MAJOR` = breaking change (e.g. `v2.0.0`)

### Current version map

| Version | Branch | Status |
|---|---|---|
| `v1.0.0` | `main` | MVP release |
| `v1.0.1` | `mvp-static-categories` | In progress (overflow fixes, response CTAs, profile cleanup) |
| `v1.1.0` | planned | Dynamic AI categories |

### Netlify deploy targets

| Branch | URL |
|---|---|
| `main` | trombl.com (production) |
| `development` | dev preview (staging) |
| `release/*` | preview URLs (pre-release testing) |

---

## Build commands

Production web build (always include dart-defines):
```
flutter build web --release \
  --dart-define=SUPABASE_URL=https://stbiwzvaykwhdirwmwku.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

Analyze before committing:
```
flutter analyze --no-pub
```

---

## Architecture notes

- Static menu: `TromblMenu.core(vibe)` / `TromblMenu.newDrop(vibe)` in `menu_data.dart`
- Dynamic menu: `DynamicMenuNotifier` / `dynamicMenuProvider` (parked — not active in `mvp-static-categories`)
- Share URL: `AppConfig.shareBaseUrl` in `app_config.dart` — single source of truth (currently `https://trombl.com`)
- Menu screen (`/menu`): kept in codebase but not navigated to in `mvp-static-categories`; all former `/menu` nav goes to `/home`
- Vibe switch: always call `TromblMenu.core(vibe)` directly — do not rely on `dynamicMenuProvider` for reactive vibe switching
