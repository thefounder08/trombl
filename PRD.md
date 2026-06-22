# trombl — Product Requirements Document
**Version:** 1.0.1 (MVP)  
**Branch:** `mvp-static-categories`  
**Status:** MVP-ready  
**Last updated:** June 2026

---

## 1. Product Overview

trombl is a Gen-Z decision helper. It kills decision fatigue with a single vibe pick — fomo (go for it) or jomo (protect your peace) — then surfaces curated options and drives you to take one concrete action. trom, the AI persona at the heart of the product, acts as a chaotic, warm, slightly unhinged best friend who has opinions and actually cares.

The core loop is: **pick a vibe → browse curated options → let trom react → take action → check in → repeat**.

---

## 2. Problem Statement

Gen-Z users spend significant mental energy deciding what to do — tonight, this weekend, right now. The paradox of choice leads to doing nothing. Existing tools (Google, Instagram, event apps) require effort and amplify FOMO without resolving it. There is no lightweight, personality-first product that cuts through the noise and gives you a push.

### Pain points addressed
- "I don't know what to do" paralysis
- Overthinking social plans until the moment passes
- Guilt around doing nothing (no JOMO permission)
- Having to coordinate plans with friends from scratch
- No one to tell you what to actually do first

---

## 3. Target Users

**Primary:** Gen-Z users (18–26), smartphone-native, socially active, high decision fatigue.

| Archetype | Behaviour |
|---|---|
| **Builder** | Constantly starting things, needs focus direction |
| **Social** | Wants plans but struggles to initiate |
| **Explorer** | Up for anything, needs a shortcut to start |
| **Cozy** | Recharging intentionally; needs JOMO permission |
| **Mix** | Day-dependent; toggles between fomo and jomo moods |

---

## 4. Goals & Success Metrics

### Product goals
1. Reduce time-to-action from "I don't know what to do" to first real step
2. Build a habit loop — users return daily to pick a vibe
3. Surface personality-driven AI content that makes the product feel human
4. Enable lightweight social coordination (plans, squad texts)

### MVP success metrics

| Metric | Target |
|---|---|
| D1 retention | > 40% |
| Daily vibe picks per active user | ≥ 1 |
| Option → action conversion (tapped "i'm on it") | > 50% |
| Check-in completion rate (wraps session) | > 30% |
| Plans created per week (early users) | Track only |
| AI reaction load success rate | > 95% (with fallback) |

---

## 5. User Flows

### 5.1 New user flow
```
App open
  └─ /login       (email → magic link or OTP)
  └─ /setup       (display name)
  └─ /onboarding  (5-screen profiling questionnaire)
  └─ /tutorial    (3-slide explainer — shown once)
  └─ /vibe        (pick fomo or jomo)
  └─ /home        (main experience)
```

### 5.2 Returning user flow
```
App open
  └─ /vibe        (today's session restored if exists, or pick fresh)
  └─ /home
```

### 5.3 Decision loop (core daily loop)
```
/home
  ├─ Browse categories  →  OptionsSheet  →  tap option  →  /response  →  "i'm on it"  →  action
  └─ "just pick smth"  →  /decide (AI)   →  reroll or accept  →  /response  →  action
```

### 5.4 End-of-day flow
```
/home  →  "wrap up"  →  /checkin  →  toggle done/not-done  →  /summary  →  home or new vibe
```

### 5.5 Plan flow
```
/response  →  "make it a plan"  →  /create-plan  →  share link
                                                          └─ recipient: /p/:token  →  RSVP
```

### 5.6 Deep link / share flow
```
trombl.com/p/:token
  ├─ Logged in: show plan → RSVP
  └─ Not logged in: /login (intent stored) → setup → /p/:token
```

---

## 6. Feature Requirements

### 6.1 Authentication

**Magic link (primary)**
- User enters email → receives magic link via Supabase Auth
- Auto-signs in on link tap; GoRouter redirect handles routing
- Streams `onAuthStateChange` to detect sign-in while app is open

**OTP (fallback path)**
- User enters email → receives 8-digit code
- 30-second resend cooldown
- Code auto-verifies on 8th digit
- "Wrong email?" restarts flow

**Post-auth routing**
| Condition | Route |
|---|---|
| No display name | `/setup` |
| Onboarding not completed | `/onboarding` |
| Pending plan token in storage | `/p/:token` |
| Normal | `/vibe` |

**Dev mode**
- Debug password login available in `kDebugMode`
- Fresh profile reset button (skips magic link round-trip)

---

