# NeutraWise — Flutter Mobile App Requirements
**Version 1.0 · May 2026**
Prepared for: Google Antigravity Development Team

---

## 1. Project Overview

NeutraWise is a carbon footprint tracking and sustainability companion app. It measures, visualises, and helps reduce users' daily CO₂ emissions through real-time tracking, gamification, and AI-powered insights.

**Target feel:** Duolingo (gamification) × Fitbit (tracking dashboards) × AI assistant (personalised nudges).
**Tone:** Encouraging, friendly, optimistic — never guilt-inducing.
**Platform:** Flutter (iOS + Android). Primary design target: iPhone 14/15 form factor.

---

## 2. Branding & Design System

### 2.1 Colour Palette
| Token | Hex | Usage |
|---|---|---|
| `primary` | `#000000` | Backgrounds, primary text |
| `secondaryBlue` | `#4696D2` | CTAs, highlights, charts |
| `secondaryGreen` | `#82C92C` | Eco indicators, XP, positive states |
| `gradient` | Blue → Green | Cards, hero sections, progress rings |

### 2.2 Typography
- **Primary:** DM Sans (all body, UI labels, numbers)
- **Accent:** Sloop Script Pro (section headings, celebratory moments — use sparingly)

### 2.3 Visual Style
- Rounded corners (≥ 16px radius on cards)
- Soft card shadows
- Nature-inspired motifs: leaves, globe, organic shapes
- Minimalist iconography
- Dark mode support required (all screens)

---

## 3. App Architecture & Screen Inventory

### 3.1 UX Flow

**First-time (once):**
Launch → Onboarding → Sign-Up → Profile Setup → Dashboard

**Daily:**
Open App → Dashboard → Log Activity → View Impact / Leaderboard → Return

---

### 3.2 Screen 1 — Onboarding (3–5 slides, shown once pre-sign-up)

- Swipeable slides explaining: (a) what carbon footprint is, (b) why it matters, (c) how NeutraWise helps
- Friendly eco-themed mascot character appears across all slides
- Final slide: **"Get Started"** CTA → Sign-Up screen
- Skip option on slides 1–4; not skippable on final slide
- Smooth horizontal swipe transitions with dot-indicator progress

---

### 3.3 Screen 2 — Sign-Up / Login

Authentication methods (via Firebase Auth or equivalent):
- Email + password
- Sign in with Google
- Sign in with Apple

No profile data collected here. After successful auth → Profile Setup screen.

---

### 3.4 Screen 3 — Profile Setup ("Help us get to know you")

**Shown once, immediately post sign-up. Non-skippable.**

Three-section multi-step form:

**Section A — Transport**
- Vehicle type: Petrol / Diesel / Hybrid / EV / None (if None, skip remaining transport fields)
- Engine size (litres) — numeric input
- Vehicle model — text input (used for display only)

**Section B — Residency**
- Home type: Flat / Small House / Large House
- Number of residents — numeric stepper
- Heating type: Natural Gas / Electric / Heat Pump / LPG / Oil / District / Biomass / Coal
- Has solar panels? — boolean toggle

**Section C — Energy & Diet**
- Monthly electricity usage (kWh) — numeric input with "I don't know" option
  - If unknown: derive from home type lookup (see Algorithm Spec §2.3)
- Dietary preference: Vegan / Vegetarian / Pescatarian / Flexitarian / Omnivore / Carnivore
  - Determines daily food baseline CO₂ (see Algorithm Spec §2.3)

On completion → `processSignUpProfile()` called → `UserProfile` record inserted into Supabase `users` table → Dashboard.

---

### 3.5 Screen 4 — Home Dashboard (primary screen)

**Top section:**
- Greeting + motivational message (rotated daily)
- Streak counter with fire icon (activates at ≥ 3 days)

**Hero section:**
- Circular ring chart showing today's total CO₂ (kgCO₂e)
- Three arc segments: Transport / Food / Energy (colour-coded)
- Centre: daily total in large type; subtitle: vs. personal baseline (e.g. "−12% vs your average")

**Category cards (horizontal scroll or 3-card grid):**
- Transport · Food · Energy
- Each card: icon, category CO₂ value, mini progress bar vs. baseline

**Weekly progress graph:**
- 7-day bar or line chart (last 7 days CO₂ totals)
- Baseline reference line

