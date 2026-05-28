# NeutraWise — Enhanced Implementation Plan
**Version 2.0 (Gaps Resolved) · May 2026**

---

## Executive Summary

This is the **enhanced** implementation plan addressing all 11 gaps identified in the original Antigravity proposal. The plan is now:

- ✅ **Security-first:** RLS policies, input validation, error handling
- ✅ **Offline-first:** Conflict resolution, sync manager, queuing
- ✅ **Modular & scalable:** Clean architecture, centralized logic, comprehensive testing
- ✅ **Production-ready:** Edge Functions code, detailed database schema, monitoring setup

**Timeline:** 16 weeks (4 months) for full v1 launch

---

## Architecture Overview

### 2.1 Layered Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (Flutter UI)                        │
│  • Feature-based screens, reusable components           │
│  • Riverpod for state management                        │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (Business Logic)                          │
│  • CO₂ Calculation Engine (100% pure functions)         │
│  • Gamification Engine (rules, XP, badges, streaks)    │
│  • Input Validators (client-side)                       │
│  • Result<T> error handling pattern                     │
├─────────────────────────────────────────────────────────┤
│  Data Layer (Repositories)                              │
│  • Remote: Supabase (PostgreSQL, Auth, Edge Funcs)     │
│  • Local: Hive (offline cache, sync queue)             │
│  • Sync Manager (offline → online reconciliation)       │
├─────────────────────────────────────────────────────────┤
│  Services Layer                                          │
│  • Push Notifications (OneSignal via Edge Functions)    │
│  • Connectivity monitoring (offline detection)          │
│  • Crash reporting (optional: Sentry)                   │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Tech Stack (Finalized)

| Component | Technology | Rationale |
|---|---|---|
| Framework | Flutter (latest stable) | Cross-platform, high performance |
| State Management | Riverpod | Type-safe, dependency injection |
| Backend | Supabase (PostgreSQL) | Realtime subscriptions, Edge Functions |
| Auth | Supabase Auth + optional Biometric | Secure, OAuth support |
| Local Cache | Hive + SharedPreferences | Fast, offline-first |
| Networking | http + connectivity | With retry logic, offline detection |
| Food Search | Open Food Facts REST API | Direct client-side (acceptable for v1) |
| Push Notifications | OneSignal + Supabase Edge Functions | Scheduled + event-driven |
| Testing | mocktail, flutter_test, golden_toolkit | Comprehensive coverage |
| CI/CD | GitHub Actions | Automated testing, builds |
| Routing | go_router | Type-safe, deep linking |
| Analytics | Sentry (v1.1+) | Error tracking, performance monitoring |

---

## Proposed Phases (16 weeks total)

### Phase 1: Project Setup & Foundational Architecture (Weeks 1–3)

**Goal:** Initialize project, establish patterns, validate architecture.

**Tasks:**

1.1 **Flutter Project Initialization**
   - Create new Flutter project targeting iOS 15+, Android 10+
   - Configure build variants (dev, staging, prod)
   - Set up code generation: `build_runner`, `freezed`, `json_serializable`
   - Install core dependencies: Riverpod, go_router, Hive, supabase_flutter, http, connectivity_plus, onesignal_flutter

1.2 **Supabase Project Setup**
   - Create Supabase project (or use existing)
   - Configure Auth (Email, Google OAuth, Apple OAuth)
   - Enable Realtime on required tables
   - Set up PostgreSQL extensions: `pg_cron` (for scheduled tasks), `http` (for Edge Functions)
   - Create service role for Edge Functions

1.3 **Database Schema Migration #1: Core Tables**
   - Run schema migrations (users, daily_logs, streaks, badges, etc.)
   - Enable RLS policies
   - Create indices for performance
   - See detailed schema in Gap Analysis §5.5

1.4 **Design System Implementation**
   - Create `lib/widgets/theme/` with colors, typography, spacing
   - Build atomic components: buttons, cards, text inputs, modals
   - Implement dark mode support (system-aware + manual toggle)
   - Create reusable chart widgets (ring, bar, line)