### 6.2 Setup Screen (`/setup`)

- Single text field: "what should trom call u?"
- Saves `display_name` to `profiles` table
- Cannot proceed without a name (silent validation)
- Routes to `/onboarding` or pending plan token if one exists

---

### 6.3 Onboarding Questionnaire (`/onboarding`)

5 sequential screens collected via PageView (swipe disabled, button-controlled):

| Screen | Question | Type | Options |
|---|---|---|---|
| 1 | What are you here for? | Multi-select | things to do, productivity, fitness, social life, explore city, surprise me |
| 2 | Your vibe? | Single-select | builder, social, explorer, cozy, mix |
| 3 | What's your schedule? | Single-select | student, 9-5, freelancer, shifts |
| 4 | Weekends? | Single-select | stay home, go out, depends |
| 5 | What do you want more of? | Multi-select | friends, fitness, money, creativity, balance, memories |

**Behaviour**
- Progress dots (animated, active dot expands)
- "skip all" shortcut available on screens 1–4
- Save failure is non-fatal — user proceeds regardless
- Navigates to `/tutorial` on completion (not `/vibe` directly)
- Writes to: `profiles.goals`, `archetype`, `schedule_type`, `weekend_pref`, `wants_more`, `onboarding_completed = true`

---

### 6.4 Tutorial (`/tutorial`)

3-slide swipeable carousel — shows only once (gated by `SharedPreferences: trombl_tutorial_seen`).

| Slide | Title | Content |
|---|---|---|
| 1 | fomo or jomo? | fomo = going for it. jomo = protecting ur peace. no wrong answer. |
| 2 | trombl picks for u | scroll options, tap one that hits. trom gives the first step. |
| 3 | trom is kinda ur bestie | chaotic but she means well. she'll roast u, give the first step, maybe draft a squad text. |

**Behaviour**
- Swipeable with bounce physics
- Dot progress indicators
- Skip button (except last slide)
- "let's go →" on final slide navigates to `/vibe` and marks tutorial as seen
- Never shown again to returning users

---

### 6.5 Vibe Picker (`/vibe`)

The daily entry point. User picks their energy before seeing options.

**Two vibes:**
- **⚡ fomo** — "i want everything" — accent: gold `#F2B705`
- **🛌 jomo** — "i want nothing" — accent: lavender `#C4B0FF`

**Smart suggestion**
trom recommends a vibe based on time of day:
- Late night / early morning (0–9) → jomo
- Friday / Saturday evening (18–24) → fomo
- Default → fomo

Shows "trom rn" badge on the suggested option.

**Session restoration**
- If today's session already exists in DB, restores it silently
- If restored vibe differs from picked vibe, user can tap to switch
- "trom." loading animation during async restore

**City picker**
- Optional chip below vibe cards
- Bottom sheet text input, stores in `profiles.city`
- Used to make action suggestions location-aware

**Navigation:** vibe pick → creates session in `sessions` table → `/home`

---

### 6.6 Home Screen (`/home`)

Main dashboard. Shows the 4 menu categories, a decide section, and activity.

#### Zone 1 — Greeting
- AI-generated or time-based greeting via `homeGreetingProvider`
- Shows user's name + session vibe
- Top-right: vibe chip (tap to switch vibe), profile icon, wrap-up link

#### Zone 2a — Category grid
- 4 core menu categories for the current vibe (static, from `TromblMenu.core(vibe)`)
- Each card: emoji + title + subtitle
- Tap → opens `OptionsSheet` (bottom sheet modal)

#### Zone 2b — Decide section
- Text input: "what's the vibe rn?" (optional mood context)
- CTA: "just pick smth for me ✨" → `/decide`

#### Zone 3 — Plans & Activity
- **My plans:** Cards for plans owned or joined by user
- **Activity handle:** Draggable bottom sheet (0.55–0.9 screen height):
  - PICKED TODAY: menu picks made in this session
  - LOOSE ENDS: AI picks awaiting confirmation ("fr did it / nah")
  - WHAT U'VE BEEN ON: last 5 accepted picks (link to full history)
  - Each item: toggle "fr did it ✓" / "nah" to mark done

**Edge cases**
- No session → redirect to `/vibe`
- Empty states for each zone shown separately

---

### 6.7 Options Sheet

Bottom sheet spawned by category tap. Shows all options in the category.

**Per option:**
- Label (e.g., "rooftop or house party")
- Tag drives action (squad, discover, order in, rest, content, coming soon)
- **Coming soon options:** show snackbar, no navigation
- **Active options:** navigate to `/response` with `ResponseArgs`

