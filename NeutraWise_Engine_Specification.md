# NeutraWise — Engine Specification
## Challenge Evaluator Engine & Badge Engine
### Derived from Gamification System v3.0 + Mid-Day Reversal Fix

---

## Part 1 — Challenge Evaluator Engine

---

### 1.1 Responsibility Boundary

The challenge evaluator engine is responsible for exactly one thing: **keeping every user's challenge progress in sync with their activity log at all times.**

It does not award XP. It does not send notifications. It does not evaluate badges. Each of those is a downstream side effect triggered by the engine when it calls `markComplete()` or `markFailed()`, but the computation inside those calls belongs to separate, dedicated functions.

The engine has two entry points that serve different purposes:

| Entry Point | Triggered By | Purpose |
|---|---|---|
| `evaluateChallengesForUser()` | Every log submission or log update | Re-evaluate today's qualification flag for all active challenges |
| `midnightAudit()` | Scheduled job at 00:01 local time (per user timezone) | Lock in the day's result, advance `days_passed`, detect failures and completions |

These two functions are the only things that write to `user_challenges` and `challenge_daily_progress`. Nothing else in the system touches those tables.

---

### 1.2 Schema — What the Engine Reads and Writes

```sql
-- Challenge definitions (read-only by the engine; written by admin/migrations)
challenges {
  id                  UUID PRIMARY KEY,
  name                TEXT NOT NULL,
  category            TEXT NOT NULL,        -- transport | food | energy | nature
  difficulty          TEXT NOT NULL,        -- easy | medium | hard
  duration_type       TEXT NOT NULL,        -- single_day | multi_day
  window_days         INTEGER NOT NULL,     -- total length of the challenge window
  required_days       INTEGER NOT NULL,     -- qualifying days needed to complete
  consecutive         BOOLEAN NOT NULL,     -- must qualifying days be consecutive?
  xp_reward           INTEGER NOT NULL,
  strategy            TEXT NOT NULL,        -- see Section 1.4
  strategy_params     JSONB NOT NULL,       -- strategy-specific config
  start_day_constraint TEXT,               -- e.g. 'saturday'; NULL means any day
  is_active           BOOLEAN DEFAULT TRUE
}

-- Per-user challenge enrollment and progress (written by the engine)
user_challenges {
  id               UUID PRIMARY KEY,
  user_id          UUID NOT NULL REFERENCES users(id),
  challenge_id     UUID NOT NULL REFERENCES challenges(id),
  status           TEXT NOT NULL DEFAULT 'in_progress',  -- in_progress | completed | failed
  started_at       DATE NOT NULL,
  deadline_at      DATE NOT NULL,     -- started_at + window_days; set at enrollment
  completed_at     DATE,
  days_passed      INTEGER NOT NULL DEFAULT 0,
  cooldown_ends_at DATE,              -- NULL until completed; read by UI to derive availability
  UNIQUE(user_id, challenge_id, started_at)
}

-- Mutable daily qualification flag (key insight from mid-day reversal fix)
-- Written by evaluateChallengesForUser(); read by midnightAudit()
challenge_daily_progress {
  user_id       UUID NOT NULL REFERENCES users(id),
  challenge_id  UUID NOT NULL REFERENCES challenges(id),
  date          DATE NOT NULL,
  qualified     BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, challenge_id, date)
}

-- Historical record of all completions (written by markComplete(); read by cooldown/decay logic)
challenge_completions {
  id             UUID PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES users(id),
  challenge_id   UUID NOT NULL REFERENCES challenges(id),
  completed_at   DATE NOT NULL,
  xp_awarded     INTEGER NOT NULL,
  completion_num INTEGER NOT NULL   -- 1 = first time, 2 = second, etc.
}
```

**The separation between `challenge_daily_progress` and `user_challenges.days_passed` is the most important design decision in this engine.** `days_passed` is only ever written by the midnight audit. `challenge_daily_progress.qualified` is written on every log update and can flip back and forth throughout the day. The two values serve entirely different purposes:

- `qualified` (per-day flag): *"Did today's log state meet the criteria as of right now?"* — mutable, real-time.
- `days_passed` (cumulative counter): *"How many days have been confirmed as qualifying so far?"* — immutable once set by midnight, never touched intraday.

---

### 1.3 The Two Entry Points in Full Detail

#### Entry Point 1: `evaluateChallengesForUser(userId, logDate, dailyResult)`

**When it runs:** immediately after any log submission or log update, synchronously within the same request-response cycle as the log save. If the log save fails, this does not run.

**What it does:** for each challenge the user is currently enrolled in, it evaluates whether today's log state meets the challenge criteria, and writes that result to `challenge_daily_progress`. It does not touch `days_passed`.

```
FUNCTION evaluateChallengesForUser(userId, logDate, dailyResult):

  ── Guard: only process the current calendar day ──────────────────────────────
  If logDate < today:
    -- This is a late-arriving offline sync for a past date.
    -- The midnight audit for that date has already run and its result is final.
    -- Do NOT upsert challenge_daily_progress for past dates.
    -- Do NOT modify days_passed.
    Return.  (XP for the log is still awarded separately by awardDailyXP.)

  ── Acquire row-level lock ─────────────────────────────────────────────────────
  -- Both this function and midnightAudit() write to the same rows.
  -- The lock prevents a race condition where both run within seconds of each other
  -- (e.g. user submits log at 23:59 while audit fires at 00:01).
  rows = SELECT * FROM user_challenges
         WHERE user_id = userId AND status = 'in_progress'
         FOR UPDATE

  If rows is empty: Return.  -- User has no active challenges.

  ── Evaluate each active challenge ────────────────────────────────────────────
  For each row (uc) in rows:

    challenge = challenges[uc.challenge_id]

    -- Dead challenge: window already expired.
    -- Don't evaluate; midnightAudit will mark it failed.
    If logDate > uc.deadline_at: Continue.

    -- Run the strategy evaluator (see Section 1.4)
    qualified = evaluateStrategy(challenge.strategy, challenge.strategy_params, dailyResult)

    -- Write (or overwrite) today's qualification flag.
    -- UPSERT means: if a record for (userId, challengeId, today) already exists,
    -- update it. Otherwise insert it.
    -- This is the mechanism that handles mid-day reversals:
    -- a qualifying entry logged at 8 AM sets qualified = true;
    -- a violating entry at 6 PM overwrites it with qualified = false.
    UPSERT INTO challenge_daily_progress
      (user_id, challenge_id, date, qualified)
      VALUES (userId, uc.challenge_id, logDate, qualified)
      ON CONFLICT (user_id, challenge_id, date) DO UPDATE SET qualified = qualified

  -- Release lock (implicit at end of transaction)
```