**Daily eco-tip card:**
- Rotated daily; tappable for more detail

**Floating Action Button (FAB):**
- Round "+" button pinned bottom-centre
- Triggers Activity Log sheet (Screen 7)
- FAB also appears on the Insights screen

---

### 3.6 Screen 5 — Detailed Insights

**Time range toggle:** Week / Month

**Charts:**
- Line/bar trend chart (total CO₂ over selected period)
- Stacked bar or donut: breakdown by Transport / Food / Energy
- "You improved by X%" callout card when applicable

**Equivalences strip (from Algorithm Spec §2.6):**
- Tree-days absorbed = `savedKg / 0.0603`
- Car-km equivalent = `savedKg / 0.18`
- Smartphone charges = `savedKg / 0.008`

**Monthly target card:**
- User-set monthly CO₂ target (editable)
- Progress ring showing current-month total vs. target

**Emissions by category — monthly breakdown table**

FAB visible here (same as Dashboard).

---

### 3.7 Screen 6 — Gamification

**Level banner:**
- Current level title + XP progress bar to next level
- 10 levels: Eco Newcomer → Green Sprout → … → Carbon Neutral (see Gamification Spec §2)

**Active Challenges section:**
- Cards for each in-progress challenge
- Fields: name, category icon, difficulty badge, days remaining, % progress bar
- Max simultaneous challenges governed by level (1 at L1, 2 at L4, 3 at L6, 4 at L9)
- "Browse Challenges" button → modal with full challenge library (5 categories × 7 challenges)

**Badges section:**
- Grid of earned badges (colour) and locked badges (greyed)
- Category badges: Road to Green / Conscious Plate / Power Saver / Nature Keeper / Mindful Consumer — each with Bronze / Silver / Gold tiers
- Special badges: Week Warrior, Monthly Maven, Century Eco, Quiz Whiz, All-Rounder, Carbon Neutral, Leaderboard Leader, Streak Saver

**Leaderboard tab strip:** Global · Friends (L8+) · City · Weekly Sprint
- Each entry: rank, avatar, username, XP, badge flair
- Current user row always pinned/highlighted
- **v1 strategy (no social graph):** Global, City, and Weekly Sprint tabs display random users from the leaderboard pool (seeded by `country_code` and `city` for City tier). This creates a populated, competitive feel without requiring friend relationships to be explicitly added. At Level 8+, the "Friends" tab becomes available and queries the `user_relations` table (empty in v1; users can add friends post-launch).
- **Friend tab unlock:** Triggered when `users.level >= 8`. Displays users where `user_relations.user_id = current_user.id AND user_relations.relation_type = 'friend'`. If empty, show "Add friends to compete!" CTA.

---

### 3.8 Screen 7 — Daily Activity Log (Bottom Sheet / Full-Screen Modal)

Triggered by FAB. Three tabbed sections:

**Tab A — Travel**
- "Add trip" → per-leg entry: mode of transport selector (icon grid) + distance (km, numeric input or map picker)
- Mode options: My Car / Bus / Train / Metro / Bicycle / Walking / Taxi / Rideshare / Ferry / EV
- "My Car" uses `userProfile.transportFactor` automatically

**Tab B — Food**
- "Add meal" → meal slot: Breakfast / Lunch / Dinner / Snack
- Food search field (calls Open Food Facts API via `foodSearch.dart` helper)
- Search result shows product name + estimated CO₂ preview (`estimateCO2ForServing()`)
- Serving size: dropdown (small / medium / large) mapped via `PORTION_MULTIPLIERS`
- Fallback category selector (if no barcode/search match): Primary categories are:
  - **Meat & Seafood:** Red Meat · Poultry · Fish · Shellfish
  - **Dairy & Eggs:** Dairy · Eggs · Cheese · Butter
  - **Plant-Based:** Legumes · Nuts · Tofu · Vegetables · Fruits · Grains
  - **Processed:** Fast Food · Pizza · Chocolate · Coffee · Tea
  - **Default:** Vegetables (safe underestimate) — see Algorithm Spec §2.5 fallback logic