1.5 **Folder Structure & Code Generation**
   - Set up folder structure per Gap Analysis §5.11
   - Configure `analysis_options.yaml` (linter rules)
   - Create code generation scripts for models (freezed)
   - Set up pre-commit hooks for linting

1.6 **CI/CD Pipeline (GitHub Actions)**
   - Automated testing on every PR (unit + widget tests)
   - Automated build for staging environment
   - Code coverage reports
   - Lint and format checks

**Deliverables:**
- ✅ App builds and runs on iOS/Android simulators
- ✅ Connected to Supabase (auth, database)
- ✅ Design system tokens applied to dummy screen
- ✅ CI/CD pipeline passes for all commits
- ✅ Code coverage baseline established

**Success Criteria:**
- Zero build warnings
- Design system implemented in code (reusable components)
- Database schema migrated successfully
- CI/CD tests pass

---

### Phase 2: Authentication & Onboarding (Weeks 4–5)

**Goal:** Implement Screens 1, 2, 3 with proper auth state management and profile calculation.

**Tasks:**

2.1 **Riverpod Auth State Management**
   - Build `AuthProvider` with Supabase session listener
   - Implement automatic token refresh
   - Handle session expiry (redirect to login)
   - See detailed code in Gap Analysis §5.6

2.2 **Onboarding Screens (Screen 1)**
   - Create 4–5 swipeable slides explaining NeutraWise
   - Add mascot character animations
   - Implement "Get Started" CTA → Sign-Up

2.3 **Sign-Up / Login (Screen 2)**
   - Email + password sign-up form
   - Login form with "Forgot password" flow
   - Google OAuth integration (Firebase/Supabase)
   - Apple OAuth integration (Supabase)
   - Form validation + error handling
   - See validation code in Gap Analysis §5.5

2.4 **Profile Setup (Screen 3)**
   - Three-section multi-step form: Transport, Residency, Energy & Diet
   - Form state management in Riverpod
   - Input validators (distance, kWh, residents, etc.)
   - Conditional fields (e.g., if primaryTransport = 'none', skip engine size)

2.5 **CO₂ Baseline Calculation**
   - Implement `CO2Calculator.processSignUpProfile()`
   - Strictly follow Algorithm Spec §2.3
   - Call on profile completion → store in Supabase users table
   - Unit tests: 100% coverage
   - See implementation in Gap Analysis §5.2

2.6 **Auth Navigation Guard**
   - Route guards with go_router
   - Redirect logic: unauthenticated → onboarding; authenticated but no profile → setup
   - Persisted auth state
   - See routing code in Gap Analysis §5.6

**Deliverables:**
- ✅ User can complete onboarding → sign-up → profile setup flow
- ✅ UserProfile created in Supabase with correct baseline CO₂
- ✅ Auth state persists across app restarts
- ✅ Navigation guards working correctly
- ✅ 100% unit test coverage for CO₂ baseline calculation

**Success Criteria:**
- Authentication tests pass (sign up, login, logout)
- CO₂ baseline matches Algorithm Spec calculations (validated by unit tests)
- Profile data saved to Supabase
- Auth state doesn't leak between users (RLS tests)

---

### Phase 3: Dashboard & Activity Logging (Weeks 6–10)

**Goal:** Core engagement loop: view dashboard → log activity → see impact.

**Tasks:**

3.1 **CO₂ Calculation Engine (Complete)**
   - Implement all calculation functions per Algorithm Spec:
     - `calculateTransportCO2()`
     - `calculateFoodCO2()`
     - `calculateEnergyCO2()`
     - `processDailyLog()` (orchestrator)
   - Handle edge cases: negative CO₂, missing data, unit conversions
   - Unit tests: 100% coverage (all edge cases from Algorithm Spec)
   - See detailed code in Gap Analysis §5.2

3.2 **Dashboard Screen (Screen 4)**
   - Ring chart: daily total CO₂ vs. baseline
   - Three arc segments: Transport / Food / Energy
   - Category cards: individual CO₂ values + mini progress bars
   - Weekly graph: last 7 days
   - Streak counter with fire icon (activates at ≥ 3 days)
   - Daily eco-tip carousel
   - Greeting + motivational message
   - FAB ("+") triggers Activity Log sheet
   - Realtime Riverpod subscription to users.xp (for level/streak updates)