**What it deliberately does NOT do:**
- Does not increment `days_passed` — only the midnight audit does that.
- Does not call `markComplete()` or `markFailed()` — only the midnight audit does that.
- Does not send notifications.
- Does not award XP.

**What the UI reads for real-time progress display:**

The UI cannot read `days_passed` alone — that would show yesterday's confirmed state. It must combine the two:

```
displayProgress(userId, challengeId):
  uc = user_challenges row for (userId, challengeId)
  confirmedDays = uc.days_passed               -- locked-in days up to yesterday midnight

  todayRecord = challenge_daily_progress
                WHERE user_id = userId AND challenge_id = challengeId AND date = today
  todayQualified = todayRecord?.qualified ?? false

  -- Show the user live, honest progress including today's current state
  displayDays = confirmedDays + (todayQualified ? 1 : 0)
  displayTotal = challenge.required_days
  Return { displayDays, displayTotal }
```

This means the progress bar rises the moment the user logs a qualifying entry, and drops the moment they log a violating one — immediate honest feedback without corrupting the audit-controlled counter.

---

#### Entry Point 2: `midnightAudit(userId, auditDate)`

**When it runs:** at 00:01 in the user's local timezone, triggered by a `pg_cron` job. The job processes all users in batches, staggered by timezone.

**What it does:** reads the final `qualified` state for `auditDate` from `challenge_daily_progress` (which was set by `evaluateChallengesForUser()` throughout the day and is now immutable), applies it to `days_passed`, checks for completions and failures, and handles streak counters and the Streak Freeze.

```
FUNCTION midnightAudit(userId, auditDate):

  ── Acquire row-level lock ─────────────────────────────────────────────────────
  rows = SELECT * FROM user_challenges
         WHERE user_id = userId AND status = 'in_progress'
         FOR UPDATE

  ── Determine whether a log was submitted today ───────────────────────────────
  -- The single source of truth for "did the user log today" is daily_logs.
  -- Both streak logic and challenge logic read from the same query.
  logExists = SELECT EXISTS (
    FROM daily_logs
    WHERE user_id = userId AND date = auditDate
  )

  ── Handle streak counters ────────────────────────────────────────────────────
  -- (Full streak logic in streak spec; summarised here for context)
  user = SELECT streak_days, full_log_streak_days, streak_freeze_held, ... FROM users WHERE id = userId

  If NOT logExists:
    If user.streak_freeze_held:
      -- Freeze consumed: counters not reset, freeze deactivated
      UPDATE users SET streak_freeze_held = false WHERE id = userId
      triggerBadge('streak_saver', userId)    -- awards badge if first use
    Else:
      -- No log, no freeze: both counters reset
      UPDATE users SET streak_days = 0, full_log_streak_days = 0 WHERE id = userId

  ── Process each active challenge ─────────────────────────────────────────────
  For each row (uc) in rows:

    challenge = challenges[uc.challenge_id]

    ── Read today's qualification result ──────────────────────────────────────
    record = SELECT qualified FROM challenge_daily_progress
             WHERE user_id = userId AND challenge_id = uc.challenge_id AND date = auditDate

    -- If no record exists, it means no log was submitted today for this date.
    -- This is equivalent to qualified = false.
    qualified = record?.qualified ?? false

    ── Apply qualification result to days_passed ──────────────────────────────
    If qualified:
      -- Day counts. Increment regardless of consecutive or not.
      uc.days_passed = uc.days_passed + 1

    Else If NOT qualified AND challenge.consecutive:
      -- Consecutive challenge: one missed/failed day resets the run.
      -- The window keeps running — user can restart within remaining days.
      uc.days_passed = 0

    Else If NOT qualified AND NOT challenge.consecutive:
      -- Non-consecutive: missed day just reduces remaining opportunity.
      -- Counter unchanged. Window shrinks by one day.
      -- (No action needed on days_passed)

    -- Special case: APP_BEHAVIOR with no log.
    -- APP_BEHAVIOR returns true for any log submission, so if no log exists,
    -- qualified = false. Since APP_BEHAVIOR challenges are always consecutive,
    -- the branch above (consecutive + not qualified) resets days_passed.
    -- No special handling needed.

    ── Streak Freeze and consecutive challenges ───────────────────────────────
    -- If a Streak Freeze was consumed today (i.e., the user missed logging but
    -- the freeze protected their streak), consecutive challenge progress is also
    -- protected: do NOT reset days_passed for that missed day.
    -- Implementation: if streak_freeze_held was true at start of audit AND
    -- logExists = false, treat qualified as false for streak purposes but
    -- do NOT reset consecutive challenge counters.
    -- (This requires reading freeze state before modifying it above.)
    If freezeWasConsumedToday AND NOT qualified AND challenge.consecutive:
      -- Freeze protects the streak AND consecutive challenge progress.
      -- Undo the reset: days_passed stays as it was before the audit iteration.
      uc.days_passed = previousDaysPassed   -- restore pre-iteration value

    ── Check for completion ───────────────────────────────────────────────────
    If uc.days_passed >= challenge.required_days:
      markComplete(userId, uc, challenge, auditDate)
      Continue  -- skip failure check; challenge is done

    ── Check for failure (deadline passed without completion) ─────────────────
    -- Use >= because deadline_at is the last valid day of the window.
    -- After midnight of deadline_at, the window is closed.
    If auditDate >= uc.deadline_at AND uc.days_passed < challenge.required_days:
      markFailed(uc)
      Continue

    ── Persist updated days_passed ───────────────────────────────────────────
    UPDATE user_challenges SET days_passed = uc.days_passed WHERE id = uc.id

  -- Release lock
```

---

### 1.4 Strategy Evaluator: `evaluateStrategy(strategy, params, dailyResult)`

This is the core of the engine. It is a pure function — given a strategy name, its parameters, and the current state of the daily log, it returns `true` or `false`. It has no side effects and no database access. It is called only by `evaluateChallengesForUser()`.

The `dailyResult` object is the output of `processDailyLog()` from the algorithm spec. The relevant fields are:

