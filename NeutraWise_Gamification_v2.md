# 🌿 NeutraWise — Gamification System Design
## Version 3.0 · Reviewed, Corrected & Ready to Implement

*XP · Levels · Challenges · Badges · Streaks · Leaderboard · Quizzes · Push Notifications*

---

## 0. Audit Summary — What Changed from v2 and Why

This version resolves all issues found in the v2 review. The table below is a changelog. Every decision in the document traces back to a finding here.

| ID | Severity | Issue | Resolution |
|---|---|---|---|
| GAP-01 | High | XP timing contradicted itself (midnight vs immediate) | XP awarded immediately on submission; idempotent delta-upgrade if log improved later |
| GAP-02 | High | Performance bonus fired on partial logs against full baseline | Performance bonus requires full log (all 3 categories + energy confirmed) |
| GAP-03 | High | Streak multiplier used single streak counter; partial/full not distinguished | Two streak counters: `streak_days` (any log) and `full_log_streak_days` (full log); multiplier uses `full_log_streak_days` |
| GAP-04 | Medium | Daily XP cap of 500 is unreachable by legitimate means; misleading | Cap replaced with per-source limits. Cap removed from documentation as a number. |
| GAP-05 | Medium | Offline sync cap check used arrival date, not log date | `awardDailyXP` takes explicit `logDate` parameter; cap is per log date |
| GAP-06 | Medium | Race condition between log submission and midnight audit | Row-level locking (SELECT FOR UPDATE) on `user_challenges` required |
| GAP-07 | High | Meatless Monday required date-awareness the engine lacked | Resolved via INCON-04: renamed to Meat-Free Day, no day constraint |
| GAP-08 | Critical | `food_waste_logged` field does not exist in DailyResult | Zero Food Waste Day deferred to v1.2; requires new UI toggle and schema field |
| GAP-09 | Critical | `food_category` is per-item array, not a scalar field | New match modes: `food_all_match` and `food_none_match` strategy variants |
| GAP-10 | Critical | `transport_mode` is per-leg array, not a scalar field | New match modes: `transport_any_match` and `transport_all_match` strategy variants |
| GAP-11 | Medium | `carpool` is not a valid transport mode in the algorithm spec | Removed; Carpool Champion uses `rideshare` only |
| GAP-12 | Medium | No Car Weekend had no enforcement that it runs Sat–Sun | Challenge can only be started on Saturday; UI enforces this |
| GAP-13 | Medium | "Quiz bonus XP unlocked at Level 5" undefined | Clarified: perfect-score +50 XP bonus is only available from Level 5+ |
| GAP-14 | Medium | Streak Freeze awarded at Level 4 AND 30-day streak; conflict undefined | Freeze queued if earned below Level 4; activates on reaching Level 4 |
| GAP-15 | High | Nature Silver/Gold badges required 7–12 completions of a single hard challenge (5–7 years) | Nature badge thresholds adjusted: Bronze=1, Silver=2, Gold=3 |
| GAP-16 | Critical | Two XP values (lifetime, monthly) never explicitly named or separated | Explicit DB fields: `lifetime_xp` (for levels) and `monthly_xp` (for leaderboard) |
| GAP-17 | Low | All-Rounder badge undefined when new categories added | Badge evaluated against categories active at time of earning; not retroactively upgraded |
| GAP-18 | Low | Challenge reminder fires at noon regardless of whether user already logged | Reminder suppressed if user has already logged today |
| INCON-01 | Medium | Streak and challenge missing-day logic used different sources of truth | Both systems query the same `daily_logs` table for the same user/date |
| INCON-02 | Low | "Partial log maintains streak" vs "any log passes APP_BEHAVIOR" — same definition, not stated | Explicitly aligned: ≥1 category logged = partial log = streak maintained = APP_BEHAVIOR passes |
| INCON-03 | High | Consecutive challenges with window == required_days had zero tolerance for missed days | All consecutive challenges given buffer days: No Car Week → 10-day window; Public Transport Month → 35-day window; Vegan Challenge → 35-day window; Plant-Based Week → 9-day window |
| INCON-04 | High | Meatless Monday in a 7-day window contained only one valid qualifying day | Renamed to Meat-Free Day; 1-day window; user picks any day; no day-of-week constraint |
| INCON-05 | Low | `completed` and `cooldown` were two statuses for the same state | Merged: one `completed` status; cooldown timer derived from `cooldown_ends_at` vs today |
| INCON-06 | Medium | Overtake notification promised "within 15 minutes" but leaderboard updates hourly | Corrected: overtake delivered within 1 hour of rank change |
| IMPL-01 | Critical | Zero Food Waste Day unimplementable without schema change | Deferred to v1.2 |
| IMPL-02 | Critical | Engine couldn't evaluate multi-entry food/transport arrays | New strategy variants cover array evaluation |
| IMPL-03 | Medium | Engine lacked date-awareness for day-of-week constraints | Resolved via INCON-04 |
| IMPL-04 | Low | No queuing mechanism for Streak Freeze below Level 4 | `streak_freeze_queued` boolean added to user schema |
| IMPL-05 | Critical | Schema had one XP field; two are required | `lifetime_xp` and `monthly_xp` separated |
| IMPL-06 | Low | O(N×M) challenge evaluation at scale | Documented as known concern for v2.0+ |

---

## 1. Design Philosophy

NeutraWise borrows proven mechanics from the most engaging apps in the world — adapted for a sustainability context.

**Duolingo — The streak is everything.** Users with a 7-day streak have 2.4× the 30-day retention of users with no streak. The streak is tied to a real-world impact behaviour (logging), not just app-opening. Early levels must feel fast: if users don't feel progress in the first three days, they leave.

**Habitica — Gamification only works if the loop is frictionless.** The activity log must be completable in under 90 seconds. Any friction = streak broken = user churns.

**Fitbit — Show what numbers mean.** CO₂ equivalences (tree-days, car-km, charges) translate abstract data into visceral impact, borrowed directly from Fitbit's step-to-miles approach.

**Pokémon GO — Variable reward schedules.** Not knowing the exact quiz questions, seeing challenges rotate, and the performance bonus as a variable outcome all exploit the same proven engagement mechanic.

**Strava — Overtake notifications are the most-acted-upon notification in fitness apps.** Replicated with a frequency cap to prevent fatigue.

**Clash of Clans — Monthly season resets keep everyone competitive.** Without resets, early users accumulate insurmountable leads and new users see no path to the top.

**Xbox/Steam — Badge earning rate should be 10–30%.** Earned by 80%+ = meaningless. Earned by <1% = discouraging. NeutraWise badge thresholds are calibrated for this range.

---

## 2. Core Data Model

These are the canonical fields that the gamification system reads and writes. All other sections reference these names.

### 2.1 Users Table (Gamification Fields)

```sql
users {
  -- XP (TWO DISTINCT FIELDS — never conflate them)
  lifetime_xp        INTEGER NOT NULL DEFAULT 0,  -- never decreases; used for level calculation
  monthly_xp         INTEGER NOT NULL DEFAULT 0,  -- reset to 0 on 1st of each month; used for leaderboard ranking

  -- Level (derived from lifetime_xp; recomputed on every XP update)
  level              INTEGER NOT NULL DEFAULT 1,   -- 1–10

  -- Streak (TWO COUNTERS — never conflate them)
  streak_days            INTEGER NOT NULL DEFAULT 0,  -- increments on ANY log (partial or full)
  full_log_streak_days   INTEGER NOT NULL DEFAULT 0,  -- increments only on FULL log (all 3 categories + energy confirmed)
  last_log_date          DATE,                         -- used to detect missed days

  -- Streak Freeze
  streak_freeze_held     BOOLEAN NOT NULL DEFAULT FALSE,  -- user currently holds a freeze
  streak_freeze_queued   BOOLEAN NOT NULL DEFAULT FALSE,  -- freeze earned but user is below Level 4

  -- Daily XP tracking (for cap enforcement per log date)
  last_daily_xp_date     DATE,
  daily_xp_from_log      INTEGER NOT NULL DEFAULT 0,   -- XP from logging on last_daily_xp_date
  daily_xp_from_quiz     INTEGER NOT NULL DEFAULT 0,   -- XP from quiz on last_daily_xp_date
}
```

> **Why two XP fields?** Lifetime XP never resets — it is the source of truth for levels. Monthly XP resets every month — it is the source of truth for leaderboard ranking. Conflating them would mean either levels reset monthly (wrong) or the leaderboard never resets (wrong).

> **Why two streak counters?** The streak counter (`streak_days`) decides retention — any log keeps it alive. The full-log counter (`full_log_streak_days`) decides the XP multiplier — only a complete log earns the multiplier bonus. These are different incentives and must not share a field.

### 2.2 Challenge-Related Tables

```sql
challenges {
  id                UUID PRIMARY KEY,
  name              TEXT NOT NULL,
  category          TEXT NOT NULL,        -- transport | food | energy | nature
  difficulty        TEXT NOT NULL,        -- easy | medium | hard
  duration_type     TEXT NOT NULL,        -- single_day | multi_day
  window_days       INTEGER NOT NULL,     -- total days the challenge window stays open
  required_days     INTEGER NOT NULL,     -- qualifying days needed to complete
  consecutive       BOOLEAN NOT NULL,     -- must qualifying days be consecutive?
  xp_reward         INTEGER NOT NULL,     -- base XP before decay
  strategy          TEXT NOT NULL,        -- see Section 6.1
  strategy_params   JSONB NOT NULL,       -- strategy-specific config
  start_day_constraint TEXT,             -- e.g. 'saturday' — UI enforces this
  is_active         BOOLEAN DEFAULT TRUE,
}

user_challenges {
  id                UUID PRIMARY KEY,
  user_id           UUID NOT NULL,
  challenge_id      UUID NOT NULL,
  status            TEXT NOT NULL DEFAULT 'in_progress',  -- in_progress | completed | failed
  started_at        DATE NOT NULL,
  deadline_at       DATE NOT NULL,        -- started_at + window_days
  completed_at      DATE,
  days_passed       INTEGER DEFAULT 0,
  cooldown_ends_at  DATE,                 -- populated on completion; NULL means available
  UNIQUE(user_id, challenge_id, started_at)
}

challenge_completions {
  id              UUID PRIMARY KEY,
  user_id         UUID NOT NULL,
  challenge_id    UUID NOT NULL,
  completed_at    DATE NOT NULL,
  xp_awarded      INTEGER NOT NULL,
  completion_num  INTEGER NOT NULL,       -- 1 = first time, 2 = second, etc.
}
```