**Tab C — Energy**
- Single-question UI: "How was your energy use today?"
- Options (chip selector): Typical Day / More Than Usual / Less Than Usual / No AC / Cold Showers / Unplugged Devices / Solar Panels (only shown if `hasSolar=false`)
- User must confirm selection (sets `energy.confirmed = true` for completeness check)
- "Typical Day" = empty deviations array, confirmed=true

Submit button → calls `processDailyLog()` → returns `DailyResult` → triggers XP award animation → updates Dashboard.

**Completeness logic:**
- Full log (all 3 tabs + energy confirmed): 50 XP base
- Partial (1–2 categories): 20 XP base
- Streak multiplier applied: ×1.0 (day 1–6) / ×1.25 (day 7–29) / ×1.5 (day 30+)
- Performance bonus stacked on top: +25 XP (≥30% below baseline), +15 XP (≥15%), +8 XP (≥5%)

---

### 3.9 Screen 8 — AI Assistant ("Coming Soon" state)

Display a polished "Coming Soon" placeholder screen.
- Brief description of planned features: personalised suggestions, what-if simulator, chat-style interface
- Email sign-up field to notify user at launch
- No functional chat implemented in v1

---

### 3.10 Screen 9 — Profile

**User stats strip:** Total CO₂ saved · Current streak · Days active · Challenges completed

**Level + XP card:** Progress bar, current title, XP to next level

**Badge showcase:** Horizontal scroll of earned badges

**Carbon reduction summary:** Cumulative CO₂ saved vs. baseline (lifetime), rendered as equivalences

**Settings section:**
- Notification preferences (toggles per notification type — see §5)
- Quiet hours window (custom time range)
- Dark mode toggle
- Edit profile setup answers (re-runs processSignUpProfile on save)
- Account: Change password / Sign out / Delete account

---

## 4. CO₂ Calculation Engine

All calculations must implement `NeutraWise_Algorithm_Specification_v1.0` exactly. Key rules:

- All emission factors live exclusively in `emissionFactors.dart` — no hardcoded factors elsewhere
- EV factor is never table-looked-up; always computed at runtime: `EV_EFFICIENCY_KWH_PER_KM[engineSize] × gridIntensity`
- `mapOFFCategoryToFactorKey()` is a single shared function (not duplicated)
- `co2Per100g` is always stored as gCO₂e/100g (raw); both `estimateCO2ForServing()` and `calculateFoodItemCO2()` independently apply `/1000` conversion
- `dailyHeatingBaselineCO2` is stored explicitly in UserProfile — never reverse-engineered by subtraction
- Solar deviation tags (`solar_panels_sunny`, `solar_panels_cloudy`) hidden in UI for `hasSolar=true` users
- `avgDailyKm` is a required field for car/EV/motorcycle users — prompt on first log if missing
- `loggedAllCategories` requires `energy.confirmed = true` (not just presence of transport + food)
- XP values: full log = 50 XP base, partial = 20 XP base (not the 10–40 range in legacy code)

### CO₂ Equivalence Display
| Equivalence | Formula |
|---|---|
| Tree-days absorbed | `totalDailyCO2 / 0.0603` |
| Car-km equivalent | `co2SavedVsBaseline / 0.18` (hidden if saving is negative) |
| Smartphone charges | `co2SavedVsBaseline / 0.008` (hidden if saving is negative) |

---

## 5. Gamification System

Full specification: `NeutraWise_Gamification_System.docx`. Summary:

### XP Earning
| Activity | Base XP |
|---|---|
| Full activity log | 50 XP (× streak multiplier) |
| Partial activity log | 20 XP |
| Flashcard quiz attempt | 30 XP + 5 XP/correct answer |
| Perfect quiz score bonus | +50 XP |
| Easy challenge completion | 100 XP |
| Medium challenge completion | 200 XP |
| Hard challenge completion | 400 XP |

Daily cap: 500 XP from logging + quizzes combined. Challenge XP uncapped.