```
dailyResult {
  transportLegs: [
    { mode: string, distanceKm: number, co2: number },
    ...
  ],
  foodEntries: [
    { name: string, category: string, servingGrams: number, co2: number, mealSlot: string },
    ...
  ],
  energy: {
    confirmed: boolean,
    deviations: string[],    -- e.g. ['cold_shower', 'unplugged_devices']
    totalKwh: number,
    co2: number
  },
  totalDailyCO2: number,
  baselineCO2: number,
  percentVsBaseline: number  -- negative = below baseline (better than usual)
}
```

#### All Strategy Types

---

**`LOG_FIELD_ZERO`**

Passes if the sum of a specific numeric field across all transport legs equals zero. Used for "no car" challenges.

```
evaluateStrategy('LOG_FIELD_ZERO', { field: 'car_km' }, dailyResult):

  -- Sum the specified field across all transport legs
  total = 0
  For each leg in dailyResult.transportLegs:
    If leg.mode == 'car' OR leg.mode == 'ev' OR leg.mode == 'motorcycle':
      -- Only car-type modes contribute to car_km
      -- (The field name in params tells us what to sum; the strategy is generic)
      total += leg.distanceKm

  -- A user who logged no transport at all has zero legs.
  -- sum of zero items = 0. This correctly passes the challenge:
  -- a user who walked everywhere and didn't touch a car qualifies.
  Return total == 0
```

*Edge case — no transport logged:* `total = 0`. Returns `true`. This is correct: a user who stayed home or walked and logged no transport entries has genuinely used no car. The challenge passes.

*Edge case — transport logged as EV:* EVs produce CO₂ via grid electricity but the challenge is about private car removal from roads. Spec decision: EVs count as "car" for LOG_FIELD_ZERO challenges. This is deliberate — the challenge targets road traffic, not just combustion. This should be stated in the challenge description.

*Edge case — zero-distance car trip:* A user who logs `mode: 'car', distanceKm: 0` for some reason. `total = 0`. Returns `true`. This is acceptable: a 0 km car trip is a data entry anomaly, not a real trip. The validator on the log UI should enforce `distanceKm > 0`.

---

**`TRANSPORT_ANY_MATCH`**

Passes if at least one transport leg has a mode in the accepted values. Used for "cycle to work" or "walk" challenges where the user just needs to have done the behaviour at least once that day.

```
evaluateStrategy('TRANSPORT_ANY_MATCH', { accepted_values: ['cycling'] }, dailyResult):

  If dailyResult.transportLegs is empty:
    Return false
    -- The user must have logged at least one transport entry.
    -- An empty log means they made no active transport entries;
    -- we cannot infer they were cycling.

  For each leg in dailyResult.transportLegs:
    If leg.mode in params.accepted_values:
      Return true   -- found at least one qualifying leg; done

  Return false
```

*Edge case — user cycles to work and takes a taxi home:* Two legs: `{mode: 'cycling', ...}` and `{mode: 'taxi', ...}`. ANY_MATCH finds the cycling leg first. Returns `true`. The taxi does not disqualify the day. This is correct for "Cycle to Work Week" — the challenge only requires that the user cycled at some point.

*Edge case — no transport logged:* Returns `false`. The user must actively log at least one transport entry for the day to count. Logging nothing is not evidence of having cycled.

*Edge case — user logs walking AND cycling:* Both are in `accepted_values: ['walking']` for Walk 7 Days. Either would trigger `true`. Correct.

---

**`TRANSPORT_ALL_MATCH`**

Passes only if every transport leg logged has a mode in the accepted values. Used for "public transport month" where any private vehicle use disqualifies the day.

```
evaluateStrategy('TRANSPORT_ALL_MATCH', { accepted_values: ['bus','train','metro','tram','ferry'] }, dailyResult):

  If dailyResult.transportLegs is empty:
    Return false
    -- The user must have logged transport entries for the day to count.
    -- Logging nothing is not evidence of using public transport.

  For each leg in dailyResult.transportLegs:
    If leg.mode NOT IN params.accepted_values:
      Return false   -- found a disqualifying leg; fail immediately

  Return true   -- all legs passed
```

*Edge case — user logs bus to work, then taxi for one errand:* Taxi is not in `accepted_values`. Returns `false` immediately on finding the taxi leg. Day fails. This is correct and strict — the challenge requires exclusive public transit use.

*Edge case — user logs only walking:* Walking is not in `accepted_values` for Public Transport Month. Returns `false`. This is a deliberate design choice: the challenge specifically promotes public transit, not just car-free travel. If walking should qualify, `walking` must be in `accepted_values`. Check the challenge definition.

*Edge case — user logs no transport (stayed home):* Returns `false`. The user must log at least one public transport entry. This is the correct strict interpretation for a "public transport month" challenge. Staying home every day should not complete the challenge.

> **Design note:** This is the most debatable edge case. An alternative is to return `true` for empty transport (treating a no-transport day as "no violation"). This would allow users to complete Public Transport Month by simply never logging car trips. The conservative implementation (`empty → false`) is recommended because it prevents passive completion without active behaviour change.

---

**`FOOD_NONE_MATCH`**

Passes if no food entry has a category in the excluded values. Used for meat-free challenges.

```
evaluateStrategy('FOOD_NONE_MATCH', { excluded_values: ['beef','pork','poultry','chicken','lamb','fish','seafood'] }, dailyResult):

  If dailyResult.foodEntries is empty:
    Return false
    -- The user must have logged at least one food entry.
    -- An empty food log provides no evidence of a meat-free day.

  For each entry in dailyResult.foodEntries:
    If entry.category IN params.excluded_values:
      Return false   -- found a disqualifying entry; fail immediately

  Return true   -- no excluded category found in any entry
```

*Edge case — user logs only a snack (no main meals):* One entry. If the snack is not in `excluded_values`, returns `true`. The challenge passes with minimal logging. This is acceptable — the challenge does not require logging all meals; it requires that whatever was logged contains no meat.

*Edge case — user logs eggs:* `eggs` is not in the default excluded list for Meat-Free Day. Eggs are animal products but not meat. The challenge passes. The excluded list in the challenge definition controls this; the engine is agnostic.

*Edge case — food item category is null:* If a food item from the Open Food Facts API has no category that the mapper recognises, it falls back to `vegetables_avg`. The engine sees `vegetables_avg`, which is not in `excluded_values`. Returns `true` for that item. This is a permissive fallback — unrecognised items don't penalise the user.

---

**`FOOD_ALL_MATCH`**

Passes only if every food entry has a category in the accepted values. Used for plant-based challenges where any animal product disqualifies the day.