---

### 6.8 Decide Screen (`/decide`) — AI Pick

AI-powered decision engine with 4-level fallback:

| Layer | Behaviour |
|---|---|
| 1 – AI | Calls edge function `llm-proxy` with full context prompt |
| 2 – Retry | If response contains banned phrases (generic/vague), retries once with "be more specific" instruction |
| 3 – Static fallback | Hardcoded `PickFallback` (time-aware, by vibe) |
| 4 – Ask | After 3 rerolls, trom asks a clarifying question — user inputs mood, AI tries again |

**Context sent to AI:**
- Session vibe + hour + day of week
- City (if set)
- User profile: archetype, goals, wants_more, schedule_type
- Previously rejected picks in this session (exclude list)
- Weather condition
- User mood input (if provided)

**AI response format:** JSON — `{pick_text, reason_text, tag}`

**Screen states:** `fork` → `loading` → `pick` → (reroll or accept) → (ask after 3 rerolls)

**Logging:** Every AI call logs to `ai_usage_logs` — endpoint, layer, token counts, latency, cache hit.

---

### 6.9 Response Screen (`/response`)

Shows the chosen option (menu pick or AI pick) with trom's reaction and a first step.

#### Content blocks

**1. Vibe context line**
- "⚡ fomo pick · going for it" or "🛌 jomo pick · protecting ur energy"

**2. Pick hero**
- Option label in accent colour, serif font

**3. TROM'S TAKE card** (AI-generated, single call)
- Reaction text: 1–2 punchy, unhinged lines specific to the pick
- "TROM CLOCKED THIS" observation: one intimate sentence about the user

**4. DO THIS FIRST** (rule-based per tag)
| Tag | First step |
|---|---|
| squad | "open the group chat and send smth rn." |
| discover | "search it up right now. don't save it for later." |
| order in | "open the app and just browse. u don't have to decide yet." |
| rest | "put ur phone face down. that's literally the whole move." |
| content | "open the app first. don't draft — just open it." |
| solo | "close this and go. u already know what to do." |

**5. Squad draft block** (squad tag + AI message only)
- Shows trom's pre-written squad message in a WhatsApp-green card
- "text ur squad →" button

#### CTAs
- **Primary:** "i'm on it →" — executes action via `ActionEngine`
- **Secondary row:** "🔥 make it a plan" · "🔗 share this"
- **Tertiary:** "pick smth else" → `/home`
- **Post-launch:** "fr did it ✓" / "nah didn't happen" — marks pick done

#### Action routing (ActionEngine)
| Tag | Action |
|---|---|
| squad | Launch WhatsApp / Instagram DM |
| discover | Open Google Maps / event search |
| order in | Open Zomato / Swiggy |
| rest | Navigate to `/dnd` |
| content | Open Notes / Spotify |
| coming soon | Show "coming soon" snackbar |

---

### 6.10 DnD Screen (`/dnd`)

Shown after selecting a rest-tagged option. Full-screen confirmation.

- Message: "🛌 trom handled it. ur off the grid."
- Single button: "back when ur ready" → `/home`
- No check-in required (rest is its own completion)

---

### 6.11 Check-in (`/checkin`)

End-of-day review of today's picks.

- Lists all picks from the current session
- Per pick: toggle checkbox + label
- "wrap it up" enabled after at least one pick is marked done
- Navigates to `/summary` with `done` and `total` counts

**Empty state:** "u haven't picked anything yet" (redirects or encourages action)

---

### 6.12 Summary Screen (`/summary`)

Instant, hardcoded reactive verdict — no AI call, instant load.

| Condition | Headline |
|---|---|
| All done | "u actually did everything. who are u." |
| None done | "u picked $total things. did zero. iconic." |
| Some done | "$done/$total. trom respects the effort." |

**CTAs:**
- "i'm good for now" → `/home` (stay in session)
- "new vibe" → `/vibe` (start fresh)

---

### 6.13 Plans Feature

#### Create Plan (`/create-plan`)
- Entry point: "make it a plan" on response screen
- Pre-fills title using human-phrased version of option label
- Optional detail field (never pre-filled with AI output)
- Time chips: tonight, tomorrow, this weekend (sets `starts_at`)
- On create: generates `share_token`, shows shareable URL `https://trombl.com/p/:token`
- Share sheet via `share_plus`

