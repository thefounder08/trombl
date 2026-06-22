# Privacy Policy — Trombl

**Effective Date:** [INSERT DATE ON PUBLICATION]

**Last Updated:** [INSERT DATE]

---

## 1. Introduction

Trombl ("Trombl," "we," "us," or "our") provides a mobile and web application (the "App") that helps users decide what to do with their time by offering a single daily mood choice ("fomo" or "jomo"), curated and AI-generated activity suggestions, lightweight social plan-sharing, and related features (collectively, the "Service"). The Service is available on Android, iOS, and the web at trombl.com.

This Privacy Policy explains what information we collect when you use the Service, how we use and share it, how long we keep it, and what choices and rights you have. It is written to reflect how the Service actually operates, based on its current technical implementation — not generic boilerplate.

By using the Service, you agree to the collection and use of information as described in this Policy. If you do not agree, please do not use the Service.

This Policy is intended to comply with the EU/UK General Data Protection Regulation ("GDPR"), the California Consumer Privacy Act as amended by the California Privacy Rights Act ("CCPA/CPRA"), and the data collection disclosure requirements of the Apple App Store and Google Play Store.

---

## 2. Information We Collect

We collect information in three ways: information you provide directly, information generated automatically through your use of the Service, and information collected by third-party infrastructure providers we rely on to operate the Service (described in Section 5).

### 2.1 Account Information

When you create an account, we collect:

- **Email address** — used to send you a magic sign-in link or a one-time passcode (OTP). This is the only credential required to use the Service; Trombl does not use or store passwords.

### 2.2 Authentication Information

Account access is handled by our backend provider, Supabase, using passwordless authentication:

- **Magic link tokens** and **one-time passcodes (OTP)**, generated and validated by Supabase Authentication, sent to your email address.
- **Session tokens** issued after successful sign-in, used to keep you logged in and to authorize requests to our backend.

We do not collect or store your password, because no password exists in this authentication flow.

### 2.3 Profile Information

After signing in, you may provide, and we store:

- **Display name** — shown to you and, where you create or join shared Plans (Section 2.6), to other participants in that Plan.
- **Handle** (username) — optional, unique identifier.
- **City** — a free-text field you type in yourself. We do **not** collect precise GPS location, device location permissions, or any geolocation coordinates. City is used only to give activity suggestions local relevance and to retrieve general weather conditions for your stated city (Section 2.5).
- **Lifestyle, archetype, schedule type, weekend preference, and "what you want more of"** — answers to a short onboarding questionnaire (e.g., whether you identify as a "builder," "social," "explorer," "cozy," or a mix; your general schedule type such as student, 9–5, freelancer, or shifts; your weekend habits; and topics like friends, fitness, money, creativity, balance, or memories). These answers personalize the activity suggestions you receive.
- **Notification preference** — whether you want nudge notifications.

### 2.4 User Activity & Content Data

As you use the Service, we collect:

- **Vibe sessions** — your daily mood selection ("fomo" or "jomo"), the date/time it was started, and when you "wrapped" (closed out) that session.
- **Picks** — the activity options you select from the curated menu, including the category, option label, an associated tag (e.g., "squad," "rest," "discover"), and whether you later marked it as done.
- **AI-generated picks** — the text and reasoning of suggestions generated for you by our AI assistant ("trom"), the mood text you optionally typed in to get a suggestion, the time of day and day of week the suggestion was generated, the general weather condition associated with your stated city at that time, whether you accepted or "rerolled" (rejected) the suggestion, and whether you later marked it done.
- **Memory content** — short text observations our AI assistant generates and stores about your stated facts, preferences, behavioral patterns, or free-form journal/emotional entries you choose to write. This is used to make future suggestions feel personalized and consistent over time.
- **AI usage telemetry** — for each call made to our AI assistant: which feature triggered it, whether the response came from a cache, which fallback tier produced the result, the approximate length (character count) of the prompt and response, and how long the call took. We do **not** retain the full text of every AI prompt in this telemetry record — only aggregate metadata about the call.

### 2.5 Plans & Social Sharing Information

If you create a shareable "Plan":

- We store the Plan's title, optional detail text, your chosen mood/vibe for the Plan, proposed start time, an expiration time, and a unique share link/token.
- If someone joins or RSVPs to your Plan (including "in," "out," or "maybe" responses), we store their account identifier and RSVP status, and other participants in that Plan can see your display name, your vibe, and your RSVP status.
- A Plan's public link can be opened by **anyone** you share it with, including people without a Trombl account, who can view limited Plan details and RSVP. If they RSVP without an existing account, we temporarily store their RSVP intent on their own device locally until they complete sign-in, after which it is associated with their new account.

### 2.6 Device & Push Notification Information

If you grant notification permission (native apps only — push notifications are not available on the web version of the Service):