```
evaluateStrategy('FOOD_ALL_MATCH', { accepted_values: ['vegetables','legumes','tofu','soy','fruit','grains','nuts','seeds'] }, dailyResult):

  If dailyResult.foodEntries is empty:
    Return false
    -- User must log food. Empty food log ≠ plant-based day.

  For each entry in dailyResult.foodEntries:
    If entry.category NOT IN params.accepted_values:
      Return false   -- found a disqualifying entry; fail immediately

  Return true
```

*Edge case — user logs a cup of coffee (category: `coffee_brewed`):* `coffee_brewed` is not in `accepted_values`. Returns `false`. This fails Plant-Based Week. This is a known limitation: coffee is plant-derived but its OFF category doesn't map to the accepted list. The `accepted_values` list should include `coffee_brewed` and `tea` if the intent is vegan/plant-based. Check challenge definition.

*Edge case — user logs dairy milk:* `milk_dairy` is not in `accepted_values`. Returns `false`. Correct — dairy is an animal product.

*Edge case — fallback category is `vegetables_avg`:* An unrecognised food item maps to `vegetables_avg`. This IS in `accepted_values`. Returns `true` for that item. Permissive fallback benefits the user.

---

**`LOG_TAG_PRESENT`**

Passes if a specific deviation tag appears in the energy log AND the user confirmed the energy section.

```
evaluateStrategy('LOG_TAG_PRESENT', { tag: 'cold_shower' }, dailyResult):

  If dailyResult.energy.confirmed == false:
    Return false
    -- The user must have explicitly confirmed their energy log.
    -- An unconfirmed energy section means the user skipped it;
    -- we cannot infer the tag was present.

  Return params.tag IN dailyResult.energy.deviations
```

*Edge case — energy not confirmed:* Returns `false` unconditionally, regardless of what might be in `deviations`. The requirement for `confirmed = true` is not arbitrary: it ensures the user actively visited the energy tab and made a deliberate selection. A user who submits only transport and food without touching energy has `confirmed = false`.

*Edge case — user selects the tag then deselects it:* The final state of `deviations` is what the engine sees. If the tag was removed before submission, it is not in the array. Returns `false`. The mid-day reversal fix handles the case where this happens across separate submissions: `evaluateChallengesForUser()` re-evaluates on every update and overwrites `challenge_daily_progress.qualified`.

*Edge case — tag name mismatch (`'cold_shower'` vs `'cold_showers'`):* The tag must match exactly. Tag names are defined in the energy deviation constants in the algorithm spec. Any mismatch silently returns `false`. The challenge `strategy_params` and the UI deviation chip values must use identical tag name strings. A mismatch is a configuration bug, not a code bug.

---

**`LOG_TAG_ABSENT`**

Passes if a specific deviation tag does NOT appear in the energy log AND the user confirmed. Used for "No AC Week."

```
evaluateStrategy('LOG_TAG_ABSENT', { tag: 'ac_used' }, dailyResult):

  If dailyResult.energy.confirmed == false:
    Return false
    -- Same reason as LOG_TAG_PRESENT: confirmed = true is required.
    -- Without confirmation, we cannot know whether the user ran AC or not.

  Return params.tag NOT IN dailyResult.energy.deviations
```

*Edge case — user confirms energy with no deviations selected ("Typical Day"):* `deviations = []`. `'ac_used'` is not in `[]`. Returns `true`. This correctly passes the challenge: a typical day with no AC tag means the user didn't log AC use.

*Edge case — user forgets to confirm energy:* `confirmed = false`. Returns `false`. This is intentional and strict: for a consecutive challenge like No AC Week, forgetting to confirm energy resets the run. This creates a strong incentive to always confirm energy — which is good for data quality.

*Edge case — user confirms and selects other deviations but not `ac_used`:* `deviations = ['cold_shower', 'unplugged_devices']`. `'ac_used'` not present. Returns `true`. Correct: other deviations don't affect this challenge.

---

**`APP_BEHAVIOR`**

Passes if any log exists for that day. This is the simplest strategy — it asks only "did the user open the app and log something today?"

```
evaluateStrategy('APP_BEHAVIOR', { metric: 'consecutive_active_days' }, dailyResult):

  -- If evaluateChallengesForUser() is being called, a log was just submitted.
  -- The very fact that we are evaluating means a log exists.
  -- This strategy always returns true when called from evaluateChallengesForUser().
  Return true

  -- The "consecutive" enforcement is handled by the midnight audit:
  -- if no log arrives by midnight, midnightAudit() sees no challenge_daily_progress
  -- record for today (qualified = false by default), and resets days_passed.
```

*Edge case — partial log (transport only):* Returns `true`. Any log counts. This is aligned with the streak rule: partial logs maintain the streak AND pass APP_BEHAVIOR challenges.

*Edge case — called from midnightAudit() with no log:* `evaluateStrategy()` is NOT called from `midnightAudit()`. The audit reads `challenge_daily_progress.qualified` directly. If no log was submitted, no `challenge_daily_progress` record exists for today, so `qualified = false`. The consecutive reset fires. This is the correct behaviour.

---

### 1.5 `markComplete(userId, uc, challenge, completionDate)`

Called by `midnightAudit()` when `days_passed >= required_days`. Handles XP decay, cooldown growth, persistence, and triggers downstream effects.

```
FUNCTION markComplete(userId, uc, challenge, completionDate):

  ── Count previous completions ─────────────────────────────────────────────────
  completionNum = SELECT COUNT(*) FROM challenge_completions
                  WHERE user_id = userId AND challenge_id = challenge.id
  completionNum = completionNum + 1    -- this completion will be #completionNum

  ── Calculate decayed XP ──────────────────────────────────────────────────────
  xpMultiplier = max(0.50, 1.0 - 0.10 × (completionNum - 1))
  xpAwarded    = round(challenge.xp_reward × xpMultiplier)
  -- Floor: 50% of base XP. Easy(100)→50, Medium(200)→100, Hard(400)→200 minimum.

  ── Calculate cooldown ────────────────────────────────────────────────────────
  baseCooldown = BASE_COOLDOWN[challenge.difficulty][challenge.duration_type]
  -- duration_type: 'single_day' or 'multi_day'
  -- BASE_COOLDOWN = {
  --   easy:   { single_day: 7,  multi_day: 14 },
  --   medium: { any: 30 },
  --   hard:   { any: 90 }
  -- }
  cooldownMultiplier = min(3.0, 1.0 + 0.5 × (completionNum - 1))
  cooldownDays       = round(baseCooldown × cooldownMultiplier)
  cooldownEndsAt     = completionDate + cooldownDays

  ── Persist ───────────────────────────────────────────────────────────────────
  INSERT INTO challenge_completions
    (user_id, challenge_id, completed_at, xp_awarded, completion_num)
    VALUES (userId, challenge.id, completionDate, xpAwarded, completionNum)

  UPDATE user_challenges
    SET status = 'completed',
        completed_at = completionDate,
        cooldown_ends_at = cooldownEndsAt,
        days_passed = challenge.required_days   -- lock in final count
    WHERE id = uc.id

  ── Award XP (bypasses daily cap; challenge XP is always uncapped) ────────────
  UPDATE users
    SET lifetime_xp = lifetime_xp + xpAwarded,
        monthly_xp  = monthly_xp  + xpAwarded
    WHERE id = userId

  Recompute level from new lifetime_xp
  If level increased: triggerLevelUp(userId, newLevel)

  ── Trigger downstream effects ────────────────────────────────────────────────
  evaluateBadges(userId, challenge.category)   -- badge engine (Part 2)
  triggerPushNotification('challenge_complete', userId, {
    challengeName: challenge.name,
    xpAwarded,
    cooldownDays
  })
  triggerCelebrationAnimation(userId, 'challenge_complete')
```