#### Plan Landing Page (`/p/:token`) — Public
- Accessible without authentication
- Shows: title, vibe emoji, owner name, start time, attendee count
- Unauthenticated user: stores intent in SharedPreferences → `/login` → auto-redirects back after auth
- RSVP options: "i'm in" / "can't tonight" / "maybe"
- Already-member state: shows current status

#### Plan Detail (`/plan/:id`)
- Full attendee list with in/maybe/out status
- Owner: can edit / delete
- Non-owner: RSVP management (change status)
- Displays share code for re-sharing

#### Join Plan (`/join-plan`)
- Paste share code → auto-joins with "maybe" status
- Error message on invalid code
- Navigates to `/plan/:id` on success

---

### 6.14 History (`/history`)

- Stats row: days active, fomo days, jomo days, completion percentage
- Chronological list of wrapped sessions (last 30 days)
- Per session: picks with done/not-done checkmarks
- Expandable/collapsible per session

---

### 6.15 Profile (`/profile`)

- Display name, @handle, city
- Edit modal (bottom sheet): name + handle + city fields
- **Stats:** days active, picks completed, total picks
- **Recent wins:** picks marked done
- **Trom's memory:** memory nodes (AI-generated observations stored after day wraps)
- **Recent sessions:** last 3 wrapped sessions

---

### 6.16 Chat (`/chat`) — Stub

Current state: minimal conversational thread viewer.
- Opens with trom's seeded opening message (`ChatArgs.seedText`)
- User can type replies (local state only, no persistence)
- No AI response generation in v1.0
- Full AI response loop is a future milestone

---

### 6.17 Push & In-App Notifications

Implemented, native (Android/iOS) only — not available on web.

- On sign-in: requests notification permission → registers FCM device token (`push_tokens`) → schedules two daily local reminders (10am, 8pm, randomized copy).
- On sign-out: unregisters tokens, cancels all scheduled local notifications.
- Server-triggered nudges go through the `send-nudge` edge function: rate-limited to once per `(user, kind)` per 24h, persists a row to `notifications` regardless of FCM delivery outcome, and sends an FCM push if an active device token exists.
- **In-app notification center** (`/notifications`): bell icon with unread-count badge on Home; lists all notification rows newest-first; tap-to-read and mark-all-read. This guarantees users see a nudge even without push permission granted or a registered device.

---

## 7. Menu Content

### FOMO categories (4 core + 1 new drop)

| Category | Emoji | Active options | Coming soon |
|---|---|---|---|
| Go out tonight | 🎉 | rooftop/house party, live music, bar hop, club/dance floor | — |
| Make plans w someone | 👥 | text group chat, reach out to that person | game night, random event |
| Treat urself | 💸 | fancy dinner, book a concert, hair/nails | memorable experience |
| Make or post something | 📸 | instagram post, shoot a reel, spotify playlist | honest opinion post |
| **NEW DROP:** Move ur body | 🏃 | gym session | fitness class, outdoor things, hike |

### JOMO categories (4 core + 1 new drop)

| Category | Emoji | Active options | Coming soon |
|---|---|---|---|
| Fully rot today | 🛌 | watch something new, endless videos, sleep/nap, do nothing | — |
| Comfort food situation | 🍕 | usual order, snack spread, bake something, fancy coffee | — |
| Soft recharge | 🧴 | face mask, journaling, shower/bath | organize space |
| Get in ur head | 🧠 | write ur mind, vision board | reflect, letter to self |
| **NEW DROP:** Get lost in music | 🎵 | album deep dive | new playlist, new artist, podcast |

**16 options are tagged `coming soon`** — they display but show a snackbar on tap.

---

## 8. AI Layer

### Trom's voice (system prompt base)
- Lowercase always. No markdown. No bullet points.
- Short, punchy — like a text from a friend.
- Chaotic, warm, a little unhinged, actually cares.
- Has opinions. Gently roasts. Never lectures.
- Never sounds like a chatbot or a brand.

### AI calls in v1.0

| Call | Trigger | Output | Fallback |
|---|---|---|---|
| `reactionCombined` | Response screen load | `{reaction, clocked}` JSON | Static warm reaction per vibe |
| `buildDecidePrompt` | /decide entry | `{pick_text, reason_text, tag}` JSON | Static fallback (time-aware) |
| `daySummary` | Day summary screen | 2-line narrative | "trom lost the plot. but u lived it, so that's enough." |
| `weeklyRead` | Profile load | One-liner pattern read | Hidden if fails |
| `memoryNode` | Session wrap | One-sentence observation about user | Skipped silently |