3.3 **Activity Log Sheet (Screen 7)**
   - Bottom sheet with three tabs: Travel, Food, Energy
   - **Travel tab:**
     - "Add trip" button
     - Per-leg entry: mode selector + distance input
     - Validation: 0–1000 km, positive
     - Show estimated CO₂ preview
   - **Food tab:**
     - "Add meal" button
     - Meal slot selector: Breakfast / Lunch / Dinner / Snack
     - Food search (Open Food Facts API)
     - Serving size dropdown: small / medium / large
     - Fallback category selector (14 categories, see Gap Analysis §5.1)
     - Show estimated CO₂ preview
   - **Energy tab:**
     - Single-question UI: "How was your energy use today?"
     - Chip selector: Typical Day / More Than Usual / Less Than Usual / No AC / Cold Showers / Unplugged Devices / Solar Panels (if `hasSolar=false`)
     - User must confirm (energy.confirmed = true)
   - Submit button:
     - Validate all entries
     - Call `CO2Calculator.processDailyLog()`
     - Optimistically update UI (Riverpod)
     - Queue for offline sync (if offline)
     - Show XP award animation (celebratory)
     - Update Dashboard

3.4 **Open Food Facts Integration**
   - Client-side food search (direct API call)
   - Cache recent searches locally (Hive)
   - Debounce search input (0.5s)
   - Parse OFF API response:
     - Extract agribalyse_co2_total if present
     - Otherwise, use mapOFFCategoryToFactorKey() → fallback category
   - Show product name + estimated CO₂ for selected serving size
   - See category mapping in Gap Analysis §5.1

3.5 **Input Validators**
   - Implement all validators per Gap Analysis §5.5
   - Client-side: transport distance, food serving size, energy inputs
   - Real-time error messages below form fields
   - Form submission blocked until valid
   - Unit test: 100% coverage

3.6 **Offline Sync Architecture**
   - Hive schema: DailyLog model with sync status
   - `SyncManager` Riverpod provider (queues operations)
   - Connectivity listener: auto-sync when network restored
   - Upsert pattern: `INSERT ... ON CONFLICT (user_id, date) DO UPDATE`
   - Conflict resolution: server timestamp wins
   - See implementation in Gap Analysis §5.7

3.7 **Offline UI Feedback**
   - Banner shows "Syncing X logs..." when pending
   - Snackbar on sync success/failure
   - Retry button on failure
   - Optimistic updates (user sees instant feedback)

**Deliverables:**
- ✅ Dashboard displays daily CO₂ with ring chart
- ✅ User can log transport, food, energy activities
- ✅ CO₂ calculations match Algorithm Spec (100% tests)
- ✅ XP awarded correctly (gamification logic tested)
- ✅ Offline logging works; sync on reconnect
- ✅ Food search integrated (Open Food Facts)
- ✅ Form validation prevents bad data
- ✅ No RLS policy violations (user can only see own data)

**Success Criteria:**
- Unit test coverage: CO₂ engine 100%, sync 90%+
- End-to-end test: log activity offline → reconnect → synced correctly
- Food search returns results in < 2s
- Dashboard updates in realtime (Riverpod subscriptions)
- No crashes or uncaught exceptions

---

### Phase 4: Gamification, Insights & Leaderboard (Weeks 11–14)

**Goal:** Implement engagement systems: levels, badges, challenges, leaderboard.

**Tasks:**

4.1 **Gamification Engine (Complete)**
   - Implement per Gamification Spec:
     - XP calculation with streak multipliers and performance bonus
     - Level progression (10 levels, thresholds per spec)
     - Badge triggers (category badges, milestone badges)
     - Streak logic (increment, freeze, reset)
   - Pure functions, 95%+ unit test coverage
   - See implementation in Gap Analysis §5.8