---

### 1.6 `markFailed(uc)`

Called by `midnightAudit()` when the deadline passes without completion. Simple — no XP, no cooldown, immediate retry available.

```
FUNCTION markFailed(uc):

  UPDATE user_challenges
    SET status = 'failed',
        completed_at = NULL,
        cooldown_ends_at = NULL    -- NULL means immediately retryable
    WHERE id = uc.id

  triggerPushNotification('challenge_failed', uc.user_id, {
    challengeName: challenges[uc.challenge_id].name
  })
  -- No XP deducted. No cooldown. No badge evaluation.
  -- The challenge appears immediately in the browse screen with a "Try Again" button.
```

---

### 1.7 Challenge Enrollment

When a user starts a challenge, this writes the initial `user_challenges` row. The engine then picks it up automatically on the next log submission.

```
FUNCTION enrollInChallenge(userId, challengeId, enrollmentDate):

  challenge = challenges[challengeId]

  ── Validate enrollment ───────────────────────────────────────────────────────
  -- Slot check: user must have an available challenge slot for their level
  activeCount = SELECT COUNT(*) FROM user_challenges
                WHERE user_id = userId AND status = 'in_progress'
  If activeCount >= MAX_SLOTS[user.level]: Return error('No challenge slots available')

  -- Cooldown check: challenge must not be in cooldown
  existing = SELECT cooldown_ends_at FROM user_challenges
             WHERE user_id = userId AND challenge_id = challengeId
             AND status = 'completed'
             ORDER BY completed_at DESC LIMIT 1
  If existing?.cooldown_ends_at > today: Return error('Challenge in cooldown until X')

  -- Duplicate check: cannot enroll in same challenge twice simultaneously
  If EXISTS(user_challenges WHERE user_id = userId AND challenge_id = challengeId AND status = 'in_progress'):
    Return error('Already enrolled')

  -- Level gate: Hard challenges require Level 6+
  If challenge.difficulty == 'hard' AND user.level < 6:
    Return error('Unlocks at Level 6')

  -- Start day constraint (e.g. No Car Weekend only starts on Saturday)
  If challenge.start_day_constraint IS NOT NULL:
    If dayOfWeek(enrollmentDate) != challenge.start_day_constraint:
      Return error('This challenge must be started on a [day]')

  ── Create enrollment ─────────────────────────────────────────────────────────
  INSERT INTO user_challenges
    (user_id, challenge_id, status, started_at, deadline_at, days_passed)
    VALUES (userId, challengeId, 'in_progress', enrollmentDate, enrollmentDate + challenge.window_days, 0)
```

---

### 1.8 Availability Derivation

The concept of a challenge being "available" is not a database status — it is derived at read time by the UI layer. There is no `available` status in the database.

```
FUNCTION getChallengeAvailability(userId, challengeId, today):

  challenge = challenges[challengeId]
  If NOT challenge.is_active: Return 'unavailable'

  -- Check for active enrollment
  active = SELECT * FROM user_challenges
           WHERE user_id = userId AND challenge_id = challengeId AND status = 'in_progress'
  If active EXISTS: Return 'in_progress'

  -- Check for failed (immediately retryable)
  failed = SELECT * FROM user_challenges
           WHERE user_id = userId AND challenge_id = challengeId AND status = 'failed'
           ORDER BY started_at DESC LIMIT 1
  If failed EXISTS AND failed.cooldown_ends_at IS NULL: Return 'available'

  -- Check for cooldown
  completed = SELECT cooldown_ends_at FROM user_challenges
              WHERE user_id = userId AND challenge_id = challengeId AND status = 'completed'
              ORDER BY completed_at DESC LIMIT 1
  If completed EXISTS:
    If completed.cooldown_ends_at > today: Return 'cooldown'
    Else: Return 'available'

  -- Never enrolled before
  Return 'available'
```

---

### 1.9 Full Data Flow Diagram

```
USER SUBMITS OR UPDATES A LOG
            │
            ▼
   processDailyLog()          ← Algorithm spec: computes CO2, produces dailyResult
            │
            ├──────────────────────────────────────────────────────┐
            ▼                                                      ▼
   awardDailyXP()                              evaluateChallengesForUser()
   (awards XP immediately;                     (for each in_progress challenge:
    delta-upgrade if log improved)              evaluateStrategy() → true/false
                                                UPSERT challenge_daily_progress
                                                  SET qualified = result
                                                does NOT touch days_passed)
                                                        │
                                                        ▼
                                               UI reads displayProgress()
                                               = days_passed + todayQualified
                                               (live progress bar updates)


                        MIDNIGHT (00:01 local time)
                                    │
                                    ▼
                           midnightAudit()
                           for each in_progress challenge:
                             read challenge_daily_progress.qualified
                             apply to days_passed:
                               +1 if qualified
                               reset if consecutive + not qualified
                               no change if non-consecutive + not qualified
                             if days_passed >= required_days → markComplete()
                             if deadline passed → markFailed()
                                    │
                          ┌─────────┴──────────┐
                          ▼                    ▼
                   markComplete()          markFailed()
                   - decay XP              - status = 'failed'
                   - cooldown              - no XP
                   - INSERT completion     - immediate retry
                   - award XP (uncapped)
                   - evaluateBadges()      ← badge engine
                   - push notification
                   - celebration anim
```

---

## Part 2 — Badge Engine

---