### Streak System
- Streak +1 per calendar day with ≥ 1 category logged
- Full log required for streak multiplier to apply
- Resets at midnight (user's local timezone) if no log submitted
- Streak Freeze power-up: earned at Level 4, max 1 held, protects 1 missed day

### Flashcard Quiz
- Triggered: once per day on app open, and via push notification (Tuesday & Friday, 9 AM)
- 48-hour availability window
- 10 MCQ questions (4 options each), no time limit, 1 attempt per session
- Topics: Transport, Food, Energy, Nature, Climate Science, Eco Tips (rotating)
- Post-quiz: explanation card per question shown

### Leaderboard
- Tiers: Global · Friends (L8+) · City · Weekly Sprint
- Reset: monthly (1st of month); Weekly Sprint resets Mondays
- Monthly rank rewards: #1 = +500 XP + badge; #2 = +300 XP; #3 = +200 XP; Top 10 = +100 XP; Top 25% = +50 XP

---

## 6. Push Notifications

**Architecture:** Supabase Edge Functions trigger OneSignal API calls for scheduled/event-driven notifications. All notifications in user's local timezone. Customisable in Settings (except badge/level-up).

**Setup flow:**
1. User opts in to push via OS permission dialog (iOS/Android)
2. Flutter app calls `onesignal.login(supabaseUserId)` to associate device
3. Supabase Edge Function `schedule_push_notification()` sends to OneSignal REST API
4. OneSignal delivers to user's device(s)

| Notification | Trigger | Time | Handler |
|---|---|---|---|
| Daily log reminder | No log by 8 PM | 8:00 PM | Edge Function (cron) |
| Final log warning | No log by 10:30 PM | 10:30 PM | Edge Function (cron) |
| Streak expiration warning | Streak > 0, no log | 10:30 PM | Edge Function (cron) |
| Streak milestone | Streak hits 3/7/14/30/60/100 days | Immediately | Realtime trigger (insert trigger on streaks table) |
| Challenge reminder | Challenge in progress, not logged | 12:00 PM daily | Edge Function (cron) |
| Challenge complete | All criteria met | Immediately | Realtime trigger (function call on daily_results insert) |
| Leaderboard overtaken | User surpassed in rank | Within 15 min (max 3/day) | Edge Function (periodic rank check) |
| New quiz available | Tue & Fri schedule | 9:00 AM | Edge Function (cron) |
| Badge earned | Badge trigger met | Immediately | Realtime trigger (function call on badges insert) |
| Level up | XP threshold crossed | Immediately | Realtime trigger (function call on users update) |
| Weekly summary | Every Sunday | 6:00 PM | Edge Function (cron) |

---

## 7. User Data Model

Fields stored per user in DB:

```
User {
  // Identity
  name, email, city, countryCode

  // Transport profile
  primaryTransport, fuelType, engineSize, vehicleAge, vehicleModel
  avgDailyKm, transportFactor

  // Energy profile
  homeType, residents, heatingType, hasSolar
  dailyEnergyBaselineKwh, dailyHeatingBaselineCO2
  dailyEnergyBaselineCO2, gridIntensity

  // Food profile
  dietaryPreference, dailyFoodBaselineCO2

  // Aggregate baseline
  totalDailyBaselineCO2

  // Gamification
  xp, level, currentStreak, longestStreak
  daysActive, badgesEarned[], challengesCompleted[]
  challengesInProgress[], streakFreezeCount

  // Progress
  totalCO2Saved, weeklyProgress[], monthlyProgress[]
  emissionsByCategory{}

  // Settings
  notificationPreferences{}, quietHoursStart, quietHoursEnd
  darkModeEnabled
}
```

---

## 8. Technical Requirements

- **Framework:** Flutter (latest stable)
- **Backend:** Supabase (PostgreSQL + Realtime API)
- **Auth:** Supabase Auth (Email/Password, Google OAuth, Apple OAuth)
- **Database:** PostgreSQL (Supabase-hosted) — realtime subscriptions for leaderboard
- **Food API:** Open Food Facts (OFF) REST API — barcode lookup + category search
- **Push Notifications:** OneSignal (integrated via Supabase Edge Functions) — see §6.1 for rationale
- **State Management:** Riverpod or Bloc (team preference)
- **Offline support:** Hive or SharedPreferences for local cache of last 7 days of logs; Supabase Realtime resync on reconnect
- **Emission factors:** Versioned constants file in `lib/data/constants/emission_factors.dart`; store `emissionFactorVersion` on each `DailyResult` record
- **Dark mode:** System-aware + manual override in Settings
- **Minimum OS:** iOS 15 / Android 10

---

## 9. Animations & Micro-interactions

- Level-up: full-screen celebration animation with confetti
- Badge earned: full-screen modal with shine/pulse effect
- Challenge complete: confetti burst + XP counter increment animation
- Streak milestone: fire animation + XP pop
- FAB: spring entrance animation on Dashboard/Insights load
- Ring chart: animated draw on Dashboard load
- XP bar: animated fill on log submission
- Tab transitions: smooth slide (no jarring cuts)

---

## 10. Out of Scope for v1

- **AI Assistant screen:** Implement as polished "Coming Soon" placeholder
- **Challenge creation by users:** Planned for Level 8 unlock in future
- **Friend add/follow UI:** Social graph exists in DB schema (`user_relations` table) but add-friend flow deferred to v1.1. For v1, Friends tab is locked until Level 8, then shows empty state with "Add friends to compete!" CTA.
- **Photo proof upload for Nature challenges:** Manual checkbox confirm only (no image upload in v1)
- **Barcode scanning:** Food entry via text search only; barcode scanning deferred to v1.1

---

## 11. Supabase Database Schema (Reference)

Core tables for v1 implementation. Use this as the ground truth for migrations.

### Core Tables

```sql
-- Users (extends auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  city TEXT,
  country_code CHAR(2),
  avatar_url TEXT,
  
  -- Transport profile
  primary_transport TEXT CHECK (primary_transport IN ('car', 'ev', 'motorcycle', 'bus', 'train', 'metro', 'bicycle', 'walking', 'ferry', 'taxi', 'rideshare')),
  fuel_type TEXT,
  engine_size NUMERIC,
  vehicle_age TEXT,
  vehicle_model TEXT,
  avg_daily_km NUMERIC,
  transport_factor NUMERIC,
  
  -- Energy profile
  home_type TEXT,
  residents INT,
  heating_type TEXT,
  has_solar BOOLEAN,
  daily_energy_baseline_kwh NUMERIC,
  daily_heating_baseline_co2 NUMERIC,
  daily_energy_baseline_co2 NUMERIC,
  grid_intensity NUMERIC,
  
  -- Food profile
  dietary_preference TEXT,
  daily_food_baseline_co2 NUMERIC,
  
  -- Aggregate baseline
  total_daily_baseline_co2 NUMERIC,
  
  -- Gamification
  xp INT DEFAULT 0,
  level INT DEFAULT 1,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  days_active INT DEFAULT 0,
  streak_freeze_count INT DEFAULT 0,
  
  -- Progress
  total_co2_saved NUMERIC DEFAULT 0,
  
  -- Settings
  dark_mode_enabled BOOLEAN DEFAULT FALSE,
  notifications_enabled BOOLEAN DEFAULT TRUE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Daily logs (activity submissions)
CREATE TABLE daily_logs (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  
  -- Transport entries (JSON array)
  transport_entries JSONB,
  transport_co2 NUMERIC,
  
  -- Food entries (JSON array)
  food_entries JSONB,
  food_co2 NUMERIC,
  
  -- Energy deviations (JSON)
  energy_deviations JSONB,
  energy_co2 NUMERIC,
  
  -- Results
  total_daily_co2 NUMERIC,
  baseline_co2 NUMERIC,
  co2_saved_vs_baseline NUMERIC,
  percent_vs_baseline NUMERIC,
  xp_earned INT,
  emission_factor_version VARCHAR,
  
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- Streaks (track streaks per user)
CREATE TABLE streaks (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  last_log_date DATE,
  streak_freeze_used_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Badges earned
CREATE TABLE badges (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_name VARCHAR NOT NULL,
  badge_tier VARCHAR, -- 'bronze', 'silver', 'gold', or null for special badges
  earned_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, badge_name, badge_tier)
);

-- Active challenges
CREATE TABLE user_challenges (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge_id VARCHAR NOT NULL, -- reference to challenge library
  challenge_name VARCHAR NOT NULL,
  category VARCHAR NOT NULL,
  difficulty VARCHAR NOT NULL,
  duration_days INT,
  completion_criteria JSONB,
  xp_reward INT,
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  progress_percent INT DEFAULT 0,
  UNIQUE(user_id, challenge_id)
);

-- Leaderboard rankings (materialized view updated hourly)
CREATE TABLE leaderboard_rankings (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  xp INT NOT NULL,
  level INT NOT NULL,
  global_rank INT,
  city_rank INT,
  weekly_rank INT,
  leaderboard_type VARCHAR, -- 'global', 'city', 'weekly_sprint'
  period_start DATE,
  period_end DATE,
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, leaderboard_type, period_start)
);

-- Social graph (friendships; empty in v1)
CREATE TABLE user_relations (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  related_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  relation_type VARCHAR CHECK (relation_type IN ('friend', 'blocked')),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, related_user_id),
  CHECK(user_id != related_user_id)
);

-- Push notification preferences
CREATE TABLE notification_preferences (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  daily_log_reminder BOOLEAN DEFAULT TRUE,
  streak_warnings BOOLEAN DEFAULT TRUE,
  challenge_reminders BOOLEAN DEFAULT TRUE,
  leaderboard_overtake BOOLEAN DEFAULT TRUE,
  quiz_available BOOLEAN DEFAULT TRUE,
  badge_earned BOOLEAN DEFAULT TRUE,
  level_up BOOLEAN DEFAULT TRUE,
  weekly_summary BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indices for common queries
CREATE INDEX idx_daily_logs_user_date ON daily_logs(user_id, date DESC);
CREATE INDEX idx_badges_user ON badges(user_id);
CREATE INDEX idx_user_challenges_user ON user_challenges(user_id, completed_at);
CREATE INDEX idx_leaderboard_global ON leaderboard_rankings(xp DESC) WHERE leaderboard_type = 'global';
CREATE INDEX idx_leaderboard_city ON leaderboard_rankings(city_rank) WHERE leaderboard_type = 'city';
CREATE INDEX idx_user_relations ON user_relations(user_id, relation_type);
```

### Realtime Subscriptions (for Flutter app)

Enable realtime on these tables in Supabase dashboard → Replication:
- `daily_logs` (notify app of new logs)
- `leaderboard_rankings` (update leaderboard UI)
- `streaks` (update streak counter)
- `badges` (animate badge awards)
- `users` (sync level/xp changes)

Example Flutter listener:
```dart
supabase
  .from('leaderboard_rankings')
  .on(RealtimeListenTypes.postgresChanges,
    event: PostgresChangeEvent.all,
    callback: (payload) {
      setState(() {
        leaderboard = payload.newRecord;
      });
    })
  .subscribe();
```

---

## APPENDIX A — Implementation Decision Rationale

### A.1 Open Food Facts Fallback Categories

**Question:** What are the primary food categories we should support as fallbacks?

**Answer:** The following category structure balances user control with CO₂ accuracy. Each category maps to `FOOD_CATEGORY_FACTORS` entries per Algorithm Spec §2.5:

| Category | Fallback Keys | CO₂ Factor (kgCO₂e/kg) | Notes |
|---|---|---|---|
| **Red Meat** | beef, veal, lamb, mutton | 39.2–60.0 | Highest impact; allow refinement by meat type |
| **Poultry** | chicken, turkey, poultry | 9.9 | Lower than red meat; fixed factor |
| **Fish (Wild)** | fish, seafood | 3.0 | Default for user-selected "fish"; distinguish from farmed |
| **Shellfish** | shrimp, prawn, crab | 26.9 (farmed) | High factor; rare user input but important |
| **Dairy** | milk, yogurt, butter, cheese | 2.9–23.8 | Range wide; recommend sub-category select if user wants accuracy |
| **Eggs** | egg | 4.5 | Fixed; low variance |
| **Legumes** | legumes, lentils, beans, pulses | 0.9 | Lowest plant impact |
| **Nuts** | nuts, almonds | 2.3 | Moderate plant-based |
| **Grains & Bread** | rice, wheat, pasta, bread | 1.6–4.0 | Narrow range; combine as single category |
| **Vegetables** | vegetables, potatoes, leafy greens | 0.4–0.46 | Safe underestimate default |
| **Fruits** | fruits, berries | 0.7 | Moderate; slightly higher than veg |
| **Fast Food** | burger, fries, pizza | 4.0–0.5 | High variance; allow user type refinement |
| **Chocolate** | chocolate, cocoa | 19.0 | High; specific category |
| **Coffee/Tea** | coffee, tea | 3.5–17.0 | Beverages; tea much lower than coffee |

**Implementation logic (pseudocode):**
```
if OFF_product.agribalyse_co2_total exists:
  use agribalyse value
else if user_selected_category in above_table:
  use FOOD_CATEGORY_FACTORS[category_key]
else:
  default to vegetables_avg (0.4 kgCO₂e/kg) — safe underestimate
```

**UI presentation:** 
- Show categories as a grid of icons + labels (not a dropdown) for scannability
- After category select, optional sub-category prompt if variance is wide (e.g. Dairy → Cheese / Milk / Butter / Yogurt)

---

### A.2 Leaderboard Population Strategy (No Social Graph in v1)

**Question:** Should the "Friends" tab display dummy friends, or query a mock user relations table with auto-generated friendships?

**Answer:** **Query a real `user_relations` table seeded with zero rows; show empty state for v1; populate Global/City/Weekly Sprint with random real users.**

**Rationale:**
1. **Future-proof:** The `user_relations` table exists in the schema from day one, so adding friend functionality in v1.1 requires zero DB schema changes
2. **Realistic leaderboard:** Global, City, and Weekly Sprint tabs show a growing pool of real app users (or deterministic seeded test users), creating authentic competition feel without artificial fake profiles
3. **Level 8 unlock is real:** When user reaches L8, the Friends tab activates and queries `user_relations`. On day one, it's empty ("You haven't added friends yet"), but the UI is production-ready for when friends are added
4. **No confusing mock data:** Avoids showing "100 auto-generated dummy friends" that disappear post-v1

**Database schema (Supabase):**
```sql
CREATE TABLE user_relations (
  id BIGINT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  related_user_id UUID NOT NULL REFERENCES auth.users(id),
  relation_type TEXT NOT NULL CHECK (relation_type IN ('friend', 'blocked')),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, related_user_id),
  CHECK(user_id != related_user_id)
);

-- For mutual friendship, insert two rows:
-- (user_A → user_B, 'friend')
-- (user_B → user_A, 'friend')
```

**Leaderboard query for Friends tab (Level 8+):**
```sql
SELECT u.id, u.name, u.xp, u.level, u.badges_earned,
       ROW_NUMBER() OVER (ORDER BY u.xp DESC) AS rank
FROM users u
INNER JOIN user_relations ur ON u.id = ur.related_user_id
WHERE ur.user_id = $1 AND ur.relation_type = 'friend'
ORDER BY u.xp DESC
LIMIT 50;
```

**Global/City/Weekly Sprint leaderboards (all levels):**
```sql
-- Global: top 100 users worldwide
SELECT u.id, u.name, u.xp, u.level, u.badges_earned,
       ROW_NUMBER() OVER (ORDER BY u.xp DESC) AS rank
FROM users u
WHERE u.xp > 0
ORDER BY u.xp DESC
LIMIT 100;

-- City: top 50 users in user's city (if city is set)
SELECT u.id, u.name, u.xp, u.level, u.badges_earned, u.city,
       ROW_NUMBER() OVER (ORDER BY u.xp DESC) AS rank
FROM users u
WHERE u.city = $1 AND u.xp > 0
ORDER BY u.xp DESC
LIMIT 50;
```

**UI behavior in v1:**
- Global tab: Always shows random users from top 100
- City tab: Always shows random users from city (or "No users in your city yet" if count < 5)
- Weekly Sprint: Always shows users in current week's leaderboard_rankings table
- Friends tab: Locked (greyed) until user.level >= 8; shows empty state with "Unlock at Level 8" overlay; once unlocked, shows empty list + "Add friends to compete!" CTA + link to Settings

---

### A.3 Push Notification Strategy: Supabase + OneSignal

**Question:** Which push provider should integrate with Supabase, and should v1 use real notifications or mock local notifications?

**Answer:** **Use OneSignal integrated via Supabase Edge Functions for production readiness; optionally fall back to `flutter_local_notifications` for local development/testing.**

**Rationale:**

| Aspect | OneSignal + Edge Functions | flutter_local_notifications only |
|---|---|---|
| **v1 scope** | Real device push (production-ready) | Mock local; requires simulator/emulator testing |
| **User expectation** | Device notifications appear in native tray | In-app only; no background delivery |
| **Monetization** | OneSignal free tier: 30K monthly users | N/A (no external cost) |
| **Setup complexity** | Moderate (Edge Functions + OneSignal SDK) | Simple (add Flutter package) |
| **Analytics** | OneSignal dashboard tracks delivery/opens | No built-in analytics |
| **Scalability** | Proven for millions of users | Only suitable for prototype |
| **Recommendation** | ✅ Choose this | ❌ Prototype only |

**Architecture: OneSignal + Supabase Edge Functions**

**1. Supabase Edge Function: `schedule_push_notification()`**

Deployed at: `https://your-project.supabase.co/functions/v1/schedule_push_notification`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const ONESIGNAL_API_KEY = Deno.env.get("ONESIGNAL_API_KEY")!
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!

serve(async (req) => {
  const { user_id, title, message, data } = await req.json()

  // Send to OneSignal via REST API
  const response = await fetch("https://onesignal.com/api/v1/notifications", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${ONESIGNAL_API_KEY}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      include_external_user_ids: [user_id],
      headings: { en: title },
      contents: { en: message },
      data, // Custom fields (e.g., streak count, XP earned)
      ios_channel_id: "default",
      android_channel_id: "default",
    }),
  })

  return new Response(JSON.stringify({ ok: response.ok }), { status: 200 })
})
```

**2. Database Trigger: Auto-send on streak milestone**

```sql
-- Trigger on streaks table: sends push when milestone hit
CREATE FUNCTION notify_streak_milestone()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.streak_days IN (3, 7, 14, 30, 60, 100) THEN
    SELECT net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
      payload := json_build_object(
        'user_id', NEW.user_id,
        'title', 'Streak Milestone! 🔥',
        'message', 'You''ve reached ' || NEW.streak_days || ' days in a row!',
        'data', json_build_object('streak_days', NEW.streak_days)
      )::text,
      headers := json_build_object(
        'Authorization', 'Bearer ' || current_setting('app.supabase_jwt_secret'),
        'Content-Type', 'application/json'
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_streak_update AFTER INSERT OR UPDATE ON streaks
FOR EACH ROW EXECUTE FUNCTION notify_streak_milestone();
```

**3. Scheduled notifications (cron via Edge Functions + pg_cron)**

Install `pg_cron` in Postgres:
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Daily log reminder at 8 PM (runs at 8 PM UTC; adjust for user's timezone in Edge Function)
SELECT cron.schedule('daily_log_reminder', '0 20 * * *', $$
  SELECT
    net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/schedule_daily_push',
      payload := '{"type":"daily_log_reminder"}'::text,
      headers := json_build_object('Content-Type', 'application/json')
    )
$$);
```

**4. Flutter App Integration**

```dart
// In main.dart or init method:
import 'package:onesignal_flutter/onesignal_flutter.dart';

void initOneSignal() {
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(ONESIGNAL_APP_ID);
  
  // Link to authenticated user
  OneSignal.login(supabaseUser.id);
  
  // Handle notification taps
  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData;
    if (data != null && data['type'] == 'challenge_complete') {
      // Navigate to Gamification screen
      navigateTo(GamificationScreen.route);
    }
  });
}
```

**5. Local notifications fallback (development/testing)**

For offline testing or when OneSignal is unavailable:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final localNotifications = FlutterLocalNotificationsPlugin();

Future<void> showLocalNotification(String title, String body) async {
  await localNotifications.show(
    0,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails('neutrawise_channel', 'NeutraWise Notifications'),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

// Use conditionally:
if (kDebugMode || !oneSignalReady) {
  await showLocalNotification(title, body);
} else {
  // OneSignal handles it
}
```

**Setup Checklist:**

1. ✅ Create OneSignal account (free tier)
2. ✅ Create Supabase Edge Function (or use scheduled functions in `pg_cron`)
3. ✅ Add `onesignal_flutter` to `pubspec.yaml`
4. ✅ Request push permission on app launch (iOS 13+)
5. ✅ Add environment variables to Supabase project (ONESIGNAL_API_KEY, ONESIGNAL_APP_ID)
6. ✅ Test with local notifications during dev
7. ✅ QA with real OneSignal before launch

**Cost:** OneSignal free tier covers up to 30K monthly users → sufficient for v1 launch. Premium tiers scale from $99/month.

---

*NeutraWise Requirements · v1.0 · May 2026*
*Appendix A — Implementation Decisions*