4.2 **Insights Screen (Screen 5)**
   - Time range toggle: Week / Month
   - Trend chart (line or bar): total CO₂ over period
   - Stacked breakdown chart: Transport / Food / Energy
   - "You improved by X%" callout (when applicable)
   - CO₂ equivalences:
     - Tree-days absorbed: `totalDailyCO2 / 0.0603`
     - Car-km equivalent: `savedKg / 0.18` (hidden if negative)
     - Smartphone charges: `savedKg / 0.008` (hidden if negative)
   - Monthly target card: user-set target + progress ring
   - Emissions by category (table)
   - FAB visible (same as Dashboard)

4.3 **Gamification Screen (Screen 6)**
   - **Level banner:**
     - Current level title + progress bar to next level
     - XP remaining to level up
     - Show level-up animation when threshold crossed
   - **Active Challenges section:**
     - Cards for each active challenge
     - Fields: name, category icon, difficulty, days remaining, % progress
     - "Browse Challenges" button → modal with all challenges
   - **Badges section:**
     - Grid of earned badges (colour) + locked badges (greyed)
     - 5 category badges (bronze/silver/gold) + 9 special badges
   - **Leaderboard tabs:**
     - Global, Friends (L8+), City, Weekly Sprint
     - Each tab: rank, avatar, username, XP, badge flair
     - Current user row pinned/highlighted
     - Pagination: show top 100
     - Refresh on-demand (not realtime continuous subscription)

4.4 **Leaderboard Database Design**
   - `leaderboard_rankings` is read-only reporting table
   - Updated hourly by scheduled job (pg_cron)
   - Flutter queries on-demand (not subscribed)
   - Rank computed via `ROW_NUMBER() OVER (ORDER BY xp DESC)`
   - See schema in Gap Analysis §5.4

4.5 **Leaderboard Riverpod Provider**
   - `leaderboardProvider`: FutureProvider.family
   - Supports: global, city, weekly_sprint, friends tiers
   - Cached results with 30s TTL refresh
   - See code in Gap Analysis §5.4

4.6 **Profile Screen (Screen 9)**
   - User stats: Total CO₂ saved, Current streak, Days active, Challenges completed
   - Level card: title, XP bar, next milestone
   - Badge showcase: horizontal scroll of earned badges
   - Carbon reduction summary: cumulative saved (with equivalences)
   - Settings:
     - Notification preferences (toggles per notification type)
     - Quiet hours window (custom time range)
     - Dark mode toggle
     - Edit profile setup (re-runs processSignUpProfile)
     - Account: Change password, Sign out, Delete account (with confirmation)

**Deliverables:**
- ✅ User levels up when XP threshold crossed (animation)
- ✅ User earns badges for milestones (full-screen celebration)
- ✅ User can view leaderboard rankings (global, city, friends)
- ✅ Insights show weekly/monthly trends + equivalences
- ✅ Gamification Engine: 95%+ unit test coverage
- ✅ Profile page displays all stats
- ✅ Notification preferences saved to DB

**Success Criteria:**
- Leaderboard query < 500ms
- Level-up animation smooth (60 fps)
- Badge celebration modal not blocking interaction
- XP calculation matches Gamification Spec (all edge cases tested)
- Insights charts render correctly with various data scales

---

### Phase 5: Push Notifications & Polish (Weeks 15–16)

**Goal:** Enable engagement loop with push, add micro-interactions, final polish.

**Tasks:**

5.1 **OneSignal + Edge Functions Setup**
   - Create OneSignal account (free tier)
   - Create Supabase Edge Function: `schedule_push_notification`
   - Implement TypeScript code per Gap Analysis §5.3
   - Test locally with Supabase CLI
   - Deploy to production

5.2 **Database Triggers for Realtime Pushes**
   - PostgreSQL trigger: on level up, send push
   - PostgreSQL trigger: on badge earned, send push
   - PostgreSQL trigger: on challenge complete, send push
   - PostgreSQL trigger: on streak milestone, send push
   - See SQL in Gap Analysis §5.3