### 2.1 Responsibility Boundary

The badge engine's only job is to check whether a user has become eligible for a badge and, if so, award it exactly once. It is entirely event-driven — it never polls or schedules. Every evaluation is triggered by a specific, named event in the system.

The badge engine has one public function: `evaluateBadges(userId, eventType, eventContext)`. Everything else is internal.

**Design invariants:**
1. **Idempotent.** A badge can never be awarded twice. The first check in every evaluation is "does this badge already exist in `user_badges`?" If yes, return immediately.
2. **Atomic.** The eligibility check and the insert happen in the same database transaction. No race condition can award a badge twice.
3. **Synchronous.** Badge evaluation runs in the same process as the triggering event. It is not queued or deferred. If the evaluation fails (DB error), the triggering event is not rolled back — badge loss is acceptable; data corruption is not.
4. **Side-effect-isolated.** The badge engine writes to `user_badges`. It then triggers notifications and animations. It does not write to any other table.

---

### 2.2 Schema

```sql
badges {
  id           UUID PRIMARY KEY,
  name         TEXT NOT NULL,        -- e.g. 'week_warrior', 'road_to_green_bronze'
  display_name TEXT NOT NULL,        -- e.g. 'Week Warrior 🔥'
  type         TEXT NOT NULL,        -- streak | category | level | quiz | special
  category     TEXT,                 -- transport | food | energy | nature | null
  tier         TEXT,                 -- bronze | silver | gold | null
}

user_badges {
  id          UUID PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id),
  badge_id    UUID NOT NULL REFERENCES badges(id),
  earned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, badge_id)          -- database-enforced idempotency
}
```

The `UNIQUE(user_id, badge_id)` constraint is the hard guarantee of idempotency. Even if the application-level check fails, the database will reject a duplicate insert with a unique constraint violation — which the engine catches and silently ignores.

---

### 2.3 Event Taxonomy — What Triggers What

The badge engine is called from six distinct places in the system. Each call passes a specific `eventType` that tells the engine which badges to evaluate. The engine does not evaluate all badges on every event — only those relevant to the triggering event.

| Event Type | Triggered By | Badges Evaluated |
|---|---|---|
| `LOG_SUBMITTED` | `awardDailyXP()` after any log | `eco_newcomer`, all streak badges |
| `CHALLENGE_COMPLETED` | `markComplete()` | Category badges (bronze/silver/gold), `all_rounder` |
| `QUIZ_PERFECT` | Quiz submission handler | `quiz_whiz` |
| `STREAK_FREEZE_CONSUMED` | `midnightAudit()` when freeze fires | `streak_saver` |
| `LEVEL_UP` | XP update → level recompute | `carbon_neutral` (Level 10 only) |
| `LEADERBOARD_SEASON_END` | Monthly reset job | `leaderboard_leader` |

---

### 2.4 The Public Function: `evaluateBadges(userId, eventType, eventContext)`

```
FUNCTION evaluateBadges(userId, eventType, eventContext):

  Switch eventType:

    Case 'LOG_SUBMITTED':
      checkEcoNewcomer(userId)
      checkStreakBadges(userId, eventContext.streak_days)

    Case 'CHALLENGE_COMPLETED':
      checkCategoryBadge(userId, eventContext.category)
      checkAllRounder(userId)

    Case 'QUIZ_PERFECT':
      checkQuizWhiz(userId)

    Case 'STREAK_FREEZE_CONSUMED':
      checkStreakSaver(userId)

    Case 'LEVEL_UP':
      If eventContext.newLevel == 10:
        checkCarbonNeutral(userId)

    Case 'LEADERBOARD_SEASON_END':
      checkLeaderboardLeader(userId, eventContext.rank)

    Default:
      Log warning: unrecognised eventType. Do nothing.
```

---

### 2.5 Badge Checkers — Full Detail

Each checker follows the same pattern:

1. Check if badge already awarded (idempotency guard).
2. Query the eligibility condition.
3. If eligible: insert into `user_badges`, trigger notification and animation.

---

#### `checkEcoNewcomer(userId)`

```
FUNCTION checkEcoNewcomer(userId):

  ── Idempotency guard ──────────────────────────────────────────────────────────
  If EXISTS(user_badges WHERE user_id = userId AND badge_id = 'eco_newcomer'):
    Return   -- already awarded; nothing to do

  ── Eligibility: first log ever ───────────────────────────────────────────────
  -- This function is called after LOG_SUBMITTED.
  -- If it's called, at least one log exists. But we need to confirm it's the FIRST.
  logCount = SELECT COUNT(*) FROM daily_logs WHERE user_id = userId
  If logCount == 1:
    awardBadge(userId, 'eco_newcomer')

  -- logCount > 1 means user has logged before; do nothing.
```

*Why check count instead of trusting the caller?* Because the caller (`awardDailyXP`) fires on every log update, including when the user adds more categories to an existing log. The same log date is updated in place; it's not a new row. `COUNT(daily_logs)` counts distinct log dates, so if the user updates today's log five times, the count remains 1 on the first date and we correctly award the badge only then.

---

#### `checkStreakBadges(userId, streakDays)`

```
FUNCTION checkStreakBadges(userId, streakDays):

  -- Streak badge milestones and their badge IDs
  MILESTONES = [
    { days: 7,   badgeId: 'week_warrior' },
    { days: 14,  badgeId: 'fortnight_fighter' },
    { days: 30,  badgeId: 'monthly_maven' },
    { days: 60,  badgeId: 'eco_consistent' },
    { days: 100, badgeId: 'century_eco' },
  ]

  For each milestone in MILESTONES:

    -- Only evaluate the milestone the current streak just reached.
    -- If streakDays is 32, we only check the 30-day badge.
    -- The 7 and 14-day badges were already checked when streakDays was 7 and 14.
    -- Idempotency guard handles the case where we re-check them anyway.
    If streakDays != milestone.days: Continue

    If EXISTS(user_badges WHERE user_id = userId AND badge_id = milestone.badgeId):
      Continue   -- idempotency guard; already awarded

    -- Streak days match the milestone and badge not yet held: award
    awardBadge(userId, milestone.badgeId)

    -- Milestone XP bonus (outside the badge engine proper; triggered here for co-location)
    awardMilestoneXP(userId, milestone.days)
```

*Why check `streakDays == milestone.days` rather than `>= milestone.days`?* Because `>=` would trigger on every log after the milestone is reached — and the idempotency guard would silently swallow the re-check. The `==` check means we only run the idempotency insert once, at the exact milestone. This is slightly more efficient. Either works correctly; `==` makes the intent explicit.