> **Status is two values, not five.** `in_progress` and `completed` (plus `failed`). There is no separate `cooldown` or `available` status. Cooldown is derived by comparing `cooldown_ends_at` to today. Available is derived by the absence of any active `user_challenges` row for that challenge.

---

## 3. XP System

### 3.1 Design Principles

1. **Reward consistency above depth.** Daily logging every day for a month beats binge-logging one week.
2. **Reward depth secondarily.** Full logs, perfect quizzes, and hard challenges pay meaningfully more than partial engagement.
3. **Never punish.** The system is additive-only. Missing a day costs a streak but never subtracts XP.
4. **Prevent grinding.** Repeat challenge completions decay in value. Quiz XP is capped per session.
5. **Maintain relevance at all levels.** Level multipliers give advanced users a slight edge — not an overwhelming advantage.

### 3.2 XP Sources

| Source | XP | Notes |
|---|---|---|
| Daily Log — Full (all 3 categories confirmed) | **50 XP** | Base before multipliers |
| Daily Log — Partial (1–2 categories) | **20 XP** | Base before multipliers; no performance bonus |
| CO₂ Performance Bonus — ≥5% below baseline | **+8 XP** | Full log only; added after multipliers |
| CO₂ Performance Bonus — ≥15% below baseline | **+15 XP** | Full log only; only highest tier applies |
| CO₂ Performance Bonus — ≥30% below baseline | **+25 XP** | Full log only; only highest tier applies |
| Quiz Attempt | **30 XP** | Awarded on submission regardless of score |
| Quiz — Per Correct Answer | **+5 XP** | Max +50 XP for 10/10 |
| Quiz — Perfect Score Bonus | **+50 XP** | Level 5+ only; stacks with per-question XP; max session total 130 XP |
| Challenge Completion — Easy | **100 XP** | Subject to repeat decay; floor 50 XP |
| Challenge Completion — Medium | **200 XP** | Subject to repeat decay; floor 100 XP |
| Challenge Completion — Hard | **400 XP** | Subject to repeat decay; floor 200 XP |
| Streak Milestone — 3 days | **+25 XP** | One-time per milestone |
| Streak Milestone — 7 days | **+75 XP** | One-time per milestone |
| Streak Milestone — 14 days | **+150 XP** | One-time per milestone |
| Streak Milestone — 30 days | **+300 XP** | One-time per milestone |
| Streak Milestone — 60 days | **+600 XP** | One-time per milestone |
| Streak Milestone — 100 days | **+1000 XP** | One-time per milestone |
| Monthly Leaderboard — Rank #1 | **+500 XP** | Added to lifetime_xp and next month's monthly_xp |
| Monthly Leaderboard — Rank #2 | **+300 XP** | Same |
| Monthly Leaderboard — Rank #3 | **+200 XP** | Same |
| Monthly Leaderboard — Top 10 | **+100 XP** | Same |
| Monthly Leaderboard — Top 25% | **+50 XP** | Same |

### 3.3 XP Formula (Daily Log and Quiz)

```
Final XP = round( Base XP × Streak Multiplier × Level Multiplier ) + Performance Bonus
```

**Performance bonus is added after multiplication.** It rewards CO₂ reduction (an outcome), not time-in-app behaviour. Amplifying it via multipliers would create a perverse incentive.

**Challenge XP, streak milestone XP, and leaderboard XP bypass this formula entirely.** They are applied directly to both `lifetime_xp` and `monthly_xp` with no multipliers.

#### Streak Multiplier

Uses `full_log_streak_days` — the consecutive-full-log counter. A partial log today does NOT advance this counter and does NOT earn a multiplier.

| `full_log_streak_days` | Multiplier | Effect on 50 XP full log |
|---|---|---|
| 0–6 | ×1.00 | 50 XP |
| 7–29 | ×1.25 | 63 XP |
| 30–99 | ×1.50 | 75 XP |
| 100+ | ×1.75 | 88 XP 🔥 |

#### Level Multiplier

Uses current `level` field (derived from `lifetime_xp`).

| Level | Multiplier |
|---|---|
| 1–4 | ×1.00 |
| 5–8 | ×1.10 |
| 9–10 | ×1.20 |

### 3.4 XP Timing — Immediate with Delta Upgrade

XP is awarded **immediately** when a log is submitted. If the user later updates the same day's log to add more categories, only the **delta** is awarded. The system is idempotent per log date.

```
Example:
  10:00 AM — User logs transport only (partial). Earns 20 XP.
  13:00 PM — User adds food entries. Log is now transport + food (still partial). Earns 0 XP delta.
  19:00 PM — User adds energy and confirms. Log is now full. Earns 30 XP delta (50 - 20 already awarded).
             Performance bonus also evaluated now: +15 XP if ≥15% below baseline.
  Total day: 20 + 30 + 15 = 65 XP. Correct: matches what a single full-log submission would earn.
```

### 3.5 Per-Source XP Limits (replaces the "500 cap")

The v2 document stated a "500 XP daily cap." In practice, the maximum achievable via legitimate daily logging and one quiz session is approximately 260 XP, making 500 a meaningless ceiling. The cap is replaced by per-source limits:

| Source | Per-Session / Per-Day Limit |
|---|---|
| Daily log (base + multipliers) | One award per calendar day (delta-upgraded if log improves) |
| Performance bonus | One tier (highest achieved) per calendar day |
| Quiz | 130 XP per quiz session; maximum 2 sessions per week |
| Challenge XP | No daily limit |
| Streak milestones | No daily limit |
| Leaderboard rewards | No daily limit |

### 3.6 Challenge XP Decay

Each repeat completion of the same challenge earns less XP, discouraging grinding.

```
Repeat XP = round( base_xp × max(0.50, 1.0 − 0.10 × (completion_number − 1)) )
```

| Completion # | Multiplier | Easy (100) | Medium (200) | Hard (400) |
|---|---|---|---|---|
| 1st | ×1.00 | 100 XP | 200 XP | 400 XP |
| 2nd | ×0.90 | 90 XP | 180 XP | 360 XP |
| 3rd | ×0.80 | 80 XP | 160 XP | 320 XP |
| 4th | ×0.70 | 70 XP | 140 XP | 280 XP |
| 5th | ×0.60 | 60 XP | 120 XP | 240 XP |
| 6th+ | ×0.50 (floor) | **50 XP** | **100 XP** | **200 XP** |

### 3.7 XP Anti-Abuse Rules