### Fallback architecture
1. AI call succeeds → use response
2. AI response contains banned phrases → retry with specificity note
3. AI call fails → static fallback (never shows error state to user)

### Infrastructure
- LLM calls routed via Supabase edge function `llm-proxy` (provider-agnostic)
- Every call logs to `ai_usage_logs`: endpoint, layer fired, token counts, latency, cache hit

---

## 9. Data Model

### Supabase tables

| Table | Written by | Key columns |
|---|---|---|
| `profiles` | Setup, onboarding, profile edit | display_name, handle, city, archetype, goals, schedule_type, weekend_pref, wants_more, onboarding_completed |
| `sessions` | Vibe picker | user_id, vibe, city, started_at, wrapped_at |
| `picks` | Options sheet (menu picks) | session_id, user_id, option_id, label, tag, done |
| `ai_picks` | Decide screen | session_id, pick_text, reason_text, tag, vibe, mood_text, pick_hour, pick_day, weather_condition, rerolled, accepted |
| `plans` | Create plan | owner_id, vibe, title, detail, share_token, starts_at, expires_at |
| `plan_members` | Join/RSVP | plan_id, user_id, status (in/out/maybe) |
| `memory_nodes` | System (post-wrap) | user_id, content, type, relevance_score |
| `ai_usage_logs` | Every LLM call | endpoint, layer, prompt_tokens, completion_tokens, latency_ms, cache_hit |

### Local storage (SharedPreferences)
| Key | Purpose |
|---|---|
| `trombl_tutorial_seen` | Prevents tutorial from showing twice |
| `pending_plan_token` | Persists deep-link plan intent across magic-link restart |

---

## 10. Analytics Events

Tracked via Firebase Analytics (disabled in debug mode):

| Event | Fired when |
|---|---|
| `login_completed` | Auth sign-in success |
| `onboarding_completed` | Onboarding save + navigate |
| `vibe_picked` | Vibe tapped on /vibe |
| `category_opened` | Category card tapped → OptionsSheet |
| `option_selected` | Option tapped in OptionsSheet |
| `action_launched` | "i'm on it" tapped |
| `dnd_entered` | Rest pick confirmed |
| `checkin_started` | /checkin opened |
| `session_wrapped` | "wrap it up" → /summary |
| `reaction_loaded` | AI reaction fetched (success or fallback) |

---

## 11. Non-functional Requirements

| Requirement | Spec |
|---|---|
| Platform | Flutter web (primary), mobile-responsive |
| Deployment | Netlify — `main` → trombl.com, `development` → staging preview |
| Auth | Supabase Auth (magic link + OTP) |
| AI latency | < 2s for reaction load (target), fallback shown if exceeded |
| Offline | Basic graceful degradation (static fallbacks, no crash) |
| Secrets | All via `--dart-define` at build time, never hardcoded |
| Analytics | Firebase Analytics (no PII beyond uid) |
| Error handling | No user-visible error states — all failure paths have fallback UI |

---

## 12. Out of Scope — v1.0

These are explicitly **not** in scope for this branch:

| Feature | Status |
|---|---|
| Full AI chat responses in `/chat` | Stub — future milestone |
| 16 "coming soon" menu options | Planned for v1.1+ |
| Custom time picker for plans | Blocked on DB migration |
| AI dynamic menu generation | Parked — `DynamicMenuNotifier` exists but not active |
| Weather-aware UI display | Fetched, used in AI context only (not visible) |
| Plan expiry enforcement / cleanup | Created with 7-day TTL but no auto-archive |
| Push notifications on web | Not available — FCM service worker conflicts with Flutter web's own SW (native Android/iOS only) |
| Web SEO / meta tags | Not implemented |
| Payments or monetisation | Not in scope for MVP |

---

## 13. Versioning & Release

| Version | Branch | Status |
|---|---|---|
| `v1.0.0` | `main` | Production (trombl.com) |
| `v1.0.1` | `mvp-static-categories` | **MVP-ready** (this document) |
| `v1.1.0` | planned | Dynamic AI categories, active coming-soon options |

### What changed in v1.0.1 vs v1.0.0
- Overflow fixes and responsive layout improvements
- Response screen CTAs (make it a plan, share this)
- Profile chip display + onboarding CTA cleanup
- "About you" empty state handling
- Onboarding tutorial (3-slide, one-time)
- AI content size reduced to minimal on response screen
- Quirkier AI reaction prompts
- Android + iOS deep link support
- JOMO label and routing updates

---

*PRD generated from live codebase audit of `mvp-static-categories` branch.*