*What if a user's streak jumps over a milestone?* Theoretically impossible — the streak increments by exactly 1 per day. A streak cannot go from 6 to 8 without passing through 7. The only risk is if the streak counter was manually corrected in the database, which should never happen in production.

---

#### `checkCategoryBadge(userId, category)`

This is the most complex badge checker. Each category has three badge tiers (Bronze, Silver, Gold) at different completion thresholds. Nature uses adjusted thresholds (1/2/3) because it has only one challenge in v1.

```
FUNCTION checkCategoryBadge(userId, category):

  ── Thresholds per category ────────────────────────────────────────────────────
  THRESHOLDS = {
    transport: { bronze: 3, silver: 7,  gold: 12 },
    food:      { bronze: 3, silver: 7,  gold: 12 },
    energy:    { bronze: 3, silver: 7,  gold: 12 },
    nature:    { bronze: 1, silver: 2,  gold: 3  },   -- adjusted: only 1 challenge in v1
  }

  ── Badge IDs per category and tier ───────────────────────────────────────────
  BADGE_IDS = {
    transport: { bronze: 'road_to_green_bronze', silver: 'road_to_green_silver', gold: 'road_to_green_gold' },
    food:      { bronze: 'conscious_plate_bronze', ... },
    energy:    { bronze: 'power_saver_bronze', ... },
    nature:    { bronze: 'nature_keeper_bronze', ... },
  }

  ── Count total completions in this category ──────────────────────────────────
  -- Count ALL completions, not just unique challenges.
  -- Repeating "No Car Day" 3 times counts as 3 completions toward Transport Bronze.
  completionCount = SELECT COUNT(*) FROM challenge_completions cc
                    JOIN challenges c ON cc.challenge_id = c.id
                    WHERE cc.user_id = userId AND c.category = category

  thresholds = THRESHOLDS[category]
  badgeIds   = BADGE_IDS[category]

  ── Check each tier in descending order ───────────────────────────────────────
  -- Check Gold first. If the user just earned Gold, they already have Bronze and Silver.
  -- The idempotency guard handles previously-awarded lower tiers.

  If completionCount >= thresholds.gold:
    awardBadge(userId, badgeIds.gold)    -- idempotency guard inside awardBadge()
    awardBadge(userId, badgeIds.silver)  -- ensure lower tiers are awarded too
    awardBadge(userId, badgeIds.bronze)

  Else If completionCount >= thresholds.silver:
    awardBadge(userId, badgeIds.silver)
    awardBadge(userId, badgeIds.bronze)

  Else If completionCount >= thresholds.bronze:
    awardBadge(userId, badgeIds.bronze)
```

*Why award lower tiers explicitly when a higher tier is reached?* Consider a user who completes their 7th transport challenge and skips directly from no badge to Silver. They should also hold Bronze. Checking all lower tiers and using the idempotency guard ensures the full set is consistent regardless of how the user progressed.

*Why count ALL completions including repeats?* Repeating a challenge represents genuine repeated eco-behaviour. A user who completes "No Car Day" seven times has made seven individual car-free commitments — rewarding them with Transport Silver is appropriate. This is consistent with the XP decay design: repeat completions are worth less XP but still count toward badge progress.

---

#### `checkAllRounder(userId)`

```
FUNCTION checkAllRounder(userId):

  If EXISTS(user_badges WHERE user_id = userId AND badge_id = 'all_rounder'):
    Return   -- idempotency guard

  ── Determine currently active categories ─────────────────────────────────────
  -- "Active categories" = categories that have at least one active challenge in v1.
  -- This is what a user must cover to earn All-Rounder.
  -- When v1.2 adds Lifestyle challenges, this set grows.
  -- Users who earned All-Rounder before v1.2 keep it.
  activeCategories = SELECT DISTINCT category FROM challenges WHERE is_active = true
  -- In v1: ['transport', 'food', 'energy', 'nature']

  ── Count distinct categories the user has completed at least one challenge in ─
  completedCategories = SELECT DISTINCT c.category
                        FROM challenge_completions cc
                        JOIN challenges c ON cc.challenge_id = c.id
                        WHERE cc.user_id = userId
                          AND c.is_active = true

  ── Check if all active categories are covered ────────────────────────────────
  -- Every category in activeCategories must appear in completedCategories.
  For each cat in activeCategories:
    If cat NOT IN completedCategories: Return   -- missing at least one; not eligible

  awardBadge(userId, 'all_rounder')
```

*Versioning note:* when `challenges` gets new rows with `category = 'lifestyle'` in v1.2, `activeCategories` will include `'lifestyle'`. From that point, new All-Rounder earners must also complete a Lifestyle challenge. Existing holders are protected by the idempotency guard — their badge is already in `user_badges` and the check returns early.

---

#### `checkQuizWhiz(userId)`

```
FUNCTION checkQuizWhiz(userId):

  If EXISTS(user_badges WHERE user_id = userId AND badge_id = 'quiz_whiz'):
    Return

  perfectScoreCount = SELECT COUNT(*) FROM quiz_sessions
                      WHERE user_id = userId AND score = 10

  If perfectScoreCount >= 5:
    awardBadge(userId, 'quiz_whiz')
```

*Simple. Called only when `eventType == 'QUIZ_PERFECT'`, meaning the quiz just submitted had a perfect score. The count will be at least 1 at time of call. At exactly 5, the badge fires.*

---

#### `checkStreakSaver(userId)`

```
FUNCTION checkStreakSaver(userId):

  -- One-time badge: first use of Streak Freeze ever.
  If EXISTS(user_badges WHERE user_id = userId AND badge_id = 'streak_saver'):
    Return

  -- Called from midnightAudit() immediately after consuming the freeze.
  -- If we reach here, the freeze was just consumed for the first time.
  awardBadge(userId, 'streak_saver')
```

---

#### `checkCarbonNeutral(userId)`

```
FUNCTION checkCarbonNeutral(userId):

  -- Called only when newLevel == 10 from a LEVEL_UP event.
  -- The level check is done by the caller before calling evaluateBadges().
  If EXISTS(user_badges WHERE user_id = userId AND badge_id = 'carbon_neutral'):
    Return

  awardBadge(userId, 'carbon_neutral')
```

---

#### `checkLeaderboardLeader(userId, rank)`