5.3 **Scheduled Push Notifications**
   - Daily log reminder (8 PM user's local time)
   - Final log warning (10:30 PM)
   - Weekly summary (Sunday 6 PM)
   - Implement via `pg_cron` + Edge Function
   - Handle timezone conversions (`AT TIME ZONE`)

5.4 **Flutter Push Notification Handler**
   - Initialize OneSignal SDK
   - Listen for notification taps
   - Route to appropriate screen (dashboard, gamification, etc.)
   - Show celebratory modal for level-up/badge notifications
   - See code in Gap Analysis §5.3

5.5 **Micro-interactions & Animations**
   - Level-up: full-screen confetti + XP counter animation
   - Badge earned: modal with shine/pulse effect
   - Challenge complete: confetti burst + XP pop
   - Streak milestone: fire animation
   - FAB: spring entrance on screen load
   - Ring chart: animated draw on dashboard load
   - XP bar: animated fill on activity submission
   - Tab transitions: smooth slide (no jarring cuts)
   - Implement using `flutter_animate`, `confetti`, custom AnimationControllers

5.6 **AI Assistant "Coming Soon" Screen**
   - Polished placeholder (Screen 8)
   - Description of planned features
   - Email sign-up field for notifications
   - No functional chat in v1

5.7 **Final UI Polish**
   - Dark mode: test on all screens
   - Responsiveness: test on various screen sizes
   - Accessibility: semantic labels, text contrast (WCAG AA)
   - Animations: verify smooth 60 fps
   - Typography: font loading, fallbacks
   - Images: optimization, lazy loading

5.8 **Error Handling & Monitoring**
   - Implement Result<T> error handling pattern (see Gap Analysis §5.9)
   - Riverpod loading/error states on all async operations
   - User-friendly error dialogs + snackbars
   - Retry logic for network errors (exponential backoff)
   - Optional: integrate Sentry for crash reporting (v1.1+)

5.9 **Testing & QA**
   - Run full test suite (unit + widget + integration)
   - Manual testing on real devices (iOS + Android)
   - Offline scenarios (airplane mode)
   - Leaderboard sync (multiple devices, simultaneous updates)
   - Push notification delivery
   - Dark mode on all screens

**Deliverables:**
- ✅ Devices receive push notifications on schedule
- ✅ App feels polished with micro-animations
- ✅ All screens responsive and accessible
- ✅ Error handling catches edge cases gracefully
- ✅ Final test suite passes (no regressions)

**Success Criteria:**
- Push notification delivery rate > 95%
- All animations smooth (60 fps, no jank)
- Test coverage maintained > 85%
- Zero critical bugs found in QA
- App Store / Play Store submission ready

---

## Detailed Specifications

### 3.1 Database Schema (Supabase PostgreSQL)

See **Gap Analysis §5.5** for complete schema including:
- Users table (profile + baseline CO₂)
- Daily logs (activity submissions)
- Streaks (track streak state)
- Badges (earned achievements)
- User challenges (active challenges + progress)
- Leaderboard rankings (reporting table)
- User relations (social graph for v1.1)
- Notification preferences
- Indices and RLS policies

**Migrations path:**
1. `001_initial_schema.sql` — Core tables
2. `002_rls_policies.sql` — Row Level Security
3. `003_triggers_and_functions.sql` — Push notifications

### 3.2 CO₂ Calculation Engine

**Source of Truth:** `lib/domain/co2_engine/emission_factors.dart`

**Modules:**
- `emission_factors.dart` — Constants (SINGLE SOURCE)
- `co2_calculator.dart` — Public API (processSignUpProfile, processDailyLog)
- `transport_calculator.dart` — Transport logic
- `food_calculator.dart` — Food logic
- `energy_calculator.dart` — Energy logic

**Unit Test Coverage:** 100%

See **Gap Analysis §5.2** for detailed implementation and test cases.

### 3.3 Gamification Engine

**Modules:**
- `gamification_engine.dart` — Main orchestrator
- `xp_calculator.dart` — XP formulas
- `level_calculator.dart` — Level progression
- `badge_evaluator.dart` — Badge triggers
- `streak_manager.dart` — Streak logic

**Unit Test Coverage:** 95%+

See **Gap Analysis §5.8** for detailed implementation and test cases.

### 3.4 Offline Sync Architecture

**Components:**
- `SyncManager` (Riverpod provider) — Queues operations, manages retries
- `SyncRepository` — Handles upsert with conflict resolution
- `Hive` — Local cache for pending logs
- Connectivity listener — Detects network changes
- Exponential backoff — Retry strategy

See **Gap Analysis §5.7** for detailed implementation.

### 3.5 Push Notifications

**Architecture:** Supabase Edge Functions → OneSignal API

**Triggers:**
- Scheduled: Daily reminders (cron via pg_cron)
- Event-driven: Badges, levels, streaks (PostgreSQL triggers)
- Manual: Admin can send campaign (future)

See **Gap Analysis §5.3** for Edge Function code and triggers.

### 3.6 Input Validation

**Client-side:** Riverpod providers with validation
**Server-side:** Supabase RLS policies + Edge Function validation
**Coverage:** Transport, food, energy, profile, leaderboard queries

See **Gap Analysis §5.5** for validator implementation.

---

## Testing Strategy

### 4.1 Test Coverage Targets

| Component | Target | Type |
|---|---|---|
| CO₂ Calculator | 100% | Unit |
| Gamification Engine | 95% | Unit |
| Input Validators | 100% | Unit |
| Sync Manager | 90% | Unit + Integration |
| Critical UI paths | 70% | Widget |
| End-to-end flows | 2–3 | Integration |
| **Overall** | **85%+** | All |

### 4.2 Test Categories

**Unit Tests:**
- CO₂ engine: all edge cases (EV, solar, heating, food conversions)
- Gamification: XP formulas, level thresholds, badge triggers, streaks
- Validators: transport, food, energy, profile inputs
- Sync manager: queue, retry, conflict resolution
- See **Gap Analysis §5.10** for detailed test cases

**Widget Tests:**
- Critical forms (Profile Setup, Activity Log)
- Ring chart rendering
- Category cards + micro-animations
- See **Gap Analysis §5.10** for example

**Integration Tests:**
- Onboard → Log → Level Up (full flow)
- Offline log → sync → leaderboard update
- Push notification tap → correct screen navigation
- See **Gap Analysis §5.10** for example

**Manual Testing (QA Checklist):**
- End-to-end user flow on iOS + Android real devices
- Realtime leaderboard updates (multiple simultaneous logins)
- Dark mode across all screens
- Offline scenarios (airplane mode)
- Push notification delivery
- Performance (no jank, smooth animations)

### 4.3 GitHub Actions CI/CD

**On every PR:**
1. Run linter (`flutter analyze`)
2. Format check (`dart format`)
3. Unit + widget tests (`flutter test`)
4. Code coverage report (min 85%)
5. Build APK/IPA (don't deploy, just verify)

**On merge to main:**
1. All above + integration tests
2. Deploy to staging environment
3. Upload to App Store / Play Store (TestFlight / Internal Testing)
4. Slack notification: "v1.0.0-beta.5 deployed"

---

## Security & Compliance

### 5.1 RLS Policies

**All user-specific tables have RLS enabled:**
- `users` — User sees only own record
- `daily_logs` — User sees/edits only own logs
- `badges`, `streaks`, `user_challenges` — Similar policies
- `leaderboard_rankings` — Public (readable by all)
- `notification_preferences` — User manages own

See **Gap Analysis §5.5** for RLS policy SQL.

### 5.2 Input Validation

**Client-side:**
- Transport distance: 0–1000 km
- Food serving: 1–5000 g
- Monthly kWh: 0–10,000
- Residents: 1–20
- Username: 2–50 characters

**Server-side:**
- Supabase RLS policies (enforced)
- Edge Function validation (redundant safety)
- Rate limiting (future: max 10 logs/day/user)

### 5.3 Authentication

**Supabase Auth handles:**
- Password hashing (bcrypt)
- Session management
- Token refresh (automatic)
- OAuth provider integration (Google, Apple)

**App handles:**
- Biometric auth (optional, v1.1+)
- Session timeout (redirect to login)
- Secure token storage (Flutter secure storage)

### 5.4 API Security

**OneSignal API key:** Stored in Supabase secrets, never exposed in app code
**Supabase API:** Auth tokens sent via HTTPS only
**Open Food Facts:** No API key (public service), rate limit with local cache + debounce

### 5.5 Data Privacy

**GDPR Compliance (future roadmap):**
- User can request data export
- User can delete account (cascade delete)
- Privacy policy + terms of service
- Cookie consent (if web version added)

---

## Deployment & Release

### 6.1 Environment Strategy

**Development:**
- Local Supabase (via Docker)
- Firebase Emulator Suite (for testing)
- Local notifications (flutter_local_notifications)

**Staging:**
- Supabase staging project
- OneSignal sandbox
- TestFlight / Internal Testing Track

**Production:**
- Supabase production project
- OneSignal production
- App Store / Play Store

### 6.2 Release Checklist

Before App Store / Play Store submission:
- [ ] All tests pass (unit, widget, integration)
- [ ] Code coverage > 85%
- [ ] Zero critical/high severity bugs
- [ ] Privacy policy & terms approved
- [ ] Screenshots + app description prepared
- [ ] Version bumped (semantic versioning)
- [ ] Changelog generated
- [ ] Beta testing complete (internal + external)
- [ ] Performance testing (no jank, < 100 ms cold start)
- [ ] Battery/memory profiling done

### 6.3 Post-Launch Monitoring

**Metrics to track:**
- DAU / MAU
- Session duration
- Activity log completion rate
- Leaderboard engagement
- Push notification opt-in rate
- Crash rate (via Sentry)
- Feature usage (analytics)

**SLOs:**
- 99.9% uptime
- < 500ms API response time
- Push delivery rate > 95%

---

## Roadmap (Post-v1)

### 7.1 v1.1 Features (Weeks 17–24)

- ✅ Barcode scanning (food entries)
- ✅ Friend add/follow UI (populate user_relations table)
- ✅ Biometric auth (Face ID, fingerprint)
- ✅ Backend proxy for OFF API (caching, rate limiting)
- ✅ Sentry integration (crash reporting)
- ✅ Backend analytics dashboard (admin panel)

### 7.2 v1.2 Features (Weeks 25–32)

- ✅ AI Assistant (real implementation; planned features from Screen 8)
- ✅ Challenge creation by users (Level 8 unlock)
- ✅ Photo proof upload (Nature challenges)
- ✅ Shared leaderboards (private friend groups)
- ✅ Weekly email digest
- ✅ Export data as PDF

### 7.3 v2.0 Vision

- ✅ Web version (Flutter Web)
- ✅ Wearable integration (Apple Watch, Wear OS)
- ✅ Smart home integration (IoT emissions)
- ✅ Carbon offset marketplace
- ✅ Community challenges

---

## Team & Responsibilities

### 8.1 Recommended Team Structure

| Role | Count | Responsibilities |
|---|---|---|
| Flutter Engineer (Lead) | 1 | Architecture, code review, critical features |
| Flutter Engineer (UI) | 1 | Screens, animations, user experience |
| Backend Engineer | 1 | Supabase, Edge Functions, database |
| QA / Tester | 1 | Manual testing, test automation, QA checklist |
| Designer | 0.5 | Polish, micro-interactions, accessibility |
| DevOps | 0.5 | CI/CD, deployments, monitoring |
| **Total** | **4.5 FTE** | |

### 8.2 Weekly Standup Cadence

- **Monday 10am:** Sprint planning + tech sync
- **Daily 2pm:** 15-min standup (blockers, progress)
- **Friday 4pm:** Sprint review + demo
- **Friday 5pm:** Retrospective + planning for next week

---

## Success Criteria & Launch Checklist

### 9.1 Pre-Launch Verification

**Functional:**
- [ ] All 9 screens implemented + tested
- [ ] CO₂ calculations match Algorithm Spec (100% unit test coverage)
- [ ] Gamification mechanics working (XP, levels, badges, streaks)
- [ ] Offline sync tested (logs queue → sync on reconnect)
- [ ] Push notifications delivering (tested on real devices)
- [ ] Leaderboard showing correct rankings
- [ ] Dark mode working on all screens

**Performance:**
- [ ] Cold start < 100 ms
- [ ] Dashboard loads < 500 ms
- [ ] Leaderboard query < 500 ms
- [ ] No memory leaks (profiled)
- [ ] Battery impact < 2% per hour (in-app usage)

**Security:**
- [ ] RLS policies enforced (user sees only own data)
- [ ] Input validation prevents bad data
- [ ] No hardcoded API keys in app code
- [ ] HTTPS-only for all network calls
- [ ] Session expires & redirects to login

**Testing:**
- [ ] Unit test coverage > 100% (critical logic)
- [ ] Widget test coverage > 70% (critical paths)
- [ ] Integration tests pass (end-to-end flows)
- [ ] Manual QA checklist completed
- [ ] Zero critical bugs

**Compliance:**
- [ ] Privacy policy published
- [ ] Terms of service finalized
- [ ] GDPR compliance roadmap
- [ ] App Store / Play Store guidelines met

### 9.2 Launch Readiness Gate

**GO / NO-GO decision criteria:**

**GO if:**
1. All tests passing
2. Code coverage ≥ 85%
3. Zero critical bugs
4. Performance benchmarks met
5. Security review passed
6. Team consensus achieved

**NO-GO if:**
1. Any critical bug unfixed
2. Code coverage < 80%
3. Performance regression > 10%
4. Security vulnerability found
5. RLS policies not enforced

---

## Appendices

### A. File Tree (See Gap Analysis §5.11)

Complete folder structure with ownership boundaries.

### B. Database Schema (See Gap Analysis §5.5)

Complete SQL schema with indices and RLS policies.

### C. CO₂ Calculator Implementation (See Gap Analysis §5.2)

Full Dart code for emission factors, calculation functions, unit tests.

### D. Gamification Engine Implementation (See Gap Analysis §5.8)

Full Dart code for XP, levels, badges, streaks, unit tests.

### E. Edge Functions (See Gap Analysis §5.3)

TypeScript code for push notification scheduling, triggers.

### F. Test Plan (See Gap Analysis §5.10)

Detailed test cases for all components.

---

## FAQs & Decision Log

### Q: Why Riverpod over Bloc?
**A:** Riverpod is more concise, type-safe, and easier to test (no setup/teardown boilerplate). Bloc is heavier but also valid; decision made for reduced code complexity.

### Q: Why direct client-side OFF API calls?
**A:** Acceptable for v1 (< 10K DAU). Backend proxy can be added in v1.1 if rate limiting becomes a bottleneck.

### Q: Why Hive for offline cache?
**A:** Fast, zero-server, supports complex objects. Alternatives: ObjectBox (more powerful), Isar (newer). Hive chosen for maturity.

### Q: Why Supabase over Firebase?
**A:** Realtime subscriptions, PostgreSQL (familiar), Edge Functions (lightweight lambdas), cost-effective. Firebase also valid but overkill for v1.

### Q: When should we add monitoring (Sentry)?
**A:** v1.1+ (not critical for launch). Implement error handling now; integrate Sentry once v1 is stable.

---

## Final Notes

This enhanced implementation plan is **production-ready** and addresses all gaps identified in the original proposal. The plan is:

- ✅ **Detailed:** Down to file structure, code snippets, SQL migrations
- ✅ **Tested:** Comprehensive testing strategy with specific coverage targets
- ✅ **Secure:** RLS policies, input validation, error handling from day one
- ✅ **Scalable:** Modular architecture, offline-first, performance optimized
- ✅ **Realistic:** 16-week timeline with 4.5 FTE team

**Estimated cost:** ~$250–350K USD (all-in for v1 launch, depending on location/rates)

**Ready to proceed with Phase 1 kickoff?** ✅

---

*NeutraWise Enhanced Implementation Plan — Version 2.0*  
*Date: May 2026*  
*Status: Ready for Development*