**No retroactive logs.** Logs are accepted only for the current calendar day (user's local timezone). A log submitted at 23:59 is valid; a log submitted at 00:01 belongs to the new day.

**Offline sync.** If an offline-queued log arrives with `original_timestamp` from a previous day:
- XP is awarded for the log date (using per-log-date cap tracking).
- Streak credit is NOT awarded. The streak engine checks `original_timestamp`, not arrival time.

**No multiple quiz attempts.** The server tracks `quiz_session_id`. A second submission to the same session returns 400 and no XP. Sessions expire after 48 hours; late submissions earn no XP.

**Leaderboard computed server-side.** `monthly_xp` is never trusted from the client. It is recomputed from `challenge_completions` and `daily_logs` tables on demand.

---

## 4. Level System

`level` is derived from `lifetime_xp` and recomputed on every XP update. It never resets.

| Level | Title | Total Lifetime XP | XP to Next | Unlocks |
|---|---|---|---|---|
| 1 | Eco Newcomer | 0 | 500 | Daily log, 1 challenge slot |
| 2 | Green Sprout | 500 | 1,000 | Log history, streak tracker |
| 3 | Eco Explorer | 1,500 | 1,500 | Insights screen, city leaderboard, monthly targets |
| 4 | Sustainability Seeker | 3,000 | 2,000 | 2 challenge slots, global leaderboard, Streak Freeze activates |
| 5 | Eco Advocate | 5,000 | 3,000 | Badge showcase, quiz perfect-score bonus (+50 XP), ×1.10 level multiplier |
| 6 | Climate Champion | 8,000 | 4,000 | 3 challenge slots, Hard challenges unlocked |
| 7 | Green Guardian | 12,000 | 5,000 | Custom profile themes |
| 8 | Eco Hero | 17,000 | 6,000 | Friends leaderboard, ×1.20 level multiplier |
| 9 | Carbon Crusader | 23,000 | 8,000 | 4 challenge slots, leaderboard crown flair |
| 10 | Carbon Neutral | 31,000 | — | Champion badge, permanent leaderboard star, ×1.75 streak multiplier tier active |

> **Note on "quiz bonus XP at Level 5":** the perfect-score +50 XP bonus is only awarded to Level 5+ users. All users receive 30 XP for attempting and +5 XP per correct answer regardless of level.

> **Note on Streak Freeze at Level 4:** if a user earns a Streak Freeze (via 30-day streak milestone) before reaching Level 4, the freeze is stored in `streak_freeze_queued = true`. It activates automatically when the user reaches Level 4.

---

## 5. Streak System

### 5.1 Two Streak Counters

| Counter | Field | What Increments It | What It Drives |
|---|---|---|---|
| General streak | `streak_days` | Any log submission (≥1 category) | Streak UI display; streak badges; APP_BEHAVIOR challenges |
| Full-log streak | `full_log_streak_days` | Full log only (all 3 categories + energy confirmed) | Streak XP multiplier |

Both counters reset to 0 on a missed day. Both are evaluated by the midnight audit job.

### 5.2 Streak Rules

- `streak_days` increments by 1 for each calendar day where any log exists (partial or full).
- `full_log_streak_days` increments by 1 for each calendar day where a full log exists.
- Both reset to 0 if no log entry exists before midnight (user's local timezone).
- A **Streak Freeze** prevents both counters from resetting for one missed day. It is consumed automatically. It does **not** award XP for the missed day and does **not** increment either counter.
- When a streak resets, both counters return to 0. Previous streak history is not carried forward.

### 5.3 Streak Milestones

Milestone bonuses use `streak_days` (not `full_log_streak_days`). Any log — even partial — counts toward milestones.

| `streak_days` | Bonus XP | Badge | Other Reward |
|---|---|---|---|
| 3 | +25 XP | — | Streak fire icon activates on dashboard |
| 7 | +75 XP | Week Warrior 🔥 | Push notification |
| 14 | +150 XP | Fortnight Fighter 💪 | Streak shown on leaderboard card |
| 30 | +300 XP | Monthly Maven 🌿 | Streak Freeze awarded (or queued if below Level 4) |
| 60 | +600 XP | Eco Consistent 🌍 | Gold streak border on profile |
| 100 | +1,000 XP | Century Eco 🏆 | Legendary badge; ×1.75 multiplier tier unlocks for full-log streak |

### 5.4 Streak Expiration Warnings

- **8:00 PM local time:** warning if `last_log_date < today`.
- **10:30 PM local time:** final warning if still no log. References current `streak_days`.
- No notifications after 10:30 PM.
- Tone: always encouraging. Example: *"Your 14-day streak is at risk! Log anything to keep it alive 🌿"*

---

## 6. Challenge System

### 6.1 Completion Strategy Types

Every challenge declares exactly one strategy. The engine evaluates it generically — no challenge has its own code path.

| Strategy | Evaluation Logic | Example |
|---|---|---|
| `LOG_FIELD_ZERO` | Day passes if `sum(log[field]) == 0` across all entries | No Car Day (`car_km`) |
| `TRANSPORT_ANY_MATCH` | Day passes if ANY transport leg has mode in `accepted_values` | Cycle to Work Week |
| `TRANSPORT_ALL_MATCH` | Day passes if ALL transport legs have mode in `accepted_values` | Public Transport Month |
| `FOOD_NONE_MATCH` | Day passes if NO food entry has category in `excluded_values` | Meat-Free Day |
| `FOOD_ALL_MATCH` | Day passes if ALL food entries have category in `accepted_values` | Plant-Based Week |
| `LOG_TAG_PRESENT` | Day passes if `tag` in `energy.deviations[]` AND `energy.confirmed = true` | Cold Shower Week |
| `LOG_TAG_ABSENT` | Day passes if `tag` NOT in `energy.deviations[]` AND `energy.confirmed = true` | No AC Week |
| `APP_BEHAVIOR` | Day passes if any log exists (partial or full) for that day | 100-Day Green Journey |

> **Why TRANSPORT_ANY_MATCH and FOOD_ALL_MATCH instead of LOG_FIELD_MATCH?** The v2 engine's `LOG_FIELD_MATCH` assumed a single scalar field. Transport and food are multi-entry arrays per day. "Cycle to Work" only needs one cycling leg; "Public Transport Month" requires all legs to be public transit; "Meat-Free Day" requires no meat in any meal. These are fundamentally different operations that cannot share one strategy type.

### 6.2 Consecutive vs. Non-Consecutive

Each challenge has a `consecutive` boolean.

- **`consecutive = true`:** qualifying days must be back-to-back. A failed day resets `days_passed = 0`. The window keeps running — users can restart within the same window.
- **`consecutive = false`:** qualifying days accumulate in any order. A failed day doesn't reset the count; it only shrinks the remaining window.

**All consecutive challenges have buffer days** (window > required_days) so that one missed day doesn't guarantee failure.

### 6.3 Missing Log Handling

The midnight audit job (00:01 local time) handles days with no log:

| Challenge type | No log submitted | Effect |
|---|---|---|
| Non-consecutive | Day not counted | `days_passed` unchanged; window shrinks by 1 |
| Consecutive | Treated as failure day | `days_passed` resets to 0 |
| `APP_BEHAVIOR` | Treated as failure day | `days_passed` resets to 0 |
| Any type | Deadline passed | If `days_passed < required_days` → mark `failed` |

> **Failed challenges are immediately retryable.** No cooldown on failure. Users should never be punished for attempting a challenge and coming up short.

### 6.4 Race Condition Prevention

Both `evaluateChallengesForUser()` (runs on log submission) and `midnightAudit()` (runs at 00:01) modify `user_challenges.days_passed`. To prevent concurrent writes corrupting the count, both functions must acquire a row-level lock:

```sql
SELECT * FROM user_challenges
WHERE user_id = $userId AND status = 'in_progress'
FOR UPDATE;
```

### 6.5 Cooldown Rules

Cooldowns apply only to successful completions. Failure has no cooldown.

**Base cooldown by difficulty:**

| Difficulty | Duration type | Base cooldown |
|---|---|---|
| Easy | Single day | 7 days |
| Easy | Multi-day | 14 days |
| Medium | Any | 30 days |
| Hard | Any | 90 days |

**Cooldown grows with each repeat:**

```
cooldown_days = min( base × 3,  base × (1.0 + 0.5 × (completion_number − 1)) )
```

| Completion # | Multiplier | Easy single-day | Medium | Hard |
|---|---|---|---|---|
| 1st | ×1.0 | 7 days | 30 days | 90 days |
| 2nd | ×1.5 | 10 days | 45 days | 135 days |
| 3rd | ×2.0 | 14 days | 60 days | 180 days |
| 4th+ | ×3.0 (cap) | 21 days | 90 days | 270 days |

### 6.6 Challenge Status (Two Operative States)

| Status | Meaning | UI |
|---|---|---|
| `in_progress` | Actively running | Progress bar, day counter, deadline |
| `completed` | Successfully finished | Cooldown timer if `cooldown_ends_at > today`; "Start Again" button otherwise |
| `failed` | Window expired without completion | "Try Again" button; available immediately |

Available = no `user_challenges` row exists OR `status = completed` AND `cooldown_ends_at <= today`.

### 6.7 Challenge Library (v1 — 15 Challenges)

> **Zero Food Waste Day removed from v1.** It required a `food_waste_logged` field that does not exist in the current DailyResult schema. Deferred to v1.2 along with a UI toggle and schema addition.

#### Transport 🚗

| Challenge | Difficulty | Strategy | Window | Required | Consecutive | XP | Strategy Params |
|---|---|---|---|---|---|---|---|
| No Car Day | Easy | `LOG_FIELD_ZERO` | 1 day | 1 | N/A | 100 | `{ field: "car_km" }` |
| No Car Weekend | Easy | `LOG_FIELD_ZERO` | 2 days | 2 | Yes | 100 | `{ field: "car_km", start_day: "saturday" }` |
| Walk 7 Days | Easy | `TRANSPORT_ANY_MATCH` | 10 days | 7 | No | 100 | `{ accepted_values: ["walking"] }` |
| Cycle to Work Week | Medium | `TRANSPORT_ANY_MATCH` | 7 days | 5 | No | 200 | `{ accepted_values: ["cycling"] }` |
| No Car Week | Medium | `LOG_FIELD_ZERO` | 10 days | 7 | Yes | 200 | `{ field: "car_km" }` |
| Carpool Champion | Medium | `TRANSPORT_ANY_MATCH` | 7 days | 5 | No | 200 | `{ accepted_values: ["rideshare"] }` |
| Public Transport Month | Hard | `TRANSPORT_ALL_MATCH` | 35 days | 30 | Yes | 400 | `{ accepted_values: ["bus","train","metro","tram","ferry"] }` |

> **No Car Weekend:** can only be started on a Saturday. The `start_day: "saturday"` param is enforced by the UI (the "Start Challenge" button is disabled on non-Saturday days).

> **No Car Week:** 10-day window gives 3 buffer days. The 7 qualifying days must be consecutive (any break resets count).

> **Public Transport Month:** 35-day window gives 5 buffer days. All 30 qualifying days must be consecutive.

#### Food 🥗

| Challenge | Difficulty | Strategy | Window | Required | Consecutive | XP | Strategy Params |
|---|---|---|---|---|---|---|---|
| Meat-Free Day | Easy | `FOOD_NONE_MATCH` | 1 day | 1 | N/A | 100 | `{ excluded_values: ["beef","pork","poultry","chicken","lamb","fish","seafood"] }` |
| Plant-Based Week | Medium | `FOOD_ALL_MATCH` | 9 days | 7 | Yes | 200 | `{ accepted_values: ["vegetables","legumes","tofu","soy","fruit","grains","nuts","seeds"] }` |
| Vegan Challenge | Hard | `FOOD_ALL_MATCH` | 35 days | 30 | Yes | 400 | `{ accepted_values: ["vegetables","legumes","tofu","soy","fruit","grains","nuts","seeds"] }` |

> **Plant-Based Week:** 9-day window gives 2 buffer days. Qualifying days must be consecutive.

> **Vegan Challenge:** 35-day window gives 5 buffer days. Uses the same params as Plant-Based Week.

> **Meat-Free Day renamed from Meatless Monday.** User picks any day; no day-of-week constraint. Avoids the day-awareness implementation problem and is fairer to users in different timezones or schedules.

#### Energy ⚡

| Challenge | Difficulty | Strategy | Window | Required | Consecutive | XP | Strategy Params |
|---|---|---|---|---|---|---|---|
| Unplug Day | Easy | `LOG_TAG_PRESENT` | 1 day | 1 | N/A | 100 | `{ tag: "unplugged_devices" }` |
| Cold Shower Week | Easy | `LOG_TAG_PRESENT` | 10 days | 7 | No | 100 | `{ tag: "cold_shower" }` |
| Screen Time Cutback | Easy | `LOG_TAG_PRESENT` | 10 days | 7 | No | 100 | `{ tag: "low_screen_time" }` |
| No AC Week | Medium | `LOG_TAG_ABSENT` | 7 days | 7 | Yes | 200 | `{ tag: "ac_used" }` |

> **No AC Week** retains a 7-day window with 7 required consecutive days (zero tolerance). This is appropriate here because the strategy is tag-absent — a user who runs AC once a day simply won't log that tag. The barrier is behavioural, not administrative.

#### Nature 🌳

| Challenge | Difficulty | Strategy | Window | Required | Consecutive | XP | Strategy Params |
|---|---|---|---|---|---|---|---|
| 100-Day Green Journey | Hard | `APP_BEHAVIOR` | 100 days | 100 | Yes | 400 | `{ metric: "consecutive_active_days" }` |

---

## 7. Badge System

### 7.1 Category Badges

| Category | Badge Name | Bronze | Silver | Gold |
|---|---|---|---|---|
| 🚗 Transport | Road to Green | 3 completions | 7 completions | 12 completions |
| 🥗 Food | Conscious Plate | 3 completions | 7 completions | 12 completions |
| ⚡ Energy | Power Saver | 3 completions | 7 completions | 12 completions |
| 🌳 Nature | Nature Keeper | **1 completion** | **2 completions** | **3 completions** |

> **Nature badge uses adjusted thresholds (1/2/3 instead of 3/7/12).** There is currently only one Nature challenge (100-Day Green Journey, Hard). At 90-day base cooldown growing to 270 days, reaching 7 completions would take 5–7 years. Adjusted thresholds are achievable within a realistic app lifetime and will be raised when v1.2 adds more Nature challenges.

### 7.2 Special Badges

| Badge | Trigger | Description |
|---|---|---|
| Eco Newcomer ✨ | First log submitted | Welcome badge; one-time only |
| Week Warrior 🔥 | `streak_days` = 7 | One week of logging |
| Fortnight Fighter 💪 | `streak_days` = 14 | Two weeks of logging |
| Monthly Maven 🌿 | `streak_days` = 30 | One month of logging |
| Eco Consistent 🌍 | `streak_days` = 60 | Two months of logging |
| Century Eco 🏆 | `streak_days` = 100 | Legendary dedication |
| Quiz Whiz 🧠 | 5 perfect quiz scores (10/10) | Knowledge champion |
| Streak Saver 🛡️ | First Streak Freeze consumed | One-time |
| All-Rounder 🌐 | ≥1 challenge completed in each **currently active** category | Breadth achiever |
| Carbon Neutral 🌍 | Reach Level 10 | Ultimate achievement |
| Leaderboard Leader 👑 | Rank #1 on monthly global leaderboard | Season champion |

> **All-Rounder versioning:** the badge is evaluated against the categories active at the time it is earned. A user who earns All-Rounder in v1 (4 categories) keeps it when Lifestyle is added in v1.2. New earners from v1.2 onward must complete a challenge in all 5 categories.

### 7.3 Badge Evaluation — Event-Driven Triggers

No badge is evaluated on a schedule. Every evaluation is triggered by a specific event.

| Badge | Trigger Event | Evaluation |
|---|---|---|
| Eco Newcomer | Log submitted | If `COUNT(daily_logs WHERE user_id) == 1` → award |
| Streak badges | Log submitted → streaks updated | If `streak_days` == milestone AND badge not held → award |
| Category badges | Challenge marked `completed` | `COUNT(challenge_completions WHERE user_id AND category = X)` vs thresholds |
| Quiz Whiz | Quiz submitted with `score == 10` | `COUNT(quiz_sessions WHERE user_id AND score == 10)` ≥ 5 → award |
| Streak Saver | Streak Freeze consumed | One-time; if not already held → award |
| All-Rounder | Challenge marked `completed` | `COUNT(DISTINCT category WHERE user_id)` covers all active categories → award |
| Carbon Neutral | XP updated → level recomputed | If `level == 10` → award |
| Leaderboard Leader | Monthly leaderboard job (1st of month) | If `rank == 1` for prior month → award |

**All badge awards are idempotent.** The award function checks `user_badges` before inserting. Duplicate is impossible by design. Every award triggers a full-screen celebration animation and an immediate push notification.

---

## 8. Leaderboard System

### 8.1 Leaderboard Tiers

| Tier | Scope | Ranked By | Reset | Unlock |
|---|---|---|---|---|
| Global 🌍 | All users | `monthly_xp` | 1st of each month | All users |
| City 🏙️ | Same city (profile field) | `monthly_xp` | 1st of each month | Level 3+ |
| Friends 👥 | Mutual follows | `monthly_xp` | 1st of each month | Level 8+ |
| Weekly Sprint ⚡ | All users | `monthly_xp` accumulated Mon–Sun | Monday reset | All users |

> The leaderboard always ranks by `monthly_xp`, not `lifetime_xp`. This ensures new users are competitive each month.

### 8.2 Monthly End-of-Season Rewards

Awarded at the start of the 1st of each month. XP is added to both `lifetime_xp` and the **new** month's `monthly_xp`.

| Rank | Bonus XP | Reward |
|---|---|---|
| #1 🥇 | +500 XP | Leaderboard Leader badge + champion crown on profile for following month |
| #2 🥈 | +300 XP | Silver season badge |
| #3 🥉 | +200 XP | Bronze season badge |
| Top 10 | +100 XP | Top 10 profile flair |
| Top 25% | +50 XP | Motivational push notification |

### 8.3 Overtake Notifications

- Triggered when any user surpasses the current user's rank.
- Leaderboard is recomputed **every hour** by a scheduled job. Rank changes are detected on each run and overtake notifications are dispatched at that point.
- **Promise: delivered within 1 hour of rank change** (not 15 minutes — the hourly job makes that impossible).
- Frequency cap: max 3 overtake notifications per day per user.
- User-configurable off in Settings.

---

## 9. Flashcard Quiz System

### 9.1 Mechanics

| Property | Value |
|---|---|
| Frequency | Twice per week — Tuesday and Friday |
| Delivery | Push notification at 9:00 AM local time |
| Availability window | 48 hours from delivery |
| Format | 10 multiple-choice questions, 4 options each |
| Time limit | None |
| Attempts per session | 1; no retries |
| Base XP (all users) | 30 XP on submission |
| Per correct answer | +5 XP (max +50 XP) |
| Perfect score bonus | +50 XP — Level 5+ users only |
| Max XP per session | 80 XP (Levels 1–4) / 130 XP (Level 5+) |
| Topics | Rotating: Transport, Food, Energy, Nature, Climate Science |

### 9.2 Question Bank — Transport 🚗 (10 Questions)

**Q1:** Which vehicle type produces the least CO₂ per kilometre?
- A. Petrol car
- B. Diesel car
- **C. Electric vehicle ✅**
- D. Motorcycle

**Q2:** Approximately how many kg of CO₂ does a long-haul flight emit per passenger per hour?
- A. 5 kg
- **B. 90 kg ✅**
- C. 250 kg
- D. 1,000 kg

**Q3:** What is carpooling most effective at reducing?
- A. Fuel cost only
- **B. Per-person carbon emissions ✅**
- C. Road wear and tear
- D. Journey time

**Q4:** Which has the lowest carbon footprint per passenger-kilometre?
- A. Domestic flight
- B. Electric car (average grid)
- **C. Full inter-city train ✅**
- D. Empty bus

**Q5:** What percentage of global CO₂ emissions does the transport sector account for?
- A. 7%
- B. 16%
- **C. 24% ✅**
- D. 38%

**Q6:** A hybrid car's fuel efficiency is greatest during which type of driving?
- A. Motorway cruising at high speed
- **B. Stop-start urban driving ✅**
- C. Long uphill climbs
- D. Cold weather driving

**Q7:** A petrol car emits 180g CO₂ per km. How much CO₂ is produced on a 50 km journey?
- A. 5 kg
- **B. 9 kg ✅**
- C. 18 kg
- D. 25 kg

**Q8:** Which transport fuel is produced from biological material such as crops or waste?
- A. Hydrogen
- **B. Biofuel ✅**
- C. LPG
- D. Synthetic diesel

**Q9:** What is 'range anxiety' in the context of electric vehicles?
- A. Fear of driving in heavy rain
- **B. Concern about running out of battery before reaching a charger ✅**
- C. Anxiety about purchase price
- D. Worry about battery fires

**Q10:** Cycling instead of driving 5 km per day for a year saves approximately how much CO₂?
- A. 50 kg
- B. 200 kg
- **C. 330 kg ✅**
- D. 600 kg

---

### 9.3 Question Bank — Food 🥗 (10 Questions)

**Q11:** Which food has the highest carbon footprint per 100g produced?
- A. Lentils
- B. Chicken
- **C. Beef ✅**
- D. Tofu

**Q12:** What does 'food miles' refer to?
- A. Calories burned during cooking
- **B. Distance food travels from farm to plate ✅**
- C. Amount of food wasted annually
- D. Nutritional value per serving

**Q13:** Eating seasonally helps reduce emissions because:
- A. Seasonal food is always organic
- **B. Local seasonal food needs less transport and refrigeration ✅**
- C. Seasonal food has fewer pesticides
- D. It is lower in calories

**Q14:** Which dietary shift would reduce a person's food carbon footprint the most?
- A. Switching from tap to bottled water
- **B. Eliminating beef and lamb ✅**
- C. Buying only branded products
- D. Switching from glass to plastic packaging

**Q15:** What fraction of global greenhouse gas emissions comes from food production?
- A. 5%
- B. 10%
- **C. 25% ✅**
- D. 50%

**Q16:** Which of the following produces the most methane?
- A. Crop irrigation
- **B. Livestock digestion (enteric fermentation) ✅**
- C. Refrigerated transport
- D. Plastic packaging production

**Q17:** What does 'plant-based diet' mean?
- A. Only eating raw food
- **B. A diet centred on plants, minimising animal products ✅**
- C. Only eating food grown without pesticides
- D. A purely vegan diet with no exceptions

**Q18:** How does food waste contribute to climate change?
- A. It produces noise pollution
- **B. Decomposing food in landfill releases methane ✅**
- C. It uses up oxygen in soil
- D. It has no climate impact

**Q19:** Which farming practice helps soil absorb more carbon?
- A. Deep ploughing every season
- B. Monoculture farming
- **C. Cover cropping and reduced tillage ✅**
- D. More synthetic nitrogen fertiliser

**Q20:** On average, how much CO₂-equivalent does 1 kg of beef produce?
- A. 3 kg
- B. 10 kg
- C. 27 kg
- **D. 60 kg ✅**

---

### 9.4 Question Bank — Energy ⚡ (10 Questions)

**Q21:** Which household appliance typically consumes the most electricity per year?
- A. LED bulb
- B. Laptop
- **C. Refrigerator ✅**
- D. Phone charger

**Q22:** What does 'phantom load' refer to?
- A. Energy lost in power line transmission
- **B. Electricity used by devices on standby ✅**
- C. Peak demand during grid surges
- D. Energy produced by solar at night

**Q23:** Lowering your thermostat by 1°C reduces heating bills by approximately:
- A. 0.5%
- **B. 10% ✅**
- C. 30%
- D. 50%

**Q24:** Which of the following is a renewable energy source?
- A. Natural gas
- B. Coal
- **C. Onshore wind ✅**
- D. Nuclear fission

**Q25:** What is the 'carbon intensity' of an electricity grid?
- A. Weight of power cables per km
- **B. CO₂ emitted per unit of electricity generated (kg CO₂/kWh) ✅**
- C. Cost of electricity per unit
- D. Efficiency of solar panels

**Q26:** Which action saves the most energy in a typical home?
- A. Switching off lights when leaving
- **B. Upgrading to a more efficient boiler or heat pump ✅**
- C. Unplugging phone chargers
- D. Using a microwave instead of an oven

**Q27:** What does a solar panel's 'peak watt' rating measure?
- **A. Power output in full direct sunlight ✅**
- B. Total lifetime energy output
- C. Power stored in the battery
- D. Efficiency in cloudy weather

**Q28:** Heat pumps are more efficient than gas boilers because they:
- A. Burn fuel more cleanly
- B. Generate heat at higher combustion temperatures
- **C. Transfer heat from outside air or ground rather than burning fuel ✅**
- D. Produce no noise

**Q29:** Which best describes 'net zero' energy in a building?
- A. The building uses no energy at all
- **B. Energy consumed equals energy generated on-site over a year ✅**
- C. The building only uses energy at night
- D. The building has no heating system

**Q30:** What percentage of a typical home's energy use goes to space heating?
- A. 10%
- B. 30%
- **C. 50% ✅**
- D. 70%

---

### 9.5 Question Bank — Climate Science 🌡️ (10 Questions)

**Q31:** The main greenhouse gas produced by human activity is:
- A. Oxygen
- B. Nitrogen
- **C. CO₂ ✅**
- D. Argon

**Q32:** What is the 'greenhouse effect'?
- A. Crops growing faster in warmer climates
- **B. The trapping of heat by atmospheric gases, warming the Earth's surface ✅**
- C. The melting of polar ice caps
- D. Growing food in heated glass structures

**Q33:** Pre-industrial atmospheric CO₂ levels were approximately:
- A. 180 ppm
- **B. 280 ppm ✅**
- C. 420 ppm
- D. 550 ppm

**Q34:** What does the Paris Agreement aim to limit global warming to?
- A. 0.5°C above pre-industrial levels
- **B. 1.5–2°C above pre-industrial levels ✅**
- C. 3°C above pre-industrial levels
- D. Any amount as long as emissions are reduced

**Q35:** Which gas has a global warming potential approximately 28× higher than CO₂ over 100 years?
- A. Oxygen
- B. Nitrogen
- **C. Methane ✅**
- D. Argon

**Q36:** Ocean acidification is caused by:
- A. Ship pollution
- **B. The ocean absorbing excess CO₂ from the atmosphere ✅**
- C. Overfishing
- D. Volcanic eruptions on the ocean floor

**Q37:** What does 'carbon sequestration' mean?
- A. Burning carbon fuels more efficiently
- **B. Capturing and storing CO₂ from the atmosphere ✅**
- C. Measuring the carbon content of soil
- D. Calculating a country's total emissions

**Q38:** Which decade was the hottest on record as of 2024?
- A. 1990s
- B. 2000s
- C. 2010s
- **D. 2020s ✅**

**Q39:** What is an 'emissions offset'?
- A. A fine for exceeding emission limits
- **B. A reduction in emissions elsewhere to compensate for your own ✅**
- C. A government subsidy for clean energy
- D. A type of renewable fuel

**Q40:** Approximately how many trees offset one tonne of CO₂ over 40 years?
- A. 1
- B. 6
- **C. 50 ✅**
- D. 200

---

### 9.6 Question Bank — Nature & Sustainability 🌿 (10 Questions)

**Q41:** What percentage of the world's biodiversity is found in tropical rainforests?
- A. 10%
- B. 25%
- **C. 50% ✅**
- D. 80%

**Q42:** What is 'fast fashion' primarily criticised for environmentally?
- A. Using only synthetic dyes
- **B. High volume production leading to massive textile waste and carbon emissions ✅**
- C. Making clothing too expensive
- D. Clothes that wear out too quickly

**Q43:** Plastic takes approximately how long to decompose in landfill?
- A. 10–20 years
- B. 50–100 years
- **C. 200–500 years ✅**
- D. Thousands of years

**Q44:** What is the circular economy?
- A. An economy focused on circular trade routes
- **B. A system designed to eliminate waste by keeping materials in use as long as possible ✅**
- C. A stock market cycle theory
- D. A farming technique that rotates crops in a circle

**Q45:** The most effective way to reduce your personal water footprint is:
- A. Taking shorter showers
- B. Drinking only bottled water
- **C. Reducing consumption of meat and dairy ✅**
- D. Installing a water butt

**Q46:** What does 'biodegradable' mean?
- A. Can be recycled into new products
- **B. Breaks down naturally by microorganisms without leaving toxic residue ✅**
- C. Made from plant-based materials
- D. Produces no greenhouse gases during production

**Q47:** Which human activity is the leading driver of deforestation globally?
- A. Urban expansion
- B. Mining and oil extraction
- **C. Agricultural land clearance for livestock and crops ✅**
- D. Paper production

**Q48:** What is 'greenwashing'?
- A. Painting buildings green to reflect sunlight
- **B. Marketing that exaggerates or falsely claims a product's environmental benefits ✅**
- C. Washing clothing at low temperatures
- D. A government policy to tax high-emission products

**Q49:** Composting organic waste helps the environment primarily by:
- A. Creating plastic alternatives
- **B. Returning nutrients to soil and reducing methane from landfill ✅**
- C. Producing clean energy
- D. Purifying water sources

**Q50:** Which best describes 'sustainable development'?
- A. Development using as many resources as possible now
- **B. Development that meets today's needs without compromising future generations' ability to meet theirs ✅**
- C. Development exclusively in rural areas
- D. Development funded by environmental charities

---

## 10. Push Notification System

### 10.1 Notification Schedule

| Type | Trigger | Timing | Message Template |
|---|---|---|---|
| Daily Log Reminder | No log by 8 PM | 8:00 PM local | 🌿 *How was your day? Log your activity and keep your streak alive!* |
| Final Log Warning | No log by 10:30 PM | 10:30 PM local | ⚠️ *Last chance to log today! Don't break your [N]-day streak 🔥* |
| Streak Milestone | `streak_days` hits milestone | Immediate | 🔥 *[N] days in a row! You're a true eco-warrior. +[XP] XP awarded!* |
| Challenge Reminder | Challenge in progress; user has NOT logged today | 12:00 PM daily | 📋 *Day [X]/[total] of '[Challenge]'. Keep going — you've got this!* |
| Challenge Complete | Engine marks challenge completed | Immediate | 🎉 *'[Challenge]' complete! +[XP] XP earned. Badge progress updated!* |
| Challenge Failed | Midnight audit marks challenge failed | 00:01 local | 💪 *Don't worry — '[Challenge]' can be restarted immediately. Give it another go!* |
| Leaderboard Overtaken | Hourly leaderboard job detects rank change | Within 1 hour | 🌿 *[Name] just overtook you! You're now #[rank]. Log today to climb back.* |
| New Quiz Available | Bi-weekly (Tue & Fri) | 9:00 AM local | 🧠 *New quiz live for 48 hrs! Earn up to [80/130] XP — optional but fun!* |
| Badge Earned | Badge trigger met | Immediate | 🏅 *New badge: '[Name]'! Check your profile to see it.* |
| Level Up | `level` increases | Immediate | ⬆️ *Level up! You're now a [Title]. New features unlocked 🌍* |
| Weekly Summary | Every Sunday | 6:00 PM local | 📊 *Week in review: [X] kg CO₂ saved · [N]-day streak · [XP] earned.* |
| Monthly Leaderboard | 1st of each month | 9:00 AM local | 🏆 *New season! Last month you ranked #[rank]. Can you go higher?* |
| Top 25% Recognition | 1st of each month | 9:00 AM local | 🌟 *You finished top 25% last month! +50 XP awarded.* |

> **Challenge Reminder suppression:** the reminder at 12:00 PM only fires if `last_log_date < today`. If the user has already logged today, the reminder is suppressed. The challenge engine already ran on submission and updated progress.

### 10.2 Notification Preferences

| Type | Default | User Can Disable? |
|---|---|---|
| Daily log reminder | ON | Yes |
| Streak warnings | ON | Yes |
| Challenge reminders | ON | Yes |
| Challenge failed | ON | Yes |
| Leaderboard overtake | ON | Yes (cap of 3/day enforced regardless) |
| Quiz notifications | ON | Yes |
| Weekly summary | ON | Yes |
| Monthly leaderboard | ON | Yes |
| Badge & level-up | ON | **No** — celebratory, non-disruptive |

All times respect the user's local timezone. Users may set quiet hours; non-urgent notifications are held until the quiet window ends.

---

## 11. Daily Engagement Loop

| Step | Action | System Outcome |
|---|---|---|
| 1 | Open app | Dashboard: CO₂ ring, `streak_days` counter, active challenge progress |
| 2 | Log daily activity | `awardDailyXP()` runs immediately; challenge engine evaluates all active challenges; streak counters update |
| 3 | View impact | Dashboard shows CO₂ vs baseline, equivalences, XP earned today |
| 4 | Check Gamification tab | Level bar, challenge day counts, badge grid, leaderboard rank |
| 5 | Attempt quiz (Tue/Fri) | Optional; 48-hour window; up to 80/130 XP depending on level |
| 6 | Complete a challenge | 100–400 XP (decayed); badge progress +1; celebration animation; cooldown begins |
| 7 | Earn badge or level up | Full-screen animation; push notification; profile updated |
| 8 | Return tomorrow | Streak warning at 8 PM if no log; loop restarts |

---

## 12. Engine Specification

### 12.1 `awardDailyXP(userId, dailyResult, logDate, streakState, level)`

```
INPUT:
  userId       — user identifier
  dailyResult  — output of processDailyLog() from algorithm spec
  logDate      — the date this log is for (NOT today's date if offline sync)
  streakState  — { streak_days, full_log_streak_days }
  level        — current level (from lifetime_xp)

STEP 1 — Determine base XP
  isFullLog = (dailyResult.transportCO2 > 0 OR transport logged)
              AND (dailyResult.foodCO2 > 0)
              AND (dailyResult.energy.confirmed == true)
  baseXP = isFullLog ? 50 : 20

STEP 2 — Determine streak multiplier (uses full_log_streak_days)
  If today is NOT a full log → streakMult = 1.00 (no multiplier on partial logs)
  Else:
    fls = full_log_streak_days
    streakMult = fls >= 100 ? 1.75
               : fls >= 30  ? 1.50
               : fls >= 7   ? 1.25
               : 1.00

STEP 3 — Determine level multiplier
  levelMult = level >= 9 ? 1.20
            : level >= 5 ? 1.10
            : 1.00

STEP 4 — Compute pre-bonus XP
  preBonus = round(baseXP × streakMult × levelMult)

STEP 5 — Performance bonus (full log only)
  If NOT isFullLog → perfBonus = 0
  Else:
    pct = dailyResult.percentVsBaseline  // negative means below baseline
    perfBonus = pct <= -30 ? 25
              : pct <= -15 ? 15
              : pct <= -5  ? 8
              : 0

STEP 6 — Compute delta (idempotent upgrade)
  alreadyAwarded = SELECT daily_xp_from_log WHERE user_id = userId AND last_daily_xp_date = logDate
  If alreadyAwarded is null: alreadyAwarded = 0
  newTotal = preBonus + perfBonus
  deltaXP = max(0, newTotal - alreadyAwarded)

STEP 7 — Apply
  UPDATE users SET
    lifetime_xp      = lifetime_xp + deltaXP,
    monthly_xp       = monthly_xp + deltaXP,
    daily_xp_from_log = newTotal,
    last_daily_xp_date = logDate
  Recompute level from lifetime_xp thresholds
  If level increased → triggerLevelUp(userId, newLevel)
```

### 12.2 `evaluateChallengesForUser(userId, logDate, dailyResult)`

```
Acquire row-level lock on all in_progress user_challenges for userId

For each active challenge (uc):

  1. If logDate > uc.deadline_at → markFailed(uc); continue

  2. passed = evaluateStrategy(challenge.strategy, challenge.strategy_params, dailyResult)

  3. If passed:
       uc.days_passed += 1
       If uc.days_passed >= challenge.required_days → markComplete(userId, uc, challenge)

  4. If NOT passed AND challenge.consecutive:
       uc.days_passed = 0   // reset streak within window

  5. If NOT passed AND NOT challenge.consecutive:
       // no change to days_passed; window shrinks by one day
```

### 12.3 `evaluateStrategy(strategy, params, dailyResult)`

```
LOG_FIELD_ZERO:
  total = sum of log[params.field] across all transport legs
  return total == 0

TRANSPORT_ANY_MATCH:
  return ANY transport leg where leg.mode in params.accepted_values

TRANSPORT_ALL_MATCH:
  If no transport entries → return false  // must have logged transport
  return ALL transport legs have leg.mode in params.accepted_values

FOOD_NONE_MATCH:
  If no food entries → return false  // must have logged food
  return NO food entry has entry.category in params.excluded_values

FOOD_ALL_MATCH:
  If no food entries → return false
  return ALL food entries have entry.category in params.accepted_values

LOG_TAG_PRESENT:
  return dailyResult.energy.confirmed == true
    AND params.tag in dailyResult.energy.deviations

LOG_TAG_ABSENT:
  return dailyResult.energy.confirmed == true
    AND params.tag NOT in dailyResult.energy.deviations

APP_BEHAVIOR:
  return true  // any log submission passes; engine only called when a log exists
```

### 12.4 `midnightAudit(userId, auditDate)`

```
Acquire row-level lock on all in_progress user_challenges for userId

logExists = SELECT EXISTS(daily_logs WHERE user_id = userId AND date = auditDate)

If NOT logExists:
  -- Update streak counters
  UPDATE users SET streak_days = 0, full_log_streak_days = 0
    WHERE streak_freeze_held = false
  If streak_freeze_held:
    SET streak_freeze_held = false  // consume freeze
    // streak counters NOT reset
    triggerBadge('streak_saver', userId)

  -- Update challenges
  For each in_progress challenge (uc):
    If challenge.consecutive OR challenge.strategy == 'APP_BEHAVIOR':
      uc.days_passed = 0

For each in_progress challenge (uc):
  If auditDate >= uc.deadline_at AND uc.days_passed < challenge.required_days:
    markFailed(uc)
```

### 12.5 `markComplete(userId, uc, challenge)`

```
1. Count previous completions
   completionNum = COUNT(challenge_completions WHERE user_id = userId AND challenge_id = challenge.id) + 1

2. Calculate XP with decay
   xpMult = max(0.50, 1.0 - 0.10 × (completionNum - 1))
   xpAwarded = round(challenge.xp_reward × xpMult)

3. Calculate cooldown
   baseCooldown = BASE_COOLDOWN[challenge.difficulty][challenge.duration_type]
   cooldownMult = min(3.0, 1.0 + 0.5 × (completionNum - 1))
   cooldownDays = round(baseCooldown × cooldownMult)
   cooldownEndsAt = today + cooldownDays

4. Persist
   INSERT INTO challenge_completions (user_id, challenge_id, completed_at, xp_awarded, completion_num)
   UPDATE user_challenges SET status = 'completed', completed_at = today, cooldown_ends_at = cooldownEndsAt

5. Award XP (bypasses daily cap)
   UPDATE users SET lifetime_xp += xpAwarded, monthly_xp += xpAwarded
   Recompute level

6. Trigger downstream
   evaluateBadges(userId, challenge.category)
   triggerPushNotification('challenge_complete', userId, { challenge, xpAwarded })
```

### 12.6 `awardBadgeIfEligible(userId, badgeId, conditionFn)`

```
If EXISTS(user_badges WHERE user_id = userId AND badge_id = badgeId):
  return  // idempotent — no duplicate

If conditionFn(userId) == true:
  INSERT INTO user_badges (user_id, badge_id, earned_at = NOW())
  triggerPushNotification('badge_earned', userId, { badgeId })
  triggerCelebrationAnimation(userId, badgeId)
```

---

## 13. Test Cases

Test cases are grouped by subsystem. Each test specifies preconditions, the action, and the expected outcome across all affected fields.

---

### 13.1 XP — Daily Logging

#### TC-XP-001: Full log, new user, no streak
```
Preconditions:
  level = 1, streak_days = 0, full_log_streak_days = 0
  last_daily_xp_date = null, daily_xp_from_log = 0
  CO2 today: exactly at baseline (0% difference)

Action: Submit full log (all 3 categories, energy confirmed)

Expected:
  baseXP = 50
  streakMult = 1.00 (full_log_streak_days = 0, below 7)
  levelMult = 1.00 (level 1)
  perfBonus = 0 (0% vs baseline)
  preBonus = round(50 × 1.00 × 1.00) = 50
  deltaXP = 50 - 0 = 50
  lifetime_xp += 50
  monthly_xp += 50
  streak_days = 1
  full_log_streak_days = 1
  daily_xp_from_log = 50
```

#### TC-XP-002: Full log, 7-day streak, Level 1, 20% below baseline
```
Preconditions:
  level = 1, streak_days = 7, full_log_streak_days = 7
  CO2 today: 20% below baseline
  daily_xp_from_log for today = 0

Action: Submit full log

Expected:
  baseXP = 50
  streakMult = 1.25 (full_log_streak_days = 7)
  levelMult = 1.00
  perfBonus = 15 (≥15% below baseline)
  preBonus = round(50 × 1.25 × 1.00) = 63
  finalXP = 63 + 15 = 78
  lifetime_xp += 78
  streak_days = 8
  full_log_streak_days = 8
```

#### TC-XP-003: Partial log then upgrade to full same day
```
Preconditions:
  level = 5, streak_days = 30, full_log_streak_days = 30
  CO2 today: 35% below baseline

Action 1 (10 AM): Submit partial log (transport + food only, energy not confirmed)

Expected after Action 1:
  baseXP = 20, streakMult = 1.00 (partial → no multiplier), levelMult = 1.10
  preBonus = round(20 × 1.00 × 1.10) = 22
  perfBonus = 0 (partial log, no perf bonus)
  deltaXP = 22
  daily_xp_from_log = 22, lifetime_xp += 22
  streak_days = 31, full_log_streak_days unchanged (still 30, no full log yet)

Action 2 (7 PM): User adds energy, confirms. Log is now full.

Expected after Action 2:
  baseXP = 50, streakMult = 1.50 (full_log_streak_days = 30), levelMult = 1.10
  perfBonus = 25 (≥30% below baseline)
  preBonus = round(50 × 1.50 × 1.10) = 83
  newTotal = 83 + 25 = 108
  deltaXP = 108 - 22 = 86
  daily_xp_from_log = 108
  lifetime_xp += 86 (total day: 22 + 86 = 108)
  full_log_streak_days = 31
```

#### TC-XP-004: Log submitted twice on same day — no double award
```
Preconditions:
  daily_xp_from_log for today = 50 (full log already submitted and XP awarded)

Action: User submits same full log again (e.g. app bug / retry)

Expected:
  newTotal = 50 (same as already awarded)
  deltaXP = max(0, 50 - 50) = 0
  No XP change. No duplicate streak increment.
```

#### TC-XP-005: Partial log — no performance bonus even if below baseline
```
Preconditions:
  level = 3, streak_days = 10, full_log_streak_days = 0
  CO2: 40% below baseline (only transport logged)

Action: Submit partial log (transport only)

Expected:
  isFullLog = false
  baseXP = 20
  streakMult = 1.00 (partial log → multiplier not applied)
  perfBonus = 0 (partial log → no performance bonus)
  preBonus = round(20 × 1.00 × 1.00) = 20
  finalXP = 20
  full_log_streak_days unchanged
```

#### TC-XP-006: Level 5 — level multiplier kicks in
```
Preconditions:
  lifetime_xp = 5000 (exactly Level 5), level = 5
  full_log_streak_days = 7

Action: Submit full log, CO2 at baseline

Expected:
  streakMult = 1.25
  levelMult = 1.10
  preBonus = round(50 × 1.25 × 1.10) = round(68.75) = 69
  perfBonus = 0
  finalXP = 69
```

---

### 13.2 XP — Quiz

#### TC-QZ-001: Level 4 user, 8/10 score
```
Preconditions: level = 4 (below 5), quiz_session_id = "abc", session not previously submitted

Action: Submit quiz with 8 correct answers

Expected:
  attempt XP = 30
  correct XP = 8 × 5 = 40
  perfect bonus = 0 (not 10/10 AND below Level 5)
  total quiz XP = 70
  lifetime_xp += 70, monthly_xp += 70
  daily_xp_from_quiz = 70
```

#### TC-QZ-002: Level 5 user, perfect score
```
Preconditions: level = 5, quiz_session_id = "xyz"

Action: Submit quiz with 10/10 correct

Expected:
  attempt XP = 30
  correct XP = 10 × 5 = 50
  perfect bonus = 50 (Level 5+)
  total = 130
  lifetime_xp += 130
```

#### TC-QZ-003: Attempt to submit same quiz session twice
```
Preconditions: quiz_session_id "abc" already submitted

Action: Second submission to session "abc"

Expected:
  Response: 400 Bad Request
  No XP awarded
  No change to any user field
```

#### TC-QZ-004: Submit quiz after 48-hour window
```
Preconditions: quiz delivered Tuesday 9 AM; submission attempted Thursday 10 AM (49 hours later)

Action: Submit quiz

Expected:
  Response: 400 — session expired
  No XP awarded
```

---

### 13.3 Streaks

#### TC-ST-001: Full log on day 6 — streak increments to 7, milestone fires
```
Preconditions: streak_days = 6, full_log_streak_days = 6

Action: Submit full log

Expected:
  streak_days = 7, full_log_streak_days = 7
  Streak milestone: +75 XP awarded (outside daily cap)
  Badge: Week Warrior 🔥 awarded (if not already held)
  Push notification: streak milestone
```

#### TC-ST-002: Partial log on day 7 — streak maintained, full-log streak does not advance
```
Preconditions: streak_days = 7, full_log_streak_days = 7

Action: Submit partial log (transport only)

Expected:
  streak_days = 8
  full_log_streak_days = 7 (no change — partial log)
  XP multiplier: 1.00 (full_log_streak_days is 7 but today's log is partial)
  No streak milestone (streak_days milestone at 14 not yet reached)
```

#### TC-ST-003: Missed day — both streaks reset
```
Preconditions: streak_days = 14, full_log_streak_days = 10, streak_freeze_held = false

Action: midnight audit runs; no log for today

Expected:
  streak_days = 0
  full_log_streak_days = 0
  last_log_date unchanged
  Push notification: challenge failure if any consecutive challenge was in progress
```

#### TC-ST-004: Streak Freeze consumes on missed day
```
Preconditions: streak_days = 30, full_log_streak_days = 25, streak_freeze_held = true

Action: midnight audit; no log today

Expected:
  streak_days = 30 (unchanged — freeze protected it)
  full_log_streak_days = 25 (unchanged)
  streak_freeze_held = false (consumed)
  Streak Saver badge awarded (if first freeze use)
  No XP for today (freeze doesn't award XP)
  All consecutive challenges: days_passed NOT reset (streak freeze protects challenges too)
```

#### TC-ST-005: Streak Freeze queued at sub-Level-4 user
```
Preconditions: level = 2, streak_days = 30, streak_freeze_held = false, streak_freeze_queued = false

Action: midnight audit after 30-day streak milestone

Expected:
  Streak milestone: +300 XP, Monthly Maven badge
  streak_freeze_queued = true (not streak_freeze_held — user is Level 2)
  Notification: "You earned a Streak Freeze! It will activate when you reach Level 4."

Later — user reaches Level 4:
  streak_freeze_queued = false
  streak_freeze_held = true
  Notification: "Your Streak Freeze is now active! 🛡️"
```

---

### 13.4 Challenges — Engine

#### TC-CH-001: LOG_FIELD_ZERO — No Car Day, car used
```
Challenge: No Car Day (LOG_FIELD_ZERO, field: car_km)
Preconditions: challenge in_progress, started today

Action: User logs transport with mode: 'car', distance: 15 km

Expected:
  evaluateStrategy → sum(car_km) = 15 → return false
  days_passed: 0 → 0 (single day challenge, not consecutive)
  deadline_at = today → markFailed()
  Status: failed
  No XP awarded
  Challenge immediately available to restart
```

#### TC-CH-002: LOG_FIELD_ZERO — No Car Day, no car used
```
Challenge: No Car Day (LOG_FIELD_ZERO, field: car_km)

Action: User logs transport with mode: 'walking', distance: 3 km (car_km = 0)

Expected:
  evaluateStrategy → sum(car_km) = 0 → return true
  days_passed: 0 → 1
  1 >= required_days (1) → markComplete()
  XP: 100 (1st completion)
  Cooldown: 7 days
  Badge evaluation: Transport category count checked
```

#### TC-CH-003: TRANSPORT_ALL_MATCH — Public Transport Month, mixed mode day
```
Challenge: Public Transport Month (TRANSPORT_ALL_MATCH)
Preconditions: days_passed = 15, consecutive = true

Action: User logs bus leg (5 km) + taxi leg (3 km). Taxi is not in accepted_values.

Expected:
  evaluateStrategy → ALL legs must be in ['bus','train','metro','tram','ferry']
  taxi not in list → return false
  consecutive = true → days_passed resets to 0
  Challenge still in_progress (window has days remaining)
```

#### TC-CH-004: FOOD_NONE_MATCH — Meat-Free Day, mixed meal
```
Challenge: Meat-Free Day (FOOD_NONE_MATCH, excluded: ['beef','pork','poultry','chicken','lamb','fish','seafood'])
Preconditions: started today (1-day window)

Action: User logs breakfast (oats), lunch (chicken sandwich), dinner (vegetables)

Expected:
  evaluateStrategy → 'chicken' is in excluded_values → return false
  deadline_at = today → markFailed()
  Status: failed; immediately retryable
```

#### TC-CH-005: FOOD_ALL_MATCH — Plant-Based Week, day passes
```
Challenge: Plant-Based Week (FOOD_ALL_MATCH, accepted: ['vegetables','legumes','tofu','soy','fruit','grains','nuts','seeds'])
Preconditions: days_passed = 3, consecutive = true, window 9 days, 5 days remaining

Action: User logs breakfast (oats/grains), lunch (tofu stir-fry), dinner (lentils/legumes)

Expected:
  evaluateStrategy → all entries in accepted_values → return true
  days_passed = 4
  4 < 7 (required) → still in_progress
```

#### TC-CH-006: Plant-Based Week — one missed day resets count
```
Preconditions: days_passed = 4, consecutive = true, window 9 days, 4 days remaining

Action: midnight audit — no log today

Expected:
  consecutive = true → days_passed = 0
  4 days remaining in window; technically still possible (need 7 consecutive days in 4 remaining = impossible)
  Next audit will mark failed when deadline passes with days_passed < 7
```

#### TC-CH-007: Non-consecutive challenge — missed day does not reset count
```
Challenge: Walk 7 Days (TRANSPORT_ANY_MATCH, non-consecutive, window 10 days)
Preconditions: days_passed = 4, 5 days remaining in window

Action: midnight audit — no log today

Expected:
  consecutive = false → days_passed unchanged = 4
  5 days remaining; still possible to reach 7 if user logs walking the next 3
  No reset
```

#### TC-CH-008: LOG_TAG_PRESENT — Cold Shower Week, tag missing
```
Challenge: Cold Shower Week (LOG_TAG_PRESENT, tag: 'cold_shower', non-consecutive)
Preconditions: days_passed = 5, window 10 days

Action: User submits log with energy.confirmed = true but deviations = ['low_screen_time']

Expected:
  'cold_shower' NOT in deviations → return false
  non-consecutive → days_passed unchanged = 5
```

#### TC-CH-009: LOG_TAG_ABSENT — No AC Week, energy not confirmed
```
Challenge: No AC Week (LOG_TAG_ABSENT, tag: 'ac_used', consecutive)
Preconditions: days_passed = 3

Action: User submits log with energy.confirmed = false (user did not confirm energy tab)

Expected:
  energy.confirmed = false → evaluateStrategy returns false (requires confirmed)
  consecutive → days_passed = 0
  User is effectively penalised for not confirming energy — this is intentional: the challenge
  requires the user to actively log their energy status
```

#### TC-CH-010: APP_BEHAVIOR — 100-Day Green Journey, partial log counts
```
Challenge: 100-Day Green Journey (APP_BEHAVIOR, consecutive, 100 days)
Preconditions: days_passed = 50

Action: User submits partial log (transport only)

Expected:
  APP_BEHAVIOR → return true (any log counts)
  days_passed = 51
```

#### TC-CH-011: Challenge repeat — XP decay and cooldown growth
```
Challenge: Meat-Free Day (Easy, single-day, base XP 100, base cooldown 7 days)
Preconditions: completion_num will be 3 (two previous completions recorded)

Action: Challenge completed for 3rd time

Expected:
  xpMult = max(0.50, 1.0 - 0.10 × (3-1)) = max(0.50, 0.80) = 0.80
  xpAwarded = round(100 × 0.80) = 80
  cooldownMult = min(3.0, 1.0 + 0.5 × (3-1)) = min(3.0, 2.0) = 2.0
  cooldownDays = round(7 × 2.0) = 14
  cooldown_ends_at = today + 14
```

#### TC-CH-012: Challenge at XP decay floor (6th+ completion)
```
Challenge: Walk 7 Days (Easy multi-day, base XP 100)
Preconditions: completion_num = 7

Expected:
  xpMult = max(0.50, 1.0 - 0.10 × 6) = max(0.50, 0.40) = 0.50
  xpAwarded = round(100 × 0.50) = 50
  cooldownMult = min(3.0, 1.0 + 0.5 × 6) = min(3.0, 4.0) = 3.0
  cooldownDays = round(14 × 3.0) = 42
```

#### TC-CH-013: Deadline expiry mid-window
```
Challenge: No Car Week (Medium, 10-day window, 7 required consecutive)
Preconditions: days_passed = 6, today = deadline_at (day 10)

Action: midnight audit runs

Expected:
  days_passed (6) < required_days (7) AND deadline reached → markFailed()
  Status: failed; immediately retryable
  No XP awarded
```

#### TC-CH-014: Race condition — log and audit fire near simultaneously
```
Preconditions: user submits log at 23:59; midnight audit scheduled at 00:01

Action: evaluateChallengesForUser() runs at 23:59; midnightAudit() runs 2 minutes later

Expected:
  Both functions acquire SELECT FOR UPDATE on user_challenges
  The function that arrives first holds the lock; second waits
  No double-increment of days_passed
  No corruption of consecutive reset
```

---

### 13.5 Badges

#### TC-BG-001: Category badge — transport bronze
```
Preconditions: user has 2 completed transport challenges

Action: 3rd transport challenge marked complete (evaluateBadges called)

Expected:
  COUNT(challenge_completions WHERE category='transport') = 3
  3 >= Bronze threshold (3) → award Road to Green Bronze 🥉
  Push notification: badge earned
  Full-screen animation triggered
```

#### TC-BG-002: Badge idempotency — cannot earn same badge twice
```
Preconditions: Road to Green Bronze already in user_badges

Action: 4th transport challenge completed; evaluateBadges called again

Expected:
  Badge already exists → skip (no insert, no notification, no animation)
  Silver threshold check: 4 < 7 → no silver yet
```

#### TC-BG-003: Nature badge — adjusted thresholds
```
Challenge: 100-Day Green Journey (only Nature challenge in v1)
Preconditions: 0 previous nature completions

Action: 100-Day Green Journey completed (1st time)

Expected:
  completionNum = 1
  Nature Bronze threshold = 1 → award Nature Keeper Bronze 🥉
  xpAwarded = 400 (1st completion, no decay)
```

#### TC-BG-004: All-Rounder badge — all 4 categories completed in v1
```
Preconditions: user has completed ≥1 challenge in Transport, Food, Energy but not Nature

Action: 100-Day Green Journey completed

Expected:
  All 4 active categories now have ≥1 completion
  All-Rounder 🌐 awarded
  If Lifestyle added in v1.2: users who already hold All-Rounder keep it; new earners need all 5
```

#### TC-BG-005: Eco Newcomer — first log only
```
Preconditions: user has zero daily_logs

Action: First log submitted

Expected:
  COUNT(daily_logs WHERE user_id) = 1
  Eco Newcomer ✨ awarded
  Second log submission: COUNT = 2 → badge already in user_badges → skip
```

#### TC-BG-006: Quiz Whiz — 5th perfect score
```
Preconditions: 4 previous quiz sessions with score = 10

Action: Submit quiz session with 10/10

Expected:
  COUNT(quiz_sessions WHERE user_id AND score = 10) = 5
  Quiz Whiz 🧠 awarded
  6th perfect score: badge already exists → skip
```

#### TC-BG-007: Streak Saver — first use of Streak Freeze
```
Preconditions: streak_freeze_held = true; streak_days = 20; no log today

Action: midnight audit; no log; streak_freeze_held = true

Expected:
  Freeze consumed: streak_freeze_held = false
  streak_days NOT reset (stays 20)
  full_log_streak_days NOT reset
  Streak Saver 🛡️ awarded (if first ever use)
  Second freeze use: badge already exists → skip
```

---

### 13.6 Levels

#### TC-LV-001: Level-up from 1 to 2
```
Preconditions: lifetime_xp = 480, level = 1

Action: Log submission awards 50 XP

Expected:
  lifetime_xp = 530
  Threshold for Level 2 = 500 → level = 2
  Level up notification fired
  Unlock: log history, streak tracker visible
```

#### TC-LV-002: Level 5 unlock — quiz bonus becomes available
```
Preconditions: lifetime_xp = 4950, level = 4

Action: Challenge completion awards 100 XP

Expected:
  lifetime_xp = 5050
  level = 5
  Quiz perfect-score bonus (+50 XP) is now active for this user
  level multiplier changes from ×1.00 to ×1.10 (applies from next log)
  streak_freeze_queued flushes to streak_freeze_held if queued
```

#### TC-LV-003: Level 10 — ultimate badge
```
Preconditions: lifetime_xp = 30800, level = 9

Action: Log + challenge awards push lifetime_xp to 31200

Expected:
  level = 10
  Carbon Neutral 🌍 badge awarded
  ×1.75 streak multiplier tier now active for full_log_streak_days >= 100
  Champion badge, permanent leaderboard star visible
  Push notification
```

---

### 13.7 Leaderboard

#### TC-LB-001: monthly_xp resets on 1st of month; lifetime_xp does not
```
Preconditions: lifetime_xp = 15000, monthly_xp = 2400, level = 7

Action: Monthly reset job runs (1st of month)

Expected:
  monthly_xp = 0
  lifetime_xp = 15000 (unchanged)
  level = 7 (unchanged — derived from lifetime_xp)
  Leaderboard rankings reset
  Season reward XP (if applicable) applied BEFORE monthly_xp resets (so they count toward new month)
```

#### TC-LB-002: Leaderboard rank #1 reward
```
Preconditions: User finished month ranked #1 on global leaderboard

Action: Monthly reset job processes end-of-season rewards

Expected:
  lifetime_xp += 500
  monthly_xp (new month) += 500 (reward XP counts for the new season)
  Leaderboard Leader 👑 badge awarded (if not already held from a previous month)
  Champion crown visible on profile for the new month
  Push notification: monthly leaderboard results
```

#### TC-LB-003: Overtake notification — frequency cap
```
Preconditions: user has already received 3 overtake notifications today

Action: Hourly leaderboard job detects user was overtaken again (4th time today)

Expected:
  Notification suppressed (3/day cap reached)
  Rank updated in DB
  Notification resumes tomorrow
```

#### TC-LB-004: Weekly Sprint does not affect monthly leaderboard
```
Preconditions: User earned 200 monthly_xp this week from logging and challenges

Action: Weekly Sprint resets on Monday

Expected:
  Weekly Sprint leaderboard reset
  monthly_xp unchanged at 200 (weekly sprint is a separate view, not a separate XP bucket)
  Global monthly leaderboard rank unchanged
```

---

### 13.8 Push Notifications

#### TC-PN-001: Challenge reminder suppressed after log
```
Preconditions: User has in_progress challenge; logs at 11:30 AM

Action: Challenge reminder job fires at 12:00 PM

Expected:
  last_log_date = today → reminder suppressed
  No notification sent
```

#### TC-PN-002: Challenge reminder fires if no log yet
```
Preconditions: User has in_progress challenge; no log today by 12:00 PM

Action: Challenge reminder job fires at 12:00 PM

Expected:
  last_log_date < today → reminder fires
  Message: "Day [X]/[total] of '[Challenge]'. Keep going — you've got this!"
```

#### TC-PN-003: Streak warning — both tiers fire
```
Preconditions: streak_days = 14, no log by 8 PM

Action: 8 PM notification job runs; 10:30 PM job runs

Expected:
  8 PM: "Your 14-day streak is at risk! Log anything to keep it alive 🌿"
  10:30 PM (still no log): "Last chance to log today! Don't break your 14-day streak 🔥"
  No further notifications after 10:30 PM
```

#### TC-PN-004: Badge and level-up notifications cannot be disabled
```
Preconditions: User has disabled all notifications in Settings

Action: User earns a badge and levels up simultaneously

Expected:
  Badge notification fires (cannot be disabled)
  Level-up notification fires (cannot be disabled)
  All other notification types suppressed per user preference
```

---

### 13.9 Edge Cases & Boundary Conditions

#### TC-EC-001: User logs at exactly 23:59 on a missed streak day
```
Preconditions: streak_days = 20; no log all day; user submits at 23:59

Expected:
  Log accepted (within calendar day)
  Streak maintained (streak_days = 21)
  Midnight audit at 00:01 sees log exists for yesterday → no reset
```

#### TC-EC-002: Offline log syncs next day — XP yes, streak no
```
Preconditions:
  User logged transport on Day 1 at 11 PM while offline (original_timestamp = Day 1 23:00)
  App syncs on Day 2 at 9 AM

Action: Sync delivers Day 1 log

Expected:
  XP awarded for logDate = Day 1 (using Day 1 cap tracking)
  Streak NOT updated for Day 1 (original_timestamp is yesterday)
  streak_days already reset to 0 by midnight audit on Day 2 (because no log arrived before midnight)
  This is correct and expected — offline sync cannot rescue a streak
```

#### TC-EC-003: User with no food entries — FOOD_ALL_MATCH challenge
```
Challenge: Plant-Based Week (FOOD_ALL_MATCH)
Preconditions: User submits log with transport + energy but NO food entries

Action: evaluateStrategy called for food challenge

Expected:
  food entries array is empty → return false (spec: "If no food entries → return false")
  consecutive → days_passed resets to 0
  User must log food to make progress on food challenges
```

#### TC-EC-004: Two challenges complete on the same day — XP uncapped, both process
```
Preconditions: User has No Car Day AND Meat-Free Day both reaching completion today

Action: Two challenges marked complete by engine

Expected:
  No Car Day: 100 XP awarded to lifetime_xp and monthly_xp
  Meat-Free Day: 100 XP awarded to lifetime_xp and monthly_xp
  Total challenge XP: 200 XP (not capped — challenge XP is uncapped)
  Badge evaluations run for Transport and Food categories separately
  Two celebration animations queued
```

#### TC-EC-005: Level up and badge trigger on same XP update
```
Preconditions: lifetime_xp = 4990, level = 4; challenge completion awards 100 XP

Action: markComplete() adds 100 XP → lifetime_xp = 5090

Expected:
  Level recomputed: 5090 >= 5000 → level = 5
  Level-up event fires: quiz bonus unlocked, level multiplier to ×1.10
  If streak_freeze_queued = true → freeze activates now
  Badge Carbon Neutral NOT awarded (not Level 10)
  Transport/Food badge evaluation also runs (from challenge completion)
  Two distinct notifications: level-up + badge (if threshold crossed)
```

#### TC-EC-006: User at exactly Level 10 — no further level-up
```
Preconditions: level = 10, lifetime_xp = 35000

Action: Log submission awards 88 XP (full log, 100+ day streak, Level 10)

Expected:
  lifetime_xp = 35088
  monthly_xp += 88
  level = 10 (capped; no level-up event fires)
  No level-up notification
  XP still accumulates for leaderboard ranking
```

#### TC-EC-007: User below Level 4 starts No Car Week — Hard challenges gated
```
Preconditions: level = 3

Action: User attempts to start No Car Week (Medium — available to all)

Expected:
  No Car Week is Medium difficulty, no level gate → allowed
  User can have 1 challenge slot (Level 1), correct slot count for Level 3 = 1
  If user already has 1 active challenge → "Start Challenge" button disabled (slot full)
```

#### TC-EC-008: Hard challenge attempted before Level 6 unlock
```
Preconditions: level = 5

Action: User attempts to start Vegan Challenge (Hard)

Expected:
  Hard challenges unlock at Level 6
  Vegan Challenge card shows "Unlocks at Level 6" state
  Start button disabled
```

#### TC-EC-009: No Car Weekend started on a Wednesday
```
Challenge: No Car Weekend (start_day: "saturday")

Action: User attempts to start challenge on a Wednesday

Expected:
  UI shows "This challenge starts on Saturday"
  Start button disabled
  On Saturday → button enabled; challenge window: Saturday + Sunday only
```

#### TC-EC-010: Monthly XP reset + active challenge completion on same day
```
Preconditions: 1st of month; user completes a challenge at 8 AM (before reset job runs at 9 AM)

Action: Challenge completion at 8 AM; monthly reset job at 9 AM

Expected:
  8 AM: challenge XP added to monthly_xp (old month) — this is correct per spec:
        "Challenge XP counts toward the month in which the challenge was completed"
  9 AM: monthly reset: seasonal reward XP applied FIRST, then monthly_xp = 0
  Result: challenge XP correctly counted in the old month's final ranking
  The seasonal reward XP is added to the NEW month's monthly_xp (counts for next season)
```

#### TC-EC-011: All-Rounder badge when only 1 category is achievable at user's level
```
Preconditions: level = 2; Hard challenges locked; Nature only has 100-Day Green Journey (Hard)

Expected:
  At Level 2: user can only complete Easy/Medium challenges
  Nature's only challenge (Hard) is locked until Level 6
  All-Rounder badge is unachievable below Level 6 in v1
  This is acceptable — it creates a long-term goal
  Document this constraint in the badge description
```

---

*NeutraWise — Gamification System Design | Version 3.0 | Reviewed, Corrected & Ready to Implement*