```
FUNCTION checkLeaderboardLeader(userId, rank):

  -- Called from the monthly leaderboard reset job for the #1 finisher.
  -- The rank check is done by the caller; this function only receives rank = 1.
  If rank != 1: Return   -- defensive guard

  -- Note: unlike other badges, Leaderboard Leader CAN be awarded multiple times
  -- in the sense that it represents a monthly title. But the badge in user_badges
  -- is a permanent presence — the user holds it permanently once earned.
  -- The monthly crown flair on their profile is a separate UI state, not a badge.
  If EXISTS(user_badges WHERE user_id = userId AND badge_id = 'leaderboard_leader'):
    Return   -- already a permanent holder; no re-insert needed

  awardBadge(userId, 'leaderboard_leader')
```

*The Leaderboard Leader badge is permanent.* If a user wins the leaderboard in March, they hold the badge permanently. If they win again in April, the idempotency guard prevents a second insert. The monthly crown flair (visible on their profile during the following month) is a separate UI field, not a badge record.

---

### 2.6 The Core Award Function: `awardBadge(userId, badgeId)`

Every checker calls this. It is the single point where a badge insert happens.

```
FUNCTION awardBadge(userId, badgeId):

  ── Idempotency: check before insert ──────────────────────────────────────────
  -- Application-level check for performance (avoids unnecessary insert attempt)
  If EXISTS(user_badges WHERE user_id = userId AND badge_id = badgeId):
    Return

  ── Atomic insert ─────────────────────────────────────────────────────────────
  BEGIN TRANSACTION

    INSERT INTO user_badges (user_id, badge_id, earned_at)
      VALUES (userId, badgeId, NOW())
    ON CONFLICT (user_id, badge_id) DO NOTHING
    -- ON CONFLICT handles the race condition where two concurrent calls
    -- both pass the application-level check above before either inserts.
    -- The second insert silently does nothing rather than throwing an error.

  COMMIT

  ── If insert succeeded (not a conflict) ──────────────────────────────────────
  If rowsAffected > 0:
    badge = badges[badgeId]
    triggerPushNotification('badge_earned', userId, { badgeName: badge.display_name })
    triggerCelebrationAnimation(userId, badgeId)
    -- Log for analytics
    logEvent('badge_awarded', { userId, badgeId, earnedAt: NOW() })
```

*Why `ON CONFLICT DO NOTHING` in addition to the application-level check?* Two concurrent requests (e.g. two log updates arriving milliseconds apart) can both pass the `EXISTS` check before either one inserts. Without `ON CONFLICT`, the second insert would throw a unique constraint error. `ON CONFLICT DO NOTHING` makes the insert idempotent at the database level. The `rowsAffected > 0` check then ensures notifications only fire for the one request that actually performed the insert.

---

### 2.7 Badge Engine Data Flow

```
ANY LOG SUBMITTED
        │
        ▼
awardDailyXP()
        │
        ▼
evaluateBadges(userId, 'LOG_SUBMITTED', { streak_days })
        ├── checkEcoNewcomer(userId)
        └── checkStreakBadges(userId, streak_days)
                │
                └── If milestone reached:
                    awardBadge(userId, badgeId)
                        ├── INSERT user_badges (ON CONFLICT DO NOTHING)
                        ├── triggerPushNotification()
                        └── triggerCelebrationAnimation()


CHALLENGE COMPLETED (from midnightAudit → markComplete)
        │
        ▼
evaluateBadges(userId, 'CHALLENGE_COMPLETED', { category })
        ├── checkCategoryBadge(userId, category)
        │       │
        │       └── Award bronze/silver/gold as appropriate
        └── checkAllRounder(userId)
                │
                └── Award if all categories covered


QUIZ PERFECT SCORE
        │
        ▼
evaluateBadges(userId, 'QUIZ_PERFECT', {})
        └── checkQuizWhiz(userId)


STREAK FREEZE CONSUMED (from midnightAudit)
        │
        ▼
evaluateBadges(userId, 'STREAK_FREEZE_CONSUMED', {})
        └── checkStreakSaver(userId)


XP UPDATE → LEVEL INCREASES TO 10
        │
        ▼
evaluateBadges(userId, 'LEVEL_UP', { newLevel: 10 })
        └── checkCarbonNeutral(userId)


MONTHLY LEADERBOARD RESET JOB — RANK #1 USER
        │
        ▼
evaluateBadges(userId, 'LEADERBOARD_SEASON_END', { rank: 1 })
        └── checkLeaderboardLeader(userId, rank)
```

---

### 2.8 Concurrency and Transaction Isolation

Both engines operate in environments where multiple requests may arrive for the same user simultaneously (e.g. a log update and a quiz submission at the same millisecond). The following rules ensure correctness:

**Challenge engine:** `evaluateChallengesForUser()` and `midnightAudit()` both acquire `SELECT FOR UPDATE` on `user_challenges` rows for the target user. Only one can hold the lock at a time. The other waits. This prevents both:
- Double-increment of `days_passed`.
- A log evaluation overwriting an audit result.

**Badge engine:** `awardBadge()` uses `ON CONFLICT DO NOTHING` at the database level. Two concurrent calls to `awardBadge(userId, 'week_warrior')` will result in one insert and one silent no-op. The `rowsAffected > 0` check ensures only one notification fires.

**Transaction scope:** each call to `evaluateChallengesForUser()` or `midnightAudit()` should run in a single database transaction. If any step fails, the whole operation rolls back. This prevents partial states where, for example, `days_passed` is incremented but `markComplete()` fails.

---

### 2.9 Known Limitations and Future Considerations

**Challenge evaluation is O(N × M) per log submission**, where N = users who submitted a log and M = their active challenge count (max 4). At 10,000 DAU with average 2 active challenges, this is 20,000 evaluations per day, each involving a DB read and upsert. Acceptable for v1. At 100,000 DAU, consider batching evaluations into an async queue.

**The midnight audit is a heavy batch job** if run per-user sequentially. At scale, process users in parallel batches, grouped by timezone offset, to stay within the 00:01–00:10 window. Distribute load using a job queue (e.g. Supabase Edge Functions triggered by `pg_cron` with parallel workers).

**Badge evaluation does not award XP.** Badges are intrinsic rewards. Streak milestone XP is awarded separately by `awardMilestoneXP()`, called alongside `checkStreakBadges()` but not inside the badge engine itself. This keeps the badge engine's responsibility boundary clean.

**The `challenge_daily_progress` table grows linearly** with active users × active challenges × days. Old records (older than the longest challenge window, currently 100 days) can be archived or deleted safely — the midnight audit only ever reads records for `auditDate`, which is always today.