- **Device push token** (Firebase Cloud Messaging token) and **platform** (Android or iOS), used solely to deliver notifications to your device.
- **Notification delivery records** — a log of which notification "kind" was sent to you and when, used to prevent sending you the same type of nudge more than once per day.
- **In-app notification history** — the title, body text, and associated metadata of nudges sent to you, stored so you can view your notification history inside the Service even if push delivery fails or you have not granted notification permission.

### 2.7 Diagnostic & Analytics Information (native apps only)

On Android and iOS — **not** on the web version — we use Firebase Analytics and Firebase Crashlytics, which automatically collect:

- **App usage events**, including: sign-in completion, onboarding completion, vibe selection, category and option interactions, AI suggestion outcomes, action launches, "do not disturb" entry, check-in and session-wrap events, new-session starts, Plan creation and joining, profile views, and notification-permission grants. These events are associated with your account identifier but do not include your email, name, or message content.
- **Crash and error reports**, including device information, app state at the time of the crash, and your account identifier (so we can investigate issues you personally report or experience), via Crashlytics.

These diagnostic tools are automatically disabled during our internal development/testing builds and are not active on the web version of the Service at all.

### 2.8 Information We Do Not Collect

To be specific about the boundaries of our data collection: we do not collect precise/GPS location, payment or billing information (the Service has no purchases, subscriptions, or in-app payments), biometric data, contacts, camera or microphone data, advertising identifiers, or social media account data. We do not use the Service to serve third-party advertising.

---

## 3. How We Use Your Information

We use the information described above to:

- Authenticate you and maintain your session.
- Operate the core decision-making features: generating and storing your daily vibe sessions, curated and AI-generated activity suggestions, and your history of picks.
- Personalize AI-generated suggestions using your onboarding answers, recent activity, and stored "memory" content.
- Send you AI-generated reactions, summaries, and conversational content via our AI assistant.
- Enable and display shared Plans and RSVPs between you and other users you invite.
- Send you push and/or in-app notifications, where permitted, and prevent sending excessive repeat notifications.
- Diagnose crashes and technical errors (native apps only).
- Understand aggregate feature usage to improve the Service (native apps only, via Analytics events).
- Comply with legal obligations and enforce our terms.

We do not use your information to make automated decisions that produce legal effects or similarly significant effects concerning you. The AI-generated suggestions are recommendations only; you choose whether to act on them.

---

## 4. AI Processing Disclosure

The Service uses artificial intelligence to generate personalized activity suggestions, reactions, and summaries. Specifically:

- When the Service needs an AI-generated response, your prompt — which may include your stated mood/vibe, time of day, city, weather condition, onboarding answers, and recent activity history — is sent from our backend (a Supabase Edge Function acting as a proxy) to **Google's Gemini AI model**. Trombl's app code never communicates with Google's AI service directly, and no AI provider API key is ever stored on your device.
- The AI provider processes your prompt to generate a response, which is returned to you through our backend. We log metadata about each call (Section 2.4) but do not separately retain a permanent transcript of every prompt sent to the AI provider beyond what is needed to display the resulting suggestion to you (e.g., as a stored "pick" or "memory" entry, if you accept it).
- If the AI service is unavailable, returns an unusable response, or exceeds a quota, the Service automatically falls back to pre-written, non-AI-generated content so that your experience is not interrupted. You may not always be able to tell, from the response alone, whether a given suggestion was AI-generated or a static fallback.
- Google's processing of data sent to its AI models is subject to Google's own privacy and data-processing terms, which we encourage you to review.

---

## 5. Third-Party Service Providers

We rely on the following infrastructure and service providers to operate the Service. These providers process data on our behalf and, where applicable, in their own capacity as independent controllers/processors of certain technical data:

| Provider | Purpose | Data Involved |
|---|---|---|
| **Supabase** | Database hosting, user authentication, backend logic (Edge Functions) | All account, profile, activity, Plan, and notification data described in Section 2 |
| **Google Firebase Cloud Messaging** | Delivering push notifications (native apps only) | Device push token, platform |
| **Google Firebase Analytics** | App usage analytics (native apps only) | App interaction events, account identifier |
| **Google Firebase Crashlytics** | Crash and error reporting (native apps only) | Crash diagnostics, device state, account identifier |
| **Google Gemini (AI model)** | Generating AI-powered suggestions, reactions, and summaries | Prompts containing contextual data described in Section 4 |
| **Open-Meteo** | Retrieving general weather conditions for your stated city, used only as AI prompt context | The city name you provide; no account identifier is sent |
| **Netlify** | Web hosting for the Service at trombl.com | Standard web request/hosting logs |

We do not sell your personal information to third parties, and we do not share it with third parties for cross-context behavioral advertising.

---

## 6. Data Sharing with Other Users

Certain information is visible to other users by design, as part of the core functionality of the Service:

- If you create or join a shared **Plan**, your display name, chosen vibe, and RSVP status are visible to other participants in that specific Plan.
- A Plan's shareable link can be opened by anyone who receives it, including people without an account, who can view the Plan's title, vibe, owner's display name, proposed time, and attendee count before deciding whether to RSVP or sign in.

No other profile, activity, or AI-interaction data is shared with other users.

---

## 7. Data Retention

We retain your information for as long as your account remains active and as needed to provide the Service. Specifically:

- Account, profile, activity, Plan, and notification data are retained until you request deletion (Section 9) or your account is otherwise removed.
- AI usage telemetry (Section 2.4) is retained for service-quality monitoring.
- Crash and analytics data (native apps only) are retained according to Firebase's standard retention periods for these services.
- Shared Plans include an expiration time; however, expired Plans are not currently automatically deleted and may remain accessible via their share link until manually removed.

We do not currently offer a fully automated, self-service "delete my account" feature inside the app. To request deletion of your account and associated data, contact us using the details in Section 12, and we will process your request in accordance with applicable law.

---

## 8. Children's Privacy

The Service is intended for users who are at least 16 years old (or the minimum age of digital consent in your jurisdiction, if higher) and is designed primarily for a young-adult audience. We do not knowingly collect personal information from children below this age. If you believe a child has provided us with personal information, please contact us using the details in Section 12 and we will take steps to delete it.

---

## 9. Your Privacy Rights

### 9.1 GDPR Rights (EU/UK/EEA Users)

If you are located in the EU, UK, or EEA, you have the right to:

- **Access** the personal data we hold about you.
- **Rectify** inaccurate or incomplete data (much of this, such as your display name and city, can be edited directly within the Service).
- **Erase** your data ("right to be forgotten"), subject to legal exceptions.
- **Restrict** or **object** to certain processing.
- **Data portability** — receive your data in a structured, machine-readable format.
- **Withdraw consent** at any time where processing is based on consent (e.g., notification permissions).
- **Lodge a complaint** with your local data protection supervisory authority.

Our legal bases for processing include: performance of a contract (providing the Service you signed up for), legitimate interests (service security, diagnostics, and improvement), and consent (e.g., push notifications).

### 9.2 CCPA/CPRA Rights (California Residents)

If you are a California resident, you have the right to:

- **Know** what personal information we have collected, used, and disclosed about you.
- **Delete** personal information we have collected from you, subject to certain exceptions.
- **Correct** inaccurate personal information.
- **Opt out** of the sale or sharing of personal information — we do not sell or share your personal information as defined by the CCPA, so there is no sale/sharing to opt out of.
- **Non-discrimination** for exercising any of these rights.

To exercise any of these rights, contact us using the details in Section 12. We may need to verify your identity before fulfilling a request.

---

## 10. International Data Transfers

Our infrastructure providers (Supabase, Google Firebase, Google Gemini, Netlify) may process and store data on servers located in countries other than your own, including the United States. Where required, we rely on appropriate safeguards (such as standard contractual clauses or equivalent mechanisms offered by these providers) for international transfers of personal data.

---

## 11. Security

We rely on industry-standard security practices provided by our infrastructure partners, including encrypted connections (HTTPS/TLS) between the app and our backend, database-level access controls (row-level security policies restricting most data to its owning user), and passwordless authentication to eliminate password-related risks. No method of electronic transmission or storage is 100% secure, and we cannot guarantee absolute security.

---

## 12. App Store & Platform Disclosures

In accordance with Apple App Store and Google Play Store requirements, we confirm:

- The Service collects the data categories described in Section 2 for the purposes described in Section 3.
- Notification permission is requested only on native (Android/iOS) apps and only after sign-in; it is optional, and the Service can function without it.
- The Service does not request, and does not use, device location permissions. The "city" field is manually entered text, not derived from device GPS.
- The Service does not contain third-party advertising or advertising SDKs.
- Diagnostic data (Crashlytics) and analytics data (Firebase Analytics) are collected only on native apps, not on the web version.

---

## 13. Changes to This Policy

We may update this Privacy Policy from time to time to reflect changes in the Service, our practices, or legal requirements. We will update the "Last Updated" date above when we do, and where changes are material, we will provide additional notice (such as an in-app notification) before they take effect.

---

## 14. Contact Us

If you have questions about this Privacy Policy or wish to exercise any privacy rights described above, contact us at:

**[INSERT SUPPORT/PRIVACY CONTACT EMAIL]**

---

*This Privacy Policy was prepared based on a technical review of the Trombl application as implemented at the time of writing (see `docs/PRD.md`). It should be reviewed by qualified legal counsel before publication, and updated whenever the Service's data practices change — in particular, if account-deletion tooling, geolocation features, payment functionality, or new third-party integrations are added.*
