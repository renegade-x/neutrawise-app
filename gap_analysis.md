# NeutraWise Implementation Plan — Gap Analysis & Security Review

**Date:** May 2026  
**Reviewer:** Architecture & Requirements Team  
**Decision:** Riverpod + Direct Client-Side OFF API Calling

---

## Executive Summary

The proposed implementation plan is **solid and workable**, but has **11 critical gaps** and **security/scalability concerns** that must be addressed before development begins. This document identifies each gap, rates severity, and provides solutions.

**Overall Assessment:** ✅ **Approve with modifications** (see §5 for enhanced plan)

---

## 1. Critical Gaps Identified

### 1.1 CRITICAL — Missing Offline Sync Strategy

**Gap:** Phase 3 mentions "Hive/SharedPreferences for offline support (caching the last 7 days of logs)" but provides no specification of the sync protocol.

**Risk Level:** 🔴 CRITICAL  
**Impact:** Data loss on app crash; duplicate entries on reconnect; leaderboard corruption if XP syncs twice.

**Problem:**
- What happens if user logs activity offline, app crashes, comes back online? How do we deduplicate?
- Hive has no built-in conflict resolution. If two logs exist for the same date, which wins?
- Leaderboard XP could increment twice if daily_logs insert fails after XP is updated on users table.

**Solution (See §5.1):**
- Implement **Optimistic UI + Event Sourcing pattern**
- Local logs get UUID + timestamp before insert
- On sync: use `upsert` (INSERT ... ON CONFLICT ... DO UPDATE) by `(user_id, date)` to prevent duplicates
- XP is computed only on successful Supabase insert (not on local write)
- Implement `SyncManager` Riverpod provider to orchestrate queued operations

---

### 1.2 CRITICAL — CO₂ Calculation Engine Not Fully Specified

**Gap:** Plan says "Implement CO₂ Calculation Engine strictly following Algorithm Spec v1.0" but no Dart implementation roadmap.

**Risk Level:** 🔴 CRITICAL  
**Impact:** Discrepancies between spec and code; emission factors hardcoded in multiple places; maintenance nightmare.

**Problem:**
- No guidance on how to structure `emissionFactors.dart` (module layout, version tracking)
- No mention of `mapOFFCategoryToFactorKey()` being a single shared function (could be duplicated)
- Algorithm Spec defines emission factors as constants, but how do we version/update them?
- No Dart class structure for `DailyResult`, `UserProfile`, `TransportEntry`, `FoodEntry`, `EnergyLog`

**Solution (See §5.2):**
- Create `lib/domain/models/` with strict TypeScript-like typedefs
- `emissionFactors.dart` as a single source of truth (no constants in multiple files)
- `co2_calculator.dart` with pure functions: `processSignUpProfile()`, `processDailyLog()`, `estimateCO2ForServing()`
- Version tracking: store `emissionFactorVersion` in every `DailyResult`
- Unit test suite covering all Algorithm Spec edge cases (EV, solar, heating, food unit conversions)

---

### 1.3 CRITICAL — Push Notification Implementation Missing

**Gap:** Phase 5 mentions "Setup OneSignal and Supabase Edge Functions" but no technical spec for integration.

**Risk Level:** 🔴 CRITICAL  
**Impact:** Push notifications won't work; users miss daily reminders and streak warnings; engagement drops.

**Problem:**
- No Edge Function code provided (only Appendix A.3 shows pseudocode)
- No mention of how to link Supabase auth.users.id to OneSignal external_user_id
- No specification of the notification payload structure (which fields map to Flutter handlers)
- `pg_cron` setup steps missing (install extension, schedule queries)
- No clarification on timezone handling for 8 PM / 10:30 PM reminders

**Solution (See §5.3):**
- Provide production-ready Edge Function code (TypeScript)
- Define Flutter notification handler architecture (onMessageHandler, onNotificationTapped)
- Create database trigger for realtime events (streaks, badges, levels)
- Implement timezone-aware cron queries using `AT TIME ZONE` in PostgreSQL
- Add Flutter integration tests for notification receipt

---

### 1.4 CRITICAL — Leaderboard Realtime Sync Not Designed

**Gap:** Phase 4 says "realtime Supabase subscriptions for leaderboard" but no conflict resolution or query strategy.

**Risk Level:** 🔴 CRITICAL  
**Impact:** Leaderboard shows stale ranks; ties not handled; competing rank updates from multiple devices.

**Problem:**
- `leaderboard_rankings` table is a materialized view that updates hourly. Realtime subscriptions won't fire on the hour—they fire on immediate inserts.
- If user logs activity on Device A and Device B simultaneously, which XP counts?
- Rank calculation is complex (ties, global vs. city vs. weekly). Realtime updates could break ordering.
- No mention of `ROW_NUMBER() OVER (ORDER BY xp DESC)` being refreshed on every XP change.

**Solution (See §5.4):**
- Rank is **computed on-demand** from `users` table XP, not cached in leaderboard_rankings
- `leaderboard_rankings` is a **read-only reporting table** updated via scheduled job (hourly)
- Flutter UI subscribes to `users(xp)` changes for current user, queries leaderboard on-demand
- Monthly rank rewards are written to a separate `leaderboard_rewards` table after period ends

---

### 1.5 WARNING — No Data Validation Layer

**Gap:** Plan jumps from UI → Riverpod → Supabase. No mention of input validation, sanitization, or RLS policies.

**Risk Level:** 🟡 WARNING → 🔴 CRITICAL (security)  
**Impact:** SQL injection; unauthorized data access; malformed data in database.

**Problem:**
- No Dart validation layer for forms (Profile Setup, Activity Log)
- No Supabase Row Level Security (RLS) policies defined
- No mention of checking user permissions before update operations
- Transport distance input: what's the max? (1,000 km/day is suspicious)
- Food serving size: can user input 0g or negative values?

**Solution (See §5.5):**
- Implement `lib/domain/validators/` with strict validation functions
- Enable RLS on all user-specific tables: `users`, `daily_logs`, `badges`, `user_challenges`
- Create comprehensive RLS policies (see schema section below)
- Add form validation in Riverpod providers before submission
- Server-side validation in Supabase Edge Functions (never trust client)

---

### 1.6 WARNING — Authentication State Management Underspecified

**Gap:** Phase 2 mentions "Supabase Auth" but no guidance on managing session state, token refresh, or sign-out behavior.

**Risk Level:** 🟡 WARNING → 🟠 HIGH (security)  
**Impact:** Session hijacking; users remain logged in after sign-out; tokens expire without refresh.

**Problem:**
- No mention of token refresh strategy
- No spec for what happens when user is on Insights Screen and session expires
- No logout flow: does app close, redirect to login, or stay on current screen with frozen UI?
- No mention of biometric auth (iOS Face ID, Android fingerprint) for fast re-entry

**Solution (See §5.6):**
- Riverpod `AuthProvider` with Supabase session state
- Automatic token refresh via `onAuthStateChange` listener
- Global nav redirect: if `sessionExpired`, push to LoginScreen
- Optional biometric fallback (LocalAuthentication plugin)

---

### 1.7 WARNING — No Offline-First Conflict Resolution

**Gap:** Offline sync section only says "sync upon reconnection" with zero details.

**Risk Level:** 🟡 WARNING → 🔴 CRITICAL (data integrity)  
**Impact:** Duplicate logs; lost data; incorrect CO₂ totals; leaderboard corruption.

**Problem:**
- What if daily_logs insert succeeds but XP update fails? Partial state.
- What if user has two devices with conflicting logs for the same date?
- What if network is spotty (3G → WiFi → offline)? Retry strategy?
- Hive writes are local-only—no built-in merge conflict resolution.

**Solution (See §5.7):**
- Last-write-wins with **server timestamp** as truth (not client clock)
- Implement queue of pending operations with retry logic (exponential backoff)
- `DailyLog` has `client_timestamp` and `server_timestamp` for debugging
- Upsert pattern for daily_logs: `ON CONFLICT (user_id, date) DO UPDATE`

---

### 1.8 WARNING — Gamification Engine Logic Scattered

**Gap:** Phase 4 says "Implement Gamification Engine" but Algorithm Spec defines XP, levels, badges, streaks as separate subsystems.

**Risk Level:** 🟡 WARNING  
**Impact:** Business logic fragmented across screens; hard to test; difficult to modify rules.

**Problem:**
- XP calculation involves streak multipliers, performance bonus, level multiplier, and daily cap
- Badge triggers depend on challenge completion count, streak milestones, and level thresholds
- No mention of a **GamificationService** or **RulesEngine** that centralizes this logic
- Tests would need to mock entire Riverpod tree instead of testing pure functions

**Solution (See §5.8):**
- Create `lib/domain/gamification/` with pure Dart classes:
  - `XpCalculator`: handles formulas, multipliers, caps
  - `LevelProgressCalculator`: maps XP → level, handles thresholds
  - `BadgeEvaluator`: checks trigger conditions
  - `StreakManager`: increment, freeze, reset logic
- All logic **pure functions**, zero side effects
- Comprehensive unit test suite for every rule in Gamification Spec

---

### 1.9 WARNING — No Error Handling Strategy

**Gap:** Plan has no mention of error handling, retry logic, or user-facing error messages.

**Risk Level:** 🟡 WARNING  
**Impact:** Silent failures; app crashes; users confused about what went wrong.

**Problem:**
- What if Supabase is down? Does app hang or show error?
- What if OFF API returns 429 (rate limit)? Retry? How many times?
- What if profile setup fails partway through? Can user recover or start over?
- No mention of Firebase Crashlytics or equivalent monitoring

**Solution (See §5.9):**
- Implement `ResultType<T>` (Success / Failure / Retry) for all async operations
- Riverpod providers with loading/error states
- Exponential backoff retry for network calls (max 3 attempts)
- User-friendly error UI (Snackbar, Dialog) with action buttons
- Optional: integrate Sentry for error tracking (v1.1+)

---

### 1.10 WARNING — Testing Strategy Minimal

**Gap:** Verification section mentions "Unit tests" and "Widget tests" but no test coverage targets or mock strategy.

**Risk Level:** 🟡 WARNING  
**Impact:** Regressions in CO₂ calculations; gamification bugs slip to production; leaderboard corruption undetected.

**Problem:**
- No mention of test coverage targets (e.g., CO₂ engine @ 100%, gamification @ 95%)
- No mock strategy for Supabase (mockito? fake_cloud_firestore? custom mocks?)
- No mention of golden tests for UI regressions
- No integration test suite (end-to-end user flows)

**Solution (See §5.10):**
- **Target coverage:**
  - CO₂ Calculation Engine: **100%** (critical business logic)
  - Gamification Engine: **95%+** (complex rules)
  - UI layer: **Widget tests for critical paths** (login, log activity, leaderboard)
  - Integration tests: **2–3 critical user flows** (onboard → log → level up)
- Use `mocktail` for Supabase mocks
- Use `golden_toolkit` for UI regression tests
- GitHub Actions CI/CD: run tests on every PR

---

### 1.11 NOTE — Project Structure Not Defined

**Gap:** "Set up Riverpod, routing (go_router), and basic folder structure (lib/ui, lib/data, lib/domain)" is mentioned but no detailed folder tree.

**Risk Level:** 🟢 NOTE  
**Impact:** Inconsistent file organization; hard to find code; on-boarding difficult for new team members.

**Problem:**
- Which folder holds `emissionFactors.dart`? (`lib/data/` or `lib/domain/`?)
- How are Riverpod providers organized? (one provider per file? grouped by feature?)
- Where do Edge Function TypeScript files live? (separate repo? `supabase/functions/`?)
- Where are constants (level thresholds, emission factors, API endpoints) stored?

**Solution (See §5.11):**
- Detailed folder structure with clear ownership boundaries
- Feature-based organization: `lib/features/{auth,dashboard,gamification,insights}/`
- Centralized constants: `lib/config/constants.dart`
- Separate `supabase/` directory (or git submodule) for Edge Functions and migrations

---

## 2. Security Review

### 2.1 Authentication & Session Management

**✅ Supabase Auth is solid** (Email + OAuth providers)  
**⚠️ Missing:** Session timeout policy, token refresh, biometric auth option

### 2.2 Data Access Control

**❌ CRITICAL:** No Row Level Security (RLS) policies defined

Current state: If someone obtains a valid Supabase auth token, they can query any user's data.

**Required RLS policies:**
```sql
-- users table: user can only see their own record
CREATE POLICY "Users see own record" ON users
  FOR SELECT USING (auth.uid() = id);

-- daily_logs: user can only see/edit their own logs
CREATE POLICY "Users see own logs" ON daily_logs
  FOR ALL USING (auth.uid() = user_id);

-- Similar policies for badges, challenges, streaks, etc.
```

### 2.3 API Rate Limiting

**⚠️ Missing:** No rate limit on activity logging, OFF API calls, or leaderboard queries

**Required:**
- Log activity: max 10 logs per day per user (prevent spam)
- OFF API: implement client-side cache + rate limiting (OFF has 1 req/second limit)
- Leaderboard queries: debounce realtime subscriptions (no update every millisecond)

### 2.4 Input Validation

**❌ CRITICAL:** No validation of user inputs

**Examples of attacks:**
- User submits `avgDailyKm = 99999` → baseline is wildly wrong
- User submits `distance = -100` in activity log → negative CO₂
- Food serving size: `0` or `999999` grams
- Username: 10,000 characters (DoS)

**Required:**
- Client-side validation (UX)
- Server-side validation in Edge Functions (security)

### 2.5 Sensitive Data

**✅ Passwords:** Supabase Auth handles securely  
**✅ API keys:** OneSignal key stored in Supabase secrets (not in app)  
**⚠️ Missing:** No mention of HTTPS-only, certificate pinning, or data encryption at rest

---

## 3. Scalability Review

### 3.1 Database

**Issue:** `leaderboard_rankings` materialized view updated hourly—works for 100K users, fails at 1M.

**Solution:** Rank is computed on-demand via `ROW_NUMBER()` query (indexed on XP).

### 3.2 Food Search (Open Food Facts)

**Issue:** Direct client-side calling = no caching, no rate limiting, high latency.

**Decision:** Acceptable for v1 (assuming < 10K DAU), but consider backend cache proxy in v1.1.

**Mitigation:**
- Implement local search cache (recent searches)
- Debounce search input (0.5s)
- Fallback to category selector on slow network

### 3.3 Realtime Subscriptions

**Issue:** If 100K users all subscribe to leaderboard, Supabase could be overwhelmed.

**Solution:** 
- Paginate leaderboard (top 100, not all)
- Refresh on-demand, not continuous subscription
- Use incremental updates (only send rank deltas)

---

## 4. Modularity & Maintainability

### 4.1 Strengths ✅

- Clean separation: Presentation / State / Domain / Data
- Riverpod for dependency injection
- `go_router` for navigation
- Feature-based organization (proposed)

### 4.2 Gaps ⚠️

- No mention of shared component library (buttons, cards, modals)
- No design tokens (colors, spacing, fonts) centralized
- No mention of localization (i18n) strategy
- No mention of analytics or crash reporting

---

## 5. Enhanced Implementation Plan (Gaps Resolved)

### 5.1 Offline Sync Strategy (Resolves Gap 1.1)

**Architecture:**

```
┌─────────────────────────────────────────┐
│       Riverpod SyncManager Provider     │
│  (orchestrates all pending operations)  │
└─────────────────────────────────────────┘
            │
    ┌───────┴────────┐
    │                │
    ▼                ▼
 Local Hive      Remote Supabase
 (pending ops)   (source of truth)

DailyLog {
  id: UUID (generated locally)
  user_id: UUID
  date: DATE
  client_timestamp: DateTime (local)
  server_timestamp: DateTime (null until synced)
  transport_entries: JSONB
  ...
  _syncStatus: 'pending' | 'synced' | 'failed'
}
```

**Sync Flow:**

1. **User logs activity offline:**
   - DailyLog created with `_syncStatus = 'pending'`, stored in Hive
   - UI updates optimistically (ring chart, XP bar)
   - Operation queued in `SyncManager`

2. **Network becomes available:**
   - `SyncManager` dequeues operations
   - Calls `supabase.from('daily_logs').upsert(log, onConflict: '(user_id, date)')`
   - On success: `_syncStatus = 'synced'`, remove from Hive
   - On failure (e.g., 409 conflict): `_syncStatus = 'failed'`, show user error

3. **Conflict Resolution:**
   - Upsert uses server timestamp as tiebreaker
   - If local log newer than server: overwrite
   - If server log newer: revert UI to server state

**Implementation:**

```dart
// lib/domain/repositories/sync_manager.dart
class SyncManager {
  Future<void> syncPendingLogs() async {
    final pendingLogs = await _getLocalPendingLogs();
    for (var log in pendingLogs) {
      try {
        await _syncLog(log);
      } catch (e) {
        _markAsFailed(log);
        // Show user snackbar: "Failed to sync. Retry?"
      }
    }
  }

  Future<void> _syncLog(DailyLog log) async {
    final response = await supabase
      .from('daily_logs')
      .upsert(
        log.toJson(),
        onConflict: 'user_id,date',
        returning: ReturningOption.representation,
      )
      .select()
      .single();
    
    // Update local record with server state
    log.serverId = response['id'];
    log.serverTimestamp = DateTime.parse(response['server_timestamp']);
    log.syncStatus = 'synced';
    await _updateLocalLog(log);
  }
}
```

---

### 5.2 CO₂ Calculation Engine (Resolves Gap 1.2)

**File Structure:**

```
lib/domain/
├── models/
│   ├── user_profile.dart (TypeDef)
│   ├── daily_result.dart (TypeDef)
│   ├── transport_entry.dart (TypeDef)
│   ├── food_entry.dart (TypeDef)
│   └── energy_log.dart (TypeDef)
├── co2_engine/
│   ├── emission_factors.dart (single source of truth)
│   ├── co2_calculator.dart (pure functions)
│   ├── transport_calculator.dart
│   ├── food_calculator.dart
│   └── energy_calculator.dart
└── validators/
    ├── transport_validator.dart
    ├── food_validator.dart
    └── energy_validator.dart
```

**Key Module: `emission_factors.dart`**

```dart
// lib/domain/co2_engine/emission_factors.dart

const EMISSION_FACTOR_VERSION = '1.0.0'; // Track versions

const TRANSPORT_FACTORS = {
  'petrol_small': 0.18,
  'petrol_medium': 0.23,
  'petrol_large': 0.28,
  'diesel_small': 0.17,
  'diesel_medium': 0.22,
  'diesel_large': 0.27,
  'hybrid_medium': 0.12,
  // EV is never table-looked-up; computed at runtime
  'bus': 0.089,
  'train': 0.041,
  'metro': 0.035,
  // ... etc
};

const EV_EFFICIENCY_KWH_PER_KM = {
  'small': 0.15,
  'medium': 0.18,
  'large': 0.22,
};

const FOOD_CATEGORY_FACTORS = {
  'beef': 60.0,
  'lamb_mutton': 39.2,
  'pork': 12.3,
  'poultry_chicken': 9.9,
  'fish_wild': 3.0,
  'shrimp_farmed': 26.9,
  'cheese': 21.0,
  'butter': 23.8,
  'milk_dairy': 3.2,
  'eggs': 4.5,
  'tofu': 3.0,
  'legumes_dried': 0.9,
  'nuts_mixed': 2.3,
  'rice_white': 4.0,
  'pasta': 1.9,
  'wheat_bread': 1.6,
  'vegetables_avg': 0.4,
  'fruit_avg': 0.7,
  // ... complete list per Algorithm Spec
};

// VERSION TRACKING
const GRID_INTENSITY_BY_COUNTRY_V1_0 = {
  'PK': 0.45, // Pakistan (guesstimate, 2026)
  'US': 0.38,
  'GB': 0.25,
  'DE': 0.18,
  // ... etc
};

// Helper: single source of truth for category mapping
String mapOFFCategoryToFactorKey(String? offCategory) {
  if (offCategory == null) return 'vegetables_avg';
  final cat = offCategory.toLowerCase();
  
  if (cat.contains('beef') || cat.contains('veal')) return 'beef';
  if (cat.contains('shrimp') || cat.contains('prawn')) return 'shrimp_farmed';
  if (cat.contains('lamb') || cat.contains('mutton')) return 'lamb_mutton';
  // ... per mapping table in Appendix A.1
  
  return 'vegetables_avg'; // safe default
}
```

**Key Module: `co2_calculator.dart`**

```dart
// lib/domain/co2_engine/co2_calculator.dart

class CO2Calculator {
  /// Matches Algorithm Spec §2.3: Sign-Up Processor
  static UserProfile processSignUpProfile(SignUpProfileInput input) {
    // Transport factor derivation
    final transportFactor = _deriveTransportFactor(
      input.primaryTransport,
      input.fuelType,
      input.engineSize,
      input.vehicleAge,
    );
    final dailyTransportCO2 = transportFactor * (input.avgDailyKm ?? 10.0);

    // Energy baseline derivation
    final dailyKwh = input.monthlyKwh != null
      ? input.monthlyKwh! / 30 / input.residents
      : BASE_DAILY_KWH_BY_HOME[input.homeType]! / input.residents;
    
    final effectiveKwh = input.hasSolar ? dailyKwh * 0.75 : dailyKwh;
    final gridIntensity = GRID_INTENSITY_BY_COUNTRY_V1_0[input.country] ?? 0.4;
    final electricityCO2 = effectiveKwh * gridIntensity;
    
    // Heating CO2 (store explicitly, never reverse-engineered)
    final heatingCO2 = _calculateHeatingCO2(
      input.homeType,
      input.heatingType,
      input.residents,
    );
    final dailyEnergyBaselineCO2 = electricityCO2 + heatingCO2;

    // Food baseline
    final dailyFoodBaselineCO2 = FOOD_BASELINES[input.dietaryPreference] ?? 5.5;

    return UserProfile(
      transportFactor: transportFactor,
      dailyTransportCO2: dailyTransportCO2,
      dailyEnergyBaselineKwh: effectiveKwh,
      dailyHeatingBaselineCO2: heatingCO2,
      dailyEnergyBaselineCO2: dailyEnergyBaselineCO2,
      gridIntensity: gridIntensity,
      dailyFoodBaselineCO2: dailyFoodBaselineCO2,
      totalDailyBaselineCO2: dailyTransportCO2 + dailyEnergyBaselineCO2 + dailyFoodBaselineCO2,
      emissionFactorVersion: EMISSION_FACTOR_VERSION,
    );
  }

  /// Matches Algorithm Spec §2.5: Daily Log Processor
  static DailyResult processDailyLog({
    required DailyLog log,
    required UserProfile profile,
    required int streakDays,
  }) {
    final transportCO2 = _calculateTransportCO2(log.transportEntries, profile);
    final foodCO2 = _calculateFoodCO2(log.foodEntries);
    final energyCO2 = _calculateEnergyCO2(log.energyLog, profile);
    
    final totalDailyCO2 = transportCO2 + foodCO2 + energyCO2;
    final baselineCO2 = profile.totalDailyBaselineCO2;
    final co2SavedVsBaseline = baselineCO2 - totalDailyCO2;
    final percentVsBaseline = (co2SavedVsBaseline / baselineCO2) * 100;

    // XP calculation (Gamification Spec §1.2)
    final baseXP = _calculateBaseXP(log);
    final streakMultiplier = _getStreakMultiplier(streakDays);
    final performanceBonus = _calculatePerformanceBonus(
      co2SavedVsBaseline,
      baselineCO2,
    );
    final xpEarned = (baseXP * streakMultiplier).round() + performanceBonus;

    // Equivalences (Algorithm Spec §2.6)
    final treeDaysAbsorbed = totalDailyCO2 / 0.0603;
    final carKmEquivalent = (co2SavedVsBaseline / 0.18).clamp(0, double.infinity);
    final smartphoneCharges = (co2SavedVsBaseline / 0.008).clamp(0, double.infinity);

    return DailyResult(
      date: log.date,
      transportCO2: transportCO2,
      foodCO2: foodCO2,
      energyCO2: energyCO2,
      totalDailyCO2: totalDailyCO2,
      baselineCO2: baselineCO2,
      co2SavedVsBaseline: co2SavedVsBaseline,
      percentVsBaseline: percentVsBaseline,
      xpEarned: xpEarned,
      equivalences: Equivalences(
        treeDaysAbsorbed: treeDaysAbsorbed,
        carKmEquivalent: carKmEquivalent,
        smartphoneCharges: smartphoneCharges,
      ),
      emissionFactorVersion: EMISSION_FACTOR_VERSION,
    );
  }

  // Helper functions (private, pure, unit-testable)
  static double _deriveTransportFactor(
    String mode,
    String? fuelType,
    String? engineSize,
    String? vehicleAge,
  ) {
    // per Algorithm Spec §2.3 rules 1, 2, 3
    // ...
  }

  static double _calculateTransportCO2(
    List<TransportEntry> entries,
    UserProfile profile,
  ) {
    // per Algorithm Spec §2.5
    // ...
  }

  // etc.
}
```

**Unit Tests:**

```dart
// test/domain/co2_engine/co2_calculator_test.dart

void main() {
  group('CO2Calculator', () {
    group('processSignUpProfile', () {
      test('EV with grid intensity returns correct CO2', () {
        final input = SignUpProfileInput(
          primaryTransport: 'ev',
          engineSize: 'medium',
          country: 'GB',
          // ...
        );
        final profile = CO2Calculator.processSignUpProfile(input);
        
        // EV factor = 0.18 kWh/km * 0.25 kgCO2/kWh = 0.045 kgCO2/km
        expect(profile.transportFactor, closeTo(0.045, 0.001));
      });

      test('Solar panel reduces baseline by 25%', () {
        final withoutSolar = CO2Calculator.processSignUpProfile(
          SignUpProfileInput(hasSolar: false, monthlyKwh: 300),
        );
        final withSolar = CO2Calculator.processSignUpProfile(
          SignUpProfileInput(hasSolar: true, monthlyKwh: 300),
        );
        
        expect(withSolar.dailyEnergyBaselineKwh, 
          closeTo(withoutSolar.dailyEnergyBaselineKwh * 0.75, 0.01));
      });

      test('Heating CO2 stored explicitly, not reverse-engineered', () {
        final profile = CO2Calculator.processSignUpProfile(...);
        expect(profile.dailyHeatingBaselineCO2, isNotNull);
        // Verify it was NOT derived by subtraction
      });
    });

    group('processDailyLog', () {
      test('XP calculation matches Gamification Spec formula', () {
        // Full log (all 3 categories) = 50 XP base
        // Streak 7-29 days = ×1.25 multiplier
        // Performance ≥15% below baseline = +15 XP bonus
        // Expected: (50 * 1.25) + 15 = 77.5 → 77 XP (rounded)
      });

      test('Food unit conversion: gCO₂e/100g stored, kgCO₂e returned', () {
        // co2Per100g = 60 gCO₂e/100g (beef)
        // Serving 150g
        // Expected: (60 / 1000) * (150 / 100) = 0.09 kgCO2e
      });

      test('CO2 saved never negative; equivalences hidden if saving < 0', () {
        // User exceeded baseline
        // carKmEquivalent should be 0, not negative
      });
    });
  });
}
```

---

### 5.3 Push Notification Implementation (Resolves Gap 1.3)

**Edge Function: `schedule_push_notification.ts`**

```typescript
// supabase/functions/schedule_push_notification/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const ONESIGNAL_API_KEY = Deno.env.get("ONESIGNAL_API_KEY")!;
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;

interface PushRequest {
  type: "daily_log_reminder" | "streak_milestone" | "challenge_complete" | "level_up";
  user_id: string;
  data?: Record<string, any>;
  scheduled_time?: string; // ISO 8601 for future sends
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload: PushRequest = await req.json();

    // Get user's notification preferences
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("*")
      .eq("user_id", payload.user_id)
      .single();

    if (!prefs) {
      return new Response(JSON.stringify({ error: "Preferences not found" }), {
        status: 404,
      });
    }

    // Check if notification type is enabled
    const prefKey = `${payload.type}`;
    if (prefKey in prefs && !prefs[prefKey]) {
      console.log(`User ${payload.user_id} has disabled ${payload.type}`);
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    // Build OneSignal payload
    const title = getTitleForType(payload.type);
    const message = getMessageForType(payload.type, payload.data);

    const oneSignalPayload = {
      app_id: ONESIGNAL_APP_ID,
      include_external_user_ids: [payload.user_id],
      headings: { en: title },
      contents: { en: message },
      data: payload.data || {},
      ios_channel_id: "default",
      android_channel_id: "default",
      ttl: 86400, // 24 hours
      ...(payload.scheduled_time && {
        send_after: new Date(payload.scheduled_time).toISOString(),
      }),
    };

    // Send to OneSignal
    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${ONESIGNAL_API_KEY}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify(oneSignalPayload),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error("OneSignal error:", result);
      return new Response(JSON.stringify({ error: result }), {
        status: response.status,
      });
    }

    return new Response(JSON.stringify({ success: true, notification_id: result.id }), {
      status: 200,
    });
  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});

function getTitleForType(type: string): string {
  const titles = {
    daily_log_reminder: "🌿 How was your day?",
    streak_milestone: "🔥 Streak Milestone!",
    challenge_complete: "🎉 Challenge Complete!",
    level_up: "⬆️ Level Up!",
  };
  return titles[type] || "NeutraWise";
}

function getMessageForType(type: string, data?: Record<string, any>): string {
  switch (type) {
    case "daily_log_reminder":
      return "Log your activity and keep your streak alive!";
    case "streak_milestone":
      return `You've reached ${data?.streak_days} days in a row! 🏆`;
    case "challenge_complete":
      return `Challenge "${data?.challenge_name}" complete! +${data?.xp} XP`;
    case "level_up":
      return `You're now Level ${data?.new_level} — ${data?.level_title}! 🌟`;
    default:
      return "Check your progress!";
  }
}
```

**PostgreSQL Trigger: Realtime Push Notifications**

```sql
-- supabase/migrations/[timestamp]_push_notifications.sql

-- Trigger: Send push when user levels up
CREATE OR REPLACE FUNCTION notify_level_up()
RETURNS TRIGGER AS $$
DECLARE
  level_title TEXT;
BEGIN
  IF NEW.level > OLD.level THEN
    SELECT title INTO level_title FROM levels_titles WHERE level_num = NEW.level;
    
    SELECT net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
      payload := json_build_object(
        'type', 'level_up',
        'user_id', NEW.id,
        'data', json_build_object(
          'new_level', NEW.level,
          'level_title', level_title
        )
      )::text,
      headers := json_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.jwt_secret', false)
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_level_up
AFTER UPDATE ON users
FOR EACH ROW
WHEN (NEW.level > OLD.level)
EXECUTE FUNCTION notify_level_up();

-- Trigger: Send push when badge earned
CREATE OR REPLACE FUNCTION notify_badge_earned()
RETURNS TRIGGER AS $$
BEGIN
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
    payload := json_build_object(
      'type', 'badge_earned',
      'user_id', NEW.user_id,
      'data', json_build_object('badge_name', NEW.badge_name)
    )::text,
    headers := json_build_object('Content-Type', 'application/json')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_badge_earned
AFTER INSERT ON badges
FOR EACH ROW
EXECUTE FUNCTION notify_badge_earned();

-- Scheduled push: Daily reminder at 8 PM user's local time
SELECT cron.schedule('daily_log_reminder', '0 20 * * *', $$
  SELECT
    net.http_post(
      url := 'https://your-project.supabase.co/functions/v1/schedule_push_notification',
      payload := json_agg(
        json_build_object(
          'type', 'daily_log_reminder',
          'user_id', u.id
        )
      )::text,
      headers := json_build_object('Content-Type', 'application/json')
    )
  FROM users u
  WHERE u.notifications_enabled = true
    AND NOT EXISTS (
      SELECT 1 FROM daily_logs
      WHERE user_id = u.id AND date = CURRENT_DATE AT TIME ZONE 'UTC'
    )
$$);
```

**Flutter Integration: Notification Handler**

```dart
// lib/services/push_notification_service.dart

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:go_router/go_router.dart';

class PushNotificationService {
  static void initialize(BuildContext context) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(ONESIGNAL_APP_ID);
    
    // Handle notification tap
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      _handleNotificationTap(context, data);
    });
    
    // Handle notification received (foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });
  }

  static void _handleNotificationTap(BuildContext context, Map<String, dynamic>? data) {
    final type = data?['type'] as String?;
    
    switch (type) {
      case 'daily_log_reminder':
      case 'streak_milestone':
        context.push('/dashboard');
        break;
      case 'challenge_complete':
        context.push('/gamification');
        break;
      case 'level_up':
        context.push('/gamification');
        // Show celebratory modal
        _showLevelUpModal(context, data!);
        break;
      default:
        context.push('/dashboard');
    }
  }

  static void _showLevelUpModal(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Level ${data['new_level']} — ${data['level_title']}!'),
        content: const Text('🌟 Congratulations!'),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Awesome!'))],
      ),
    );
  }
}
```

---

### 5.4 Leaderboard Realtime Sync Design (Resolves Gap 1.4)

**Database Schema Update:**

```sql
-- leaderboard_rankings is NO LONGER a materialized view
-- Instead, it's a read-only reporting table updated by scheduled job

CREATE TABLE leaderboard_rankings (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  xp INT NOT NULL,
  level INT NOT NULL,
  global_rank INT,
  city_rank INT,
  weekly_rank INT,
  leaderboard_type VARCHAR NOT NULL, -- 'global', 'city', 'weekly_sprint'
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, leaderboard_type, period_start)
);

-- Hourly refresh job (via pg_cron)
SELECT cron.schedule('refresh_leaderboards_hourly', '0 * * * *', $$
  -- Global leaderboard
  INSERT INTO leaderboard_rankings (user_id, xp, level, global_rank, leaderboard_type, period_start, period_end)
  SELECT 
    u.id,
    u.xp,
    u.level,
    ROW_NUMBER() OVER (ORDER BY u.xp DESC) as global_rank,
    'global',
    CURRENT_DATE,
    CURRENT_DATE
  FROM users u
  ON CONFLICT (user_id, leaderboard_type, period_start) 
  DO UPDATE SET xp = EXCLUDED.xp, level = EXCLUDED.level, global_rank = EXCLUDED.global_rank;
  
  -- City leaderboard
  INSERT INTO leaderboard_rankings (user_id, xp, level, city_rank, leaderboard_type, period_start, period_end)
  SELECT 
    u.id,
    u.xp,
    u.level,
    ROW_NUMBER() OVER (PARTITION BY u.city ORDER BY u.xp DESC) as city_rank,
    'city',
    CURRENT_DATE,
    CURRENT_DATE
  FROM users u
  WHERE u.city IS NOT NULL
  ON CONFLICT (user_id, leaderboard_type, period_start)
  DO UPDATE SET xp = EXCLUDED.xp, level = EXCLUDED.level, city_rank = EXCLUDED.city_rank;
$$);
```

**Flutter Leaderboard Query (On-Demand, not Subscribed):**

```dart
// lib/domain/repositories/leaderboard_repository.dart

class LeaderboardRepository {
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 100}) async {
    final response = await supabase
      .from('leaderboard_rankings')
      .select('*, users:user_id(*)')
      .eq('leaderboard_type', 'global')
      .order('global_rank')
      .limit(limit);
    
    return response
      .map((r) => LeaderboardEntry.fromJson(r))
      .toList();
  }

  Future<LeaderboardEntry?> getUserRank({required String userId}) async {
    final response = await supabase
      .from('leaderboard_rankings')
      .select('*')
      .eq('user_id', userId)
      .eq('leaderboard_type', 'global')
      .single();
    
    return LeaderboardEntry.fromJson(response);
  }
}
```

**Riverpod Provider (Paginated, Cached):**

```dart
// lib/providers/leaderboard_provider.dart

final leaderboardProvider = FutureProvider.family<
  AsyncValue<List<LeaderboardEntry>>,
  String
>((ref, leaderboardType) async {
  final repo = ref.watch(leaderboardRepositoryProvider);
  return repo.getLeaderboard(type: leaderboardType);
});

final userRankProvider = FutureProvider<LeaderboardEntry?>((ref) async {
  final auth = ref.watch(authProvider);
  final repo = ref.watch(leaderboardRepositoryProvider);
  
  if (auth.user == null) return null;
  return repo.getUserRank(userId: auth.user!.id);
});

// Periodic refresh (every 30s, not realtime)
final leaderboardRefreshProvider = FutureProvider((ref) async {
  while (true) {
    await Future.delayed(const Duration(seconds: 30));
    ref.refresh(leaderboardProvider('global'));
  }
});
```

---

### 5.5 Data Validation Layer (Resolves Gap 1.5)

**Client-Side Validators:**

```dart
// lib/domain/validators/input_validators.dart

class InputValidators {
  // Transport validators
  static Result<double> validateDistance(String input) {
    try {
      final km = double.parse(input);
      if (km < 0) return Failure('Distance cannot be negative');
      if (km > 1000) return Failure('Distance exceeds 1000 km (suspicious)');
      return Success(km);
    } catch (e) {
      return Failure('Invalid number');
    }
  }

  // Food validators
  static Result<int> validateServingSize(String input) {
    try {
      final grams = int.parse(input);
      if (grams <= 0) return Failure('Serving must be > 0g');
      if (grams > 5000) return Failure('Serving size too large (max 5000g)');
      return Success(grams);
    } catch (e) {
      return Failure('Invalid number');
    }
  }

  // Energy validators
  static Result<int> validateMonthlyKwh(String input) {
    try {
      final kwh = int.parse(input);
      if (kwh < 0) return Failure('Cannot be negative');
      if (kwh > 10000) return Failure('Unusual value (max 10000 kWh/month)');
      return Success(kwh);
    } catch (e) {
      return Failure('Invalid number');
    }
  }

  // Profile validators
  static Result<int> validateResidents(String input) {
    try {
      final residents = int.parse(input);
      if (residents < 1 || residents > 20) {
        return Failure('Must be between 1–20');
      }
      return Success(residents);
    } catch (e) {
      return Failure('Invalid number');
    }
  }
}
```

**Supabase RLS Policies:**

```sql
-- Enable RLS on all user-specific tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_challenges ENABLE ROW LEVEL SECURITY;

-- users table
CREATE POLICY "Users see only their own record" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own record" ON users
  FOR UPDATE USING (auth.uid() = id);

-- daily_logs table (most restrictive)
CREATE POLICY "Users see only their own logs" ON daily_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own logs" ON daily_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own logs" ON daily_logs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own logs" ON daily_logs
  FOR DELETE USING (auth.uid() = user_id);

-- badges, streaks, challenges: similar policies

-- leaderboard_rankings is readable by anyone (public)
ALTER TABLE leaderboard_rankings DISABLE ROW LEVEL SECURITY;

-- notification_preferences
CREATE POLICY "Users manage their own preferences" ON notification_preferences
  FOR ALL USING (auth.uid() = user_id);
```

**Server-Side Validation in Edge Function:**

```typescript
// supabase/functions/log_activity/index.ts

serve(async (req) => {
  const payload = await req.json();
  
  // Validate input
  const validation = validateActivityInput(payload);
  if (!validation.valid) {
    return new Response(JSON.stringify({ error: validation.errors }), { status: 400 });
  }
  
  // Sanitize and store
  // ...
});

function validateActivityInput(input: any) {
  const errors: string[] = [];
  
  if (!Array.isArray(input.transport_entries)) {
    errors.push('transport_entries must be an array');
  }
  
  for (const entry of input.transport_entries || []) {
    if (typeof entry.distance_km !== 'number') {
      errors.push('distance_km must be a number');
    } else if (entry.distance_km < 0 || entry.distance_km > 1000) {
      errors.push('distance_km must be 0–1000');
    }
  }
  
  return { valid: errors.length === 0, errors };
}
```

---

### 5.6 Authentication & Session Management (Resolves Gap 1.6)

**Riverpod Auth Provider:**

```dart
// lib/providers/auth_provider.dart

final authProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(AuthState.initial()) {
    _initializeSession();
  }

  void _initializeSession() {
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final user = session?.user;
      
      if (user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          loading: false,
        );
        _setupTokenRefresh(session!);
      } else {
        state = AuthState.initial().copyWith(loading: false);
      }
    });
  }

  void _setupTokenRefresh(Session session) {
    // Supabase automatically refreshes tokens before expiry
    // But we can add custom logic here if needed
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      // Navigate to profile setup (handled by router listener)
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(loading: true);
    try {
      await supabase.auth.signOut();
      state = AuthState.initial();
      // Router automatically redirects to login
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }
}

class AuthState {
  final bool isAuthenticated;
  final User? user;
  final bool loading;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    required this.user,
    required this.loading,
    required this.error,
  });

  factory AuthState.initial() => AuthState(
    isAuthenticated: false,
    user: null,
    loading: true,
    error: null,
  );

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    bool? loading,
    String? error,
  }) => AuthState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    user: user ?? this.user,
    loading: loading ?? this.loading,
    error: error,
  );
}
```

**Navigation Router with Auth Guard:**

```dart
// lib/routing/router.dart

final routerProvider = Provider((ref) {
  final authState = ref.watch(authProvider);
  
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // If not authenticated, redirect to onboarding
      if (!authState.isAuthenticated && state.location != '/onboarding') {
        return '/onboarding';
      }
      
      // If authenticated but hasn't completed profile setup, go to setup
      if (authState.isAuthenticated && authState.user != null) {
        // Check if profile is complete (user_profile exists in DB)
        if (!_isProfileSetupComplete(authState.user!)) {
          return '/profile-setup';
        }
      }
      
      return null; // No redirect
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      // ... other routes
    ],
  );
});
```

**Biometric Auth (Optional for v1.1+):**

```dart
// lib/services/biometric_auth.dart

class BiometricAuthService {
  static Future<bool> isBiometricAvailable() async {
    final localAuth = LocalAuthentication();
    return localAuth.canCheckBiometrics || localAuth.deviceSupportsFastStart;
  }

  static Future<bool> authenticate() async {
    try {
      final localAuth = LocalAuthentication();
      return await localAuth.authenticate(
        localizedReason: 'Authenticate to access NeutraWise',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (e) {
      print('Biometric auth error: $e');
      return false;
    }
  }
}
```

---

### 5.7 Offline Sync with Conflict Resolution (Resolves Gap 1.7)

**Detailed Offline Flow:**

```dart
// lib/domain/repositories/sync_repository.dart

class SyncRepository {
  /// Main sync orchestrator
  Future<void> syncOfflineLogs() async {
    final pendingLogs = await _hive.getLocalPendingLogs();
    
    for (var log in pendingLogs) {
      try {
        await _syncSingleLog(log);
      } on NetworkException catch (e) {
        log.syncStatus = 'failed';
        log.syncError = e.message;
        await _hive.updateLocalLog(log);
        // Retry later (handled by global SyncManager)
      }
    }
  }

  /// Sync one log with conflict resolution
  Future<void> _syncSingleLog(DailyLog log) async {
    // Upsert: if log for this (user, date) exists, compare timestamps
    final response = await supabase
      .from('daily_logs')
      .upsert(
        {
          'user_id': log.user_id,
          'date': log.date,
          'transport_entries': log.transportEntries,
          'food_entries': log.foodEntries,
          'energy_deviations': log.energyDeviations,
          'transport_co2': log.transportCO2,
          'food_co2': log.foodCO2,
          'energy_co2': log.energyCO2,
          'total_daily_co2': log.totalDailyCO2,
          'xp_earned': log.xpEarned,
          'client_timestamp': log.clientTimestamp.toIso8601String(),
          // server_timestamp is AUTO-SET to NOW()
        },
        onConflict: 'user_id,date',
      )
      .select()
      .single();

    // Parse server response
    final serverLog = DailyLog.fromJson(response);
    
    // If server version is newer, revert UI to server state
    if (serverLog.serverTimestamp.isAfter(log.clientTimestamp)) {
      log = serverLog;
    }
    
    // Mark as synced and remove from Hive
    log.syncStatus = 'synced';
    log.serverId = serverLog.id;
    await _hive.updateLocalLog(log);
  }
}
```

**SyncManager (Riverpod Provider):**

```dart
// lib/providers/sync_manager_provider.dart

final syncManagerProvider = Provider((ref) {
  return SyncManager(ref);
});

class SyncManager {
  final ProviderRef ref;
  final _syncQueue = <DailyLog>[];
  bool _isSyncing = false;

  SyncManager(this.ref) {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    // Listen for network state changes
    connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.wifi || 
          result == ConnectivityResult.mobile) {
        _syncOfflineQueue();
      }
    });
  }

  /// Add log to sync queue (called when user logs offline)
  void queueLogForSync(DailyLog log) {
    log.syncStatus = 'pending';
    _syncQueue.add(log);
    _syncOfflineQueue(); // Try sync immediately if online
  }

  /// Sync all pending logs
  Future<void> _syncOfflineQueue() async {
    if (_isSyncing || _syncQueue.isEmpty) return;
    
    _isSyncing = true;
    try {
      for (var log in _syncQueue.toList()) {
        try {
          await ref.read(syncRepositoryProvider).syncSingleLog(log);
          _syncQueue.remove(log);
        } catch (e) {
          // Leave in queue for retry
          log.syncError = e.toString();
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  bool get hasPendingSync => _syncQueue.isNotEmpty;
  int get pendingCount => _syncQueue.length;
}
```

**UI Feedback:**

```dart
// Show banner when offline
class OfflineBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncManager = ref.watch(syncManagerProvider);
    
    if (syncManager.hasPendingSync) {
      return Container(
        color: Colors.orange,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Syncing ${syncManager.pendingCount} log(s)...'),
            ),
            TextButton(
              onPressed: () => syncManager.syncOfflineQueue(),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
```

---

### 5.8 Gamification Engine (Resolves Gap 1.8)

**Centralized Rules Engine:**

```dart
// lib/domain/gamification/gamification_engine.dart

class GamificationEngine {
  /// Calculate XP earned for a daily log
  static int calculateXp({
    required bool isFullLog,
    required int currentStreak,
    required double co2SavedPercent,
    required int dailyXpCap,
  }) {
    // Base XP
    int baseXp = isFullLog ? 50 : 20;
    
    // Streak multiplier
    double streakMultiplier = _getStreakMultiplier(currentStreak);
    baseXp = (baseXp * streakMultiplier).round();
    
    // Performance bonus
    int performanceBonus = _calculatePerformanceBonus(co2SavedPercent);
    
    // Daily cap
    int total = min(baseXp + performanceBonus, dailyXpCap);
    return total;
  }

  static double _getStreakMultiplier(int streakDays) {
    if (streakDays < 7) return 1.0;
    if (streakDays < 30) return 1.25;
    return 1.5;
  }

  static int _calculatePerformanceBonus(double co2SavedPercent) {
    if (co2SavedPercent >= 30) return 25;
    if (co2SavedPercent >= 15) return 15;
    if (co2SavedPercent >= 5) return 8;
    return 0;
  }

  /// Determine user's level from total XP
  static int getLevelFromXp(int totalXp) {
    const xpThresholds = [
      0, 500, 1500, 3000, 5000, 8000, 12000, 17000, 23000, 31000
    ];
    
    for (int i = xpThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= xpThresholds[i]) return i + 1;
    }
    return 1;
  }

  /// Get XP required for next level
  static int getXpToNextLevel(int currentLevel, int currentXp) {
    const xpThresholds = [
      0, 500, 1500, 3000, 5000, 8000, 12000, 17000, 23000, 31000
    ];
    
    if (currentLevel >= xpThresholds.length) return 0; // Max level
    return xpThresholds[currentLevel] - currentXp;
  }

  /// Evaluate badge triggers
  static List<Badge> evaluateBadges({
    required int completedChallenges,
    required int currentStreak,
    required int currentLevel,
    required List<Badge> earnedBadges,
  }) {
    final newBadges = <Badge>[];
    
    // Streak badges
    if (currentStreak >= 7 && !_hasBadge(earnedBadges, 'week_warrior')) {
      newBadges.add(Badge.weekWarrior);
    }
    if (currentStreak >= 30 && !_hasBadge(earnedBadges, 'monthly_maven')) {
      newBadges.add(Badge.monthlyMaven);
    }
    if (currentStreak >= 100 && !_hasBadge(earnedBadges, 'century_eco')) {
      newBadges.add(Badge.centuryEco);
    }
    
    // Level badges
    if (currentLevel >= 10 && !_hasBadge(earnedBadges, 'carbon_neutral')) {
      newBadges.add(Badge.carbonNeutral);
    }
    
    // Challenge badges (per category)
    // ... check completedChallenges by category
    
    return newBadges;
  }

  static bool _hasBadge(List<Badge> badges, String badgeName) {
    return badges.any((b) => b.name == badgeName);
  }

  /// Streak logic
  static int updateStreak({
    required int currentStreak,
    required DateTime lastLogDate,
    required DateTime todayDate,
    required bool loggedToday,
  }) {
    final daysSinceLastLog = todayDate.difference(lastLogDate).inDays;
    
    if (loggedToday) {
      // If logged today, maintain or increment streak
      if (daysSinceLastLog == 0) {
        return currentStreak; // Already counted
      } else if (daysSinceLastLog == 1) {
        return currentStreak + 1; // Continue streak
      } else {
        return 1; // Reset after gap
      }
    } else {
      return currentStreak; // No log yet
    }
  }
}
```

**Unit Tests:**

```dart
// test/domain/gamification/gamification_engine_test.dart

void main() {
  group('GamificationEngine', () {
    test('Full log with 7-day streak gives correct XP', () {
      const xp = GamificationEngine.calculateXp(
        isFullLog: true,
        currentStreak: 7,
        co2SavedPercent: 20,
        dailyXpCap: 500,
      );
      
      // 50 XP base * 1.25 (7-day multiplier) + 15 (≥15% bonus) = 77.5 → 77
      expect(xp, 77);
    });

    test('Partial log without streak gives 20 XP', () {
      const xp = GamificationEngine.calculateXp(
        isFullLog: false,
        currentStreak: 0,
        co2SavedPercent: 0,
        dailyXpCap: 500,
      );
      
      expect(xp, 20);
    });

    test('Level is correct for given XP', () {
      expect(GamificationEngine.getLevelFromXp(0), 1);
      expect(GamificationEngine.getLevelFromXp(500), 2);
      expect(GamificationEngine.getLevelFromXp(1500), 3);
      expect(GamificationEngine.getLevelFromXp(31000), 10);
    });

    test('Streak increments on consecutive days', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final today = DateTime.now();
      
      final newStreak = GamificationEngine.updateStreak(
        currentStreak: 5,
        lastLogDate: yesterday,
        todayDate: today,
        loggedToday: true,
      );
      
      expect(newStreak, 6);
    });

    test('Streak resets after gap', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final today = DateTime.now();
      
      final newStreak = GamificationEngine.updateStreak(
        currentStreak: 10,
        lastLogDate: twoDaysAgo,
        todayDate: today,
        loggedToday: true,
      );
      
      expect(newStreak, 1); // Reset
    });

    test('Badges are awarded at correct milestones', () {
      final badges = GamificationEngine.evaluateBadges(
        completedChallenges: 5,
        currentStreak: 7,
        currentLevel: 5,
        earnedBadges: [],
      );
      
      expect(badges.where((b) => b.name == 'week_warrior'), isNotEmpty);
    });
  });
}
```

---

### 5.9 Error Handling & Retry Strategy (Resolves Gap 1.9)

**ResultType Pattern:**

```dart
// lib/domain/result/result.dart

sealed class Result<T> {
  const Result();
  
  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, {Object? error, StackTrace? stackTrace}) = Failure<T>;
  factory Result.retry(String message) = Retry<T>;
  
  R when<R>({
    required R Function(T) onSuccess,
    required R Function(String) onFailure,
    required R Function(String) onRetry,
  }) {
    return switch (this) {
      Success(:final data) => onSuccess(data),
      Failure(:final message) => onFailure(message),
      Retry(:final message) => onRetry(message),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  const Failure(this.message, {this.error, this.stackTrace});
}

final class Retry<T> extends Result<T> {
  final String message;
  const Retry(this.message);
}
```

**Riverpod Provider with Retry Logic:**

```dart
// lib/providers/async_providers.dart

final asyncLogActivityProvider = FutureProvider.autoDispose
  .family<Result<DailyResult>, DailyLog>((ref, log) async {
  return _logActivityWithRetry(ref, log);
});

Future<Result<DailyResult>> _logActivityWithRetry(
  ProviderRef ref,
  DailyLog log, {
  int retryCount = 0,
  const maxRetries = 3,
}) async {
  try {
    final repo = ref.watch(activityRepositoryProvider);
    final result = await repo.logActivity(log);
    return Result.success(result);
  } on NetworkException catch (e) {
    if (retryCount < maxRetries) {
      // Exponential backoff: 1s, 2s, 4s
      final delay = Duration(seconds: pow(2, retryCount).toInt());
      await Future.delayed(delay);
      return _logActivityWithRetry(ref, log, retryCount: retryCount + 1);
    } else {
      return Result.failure(
        'Failed to log activity after $maxRetries retries',
        error: e,
      );
    }
  } catch (e, st) {
    return Result.failure(
      'Unexpected error: $e',
      error: e,
      stackTrace: st,
    );
  }
}
```

**UI Error Display:**

```dart
// lib/features/activity_log/activity_log_page.dart

class ActivityLogPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logFuture = ref.watch(asyncLogActivityProvider(log));
    
    return logFuture.when(
      loading: () => const LoadingDialog(),
      error: (err, st) => ErrorDialog(error: err.toString()),
      data: (result) => result.when(
        onSuccess: (dailyResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('+${dailyResult.xpEarned} XP!')),
          );
          Navigator.pop(context);
        },
        onFailure: (message) {
          showErrorDialog(context, message);
        },
        onRetry: (message) {
          showRetryDialog(context, message, () {
            ref.refresh(asyncLogActivityProvider(log));
          });
        },
      ),
    );
  }
}
```

---

### 5.10 Testing Strategy (Resolves Gap 1.10)

**Test Coverage Targets:**

| Component | Target | Type |
|---|---|---|
| CO₂ Calculator | 100% | Unit |
| Gamification Engine | 95% | Unit |
| Form Validators | 100% | Unit |
| Sync Manager | 90% | Unit + Integration |
| Critical UI Paths | 70% | Widget |
| End-to-end Flows | 2–3 flows | Integration |

**CO₂ Engine Test Suite:**

```dart
// test/domain/co2_engine/co2_calculator_test.dart

void main() {
  group('CO2Calculator.processSignUpProfile', () {
    test('Calculates baseline correctly for petrol car', () {
      final input = SignUpProfileInput(
        primaryTransport: 'car',
        fuelType: 'petrol',
        engineSize: 'medium',
        vehicleAge: '2010_2019',
        avgDailyKm: 50,
        homeType: 'house_medium',
        residents: 2,
        monthlyKwh: 300,
        country: 'PK',
        heatingType: 'natural_gas',
        hasSolar: false,
        dietaryPreference: 'omnivore',
      );

      final profile = CO2Calculator.processSignUpProfile(input);

      // Transport: 0.23 * 0.95 (age multiplier) * 50 km = 10.925 kgCO2e/day
      expect(profile.dailyTransportCO2, closeTo(10.925, 0.1));

      // Energy: (300 / 30 / 2) = 5 kWh/day * 0.45 (PK grid) = 2.25 kgCO2e/day
      expect(profile.dailyEnergyBaselineKwh, 5);
      expect(profile.dailyEnergyBaselineCO2, closeTo(2.25, 0.1));

      // Food: omnivore = 5.5 kgCO2e/day
      expect(profile.dailyFoodBaselineCO2, 5.5);

      // Total
      expect(profile.totalDailyBaselineCO2, closeTo(18.675, 0.2));
    });

    test('EV factor computed at runtime, not table-looked-up', () {
      final input = SignUpProfileInput(
        primaryTransport: 'ev',
        engineSize: 'medium',
        // ...
      );

      final profile = CO2Calculator.processSignUpProfile(input);

      // EV: 0.18 kWh/km * 0.45 (PK grid) = 0.081 kgCO2/km
      expect(profile.transportFactor, closeTo(0.081, 0.001));
    });

    test('Solar panel reduces electricity baseline by 25%', () {
      final without = CO2Calculator.processSignUpProfile(
        SignUpProfileInput(
          hasSolar: false,
          monthlyKwh: 300,
          residents: 2,
          // ...
        ),
      );

      final with_ = CO2Calculator.processSignUpProfile(
        SignUpProfileInput(
          hasSolar: true,
          monthlyKwh: 300,
          residents: 2,
          // ...
        ),
      );

      expect(with_.dailyEnergyBaselineKwh,
        closeTo(without.dailyEnergyBaselineKwh * 0.75, 0.01));
    });
  });

  group('CO2Calculator.processDailyLog', () {
    test('XP calculation matches Gamification Spec', () {
      final log = DailyLog(
        transportEntries: [],
        foodEntries: [],
        energyLog: EnergyLog(deviations: [], confirmed: true),
      );

      final profile = UserProfile(...);

      // Assuming log is perfect (full log, 15% below baseline)
      final result = CO2Calculator.processDailyLog(
        log: log,
        profile: profile,
        streakDays: 7,
      );

      // Base 50 * 1.25 (7-day) + 15 (≥15% bonus) = 77
      expect(result.xpEarned, 77);
    });

    test('Food unit conversion is correct', () {
      final entry = FoodEntry(
        co2Per100g: 60, // gCO2e/100g (beef)
        servingGrams: 150,
      );

      final co2 = calculateFoodItemCO2(entry);
      // (60 / 1000) * (150 / 100) = 0.09 kgCO2e
      expect(co2, closeTo(0.09, 0.001));
    });

    test('Negative savings are clamped to 0', () {
      final result = CO2Calculator.processDailyLog(
        log: excessiveLog, // exceeds baseline
        profile: profile,
        streakDays: 0,
      );

      expect(result.co2SavedVsBaseline, lessThanOrEqualTo(0));
      expect(result.equivalences.carKmEquivalent, 0);
    });
  });
}
```

**Widget Test Example:**

```dart
// test/features/activity_log/activity_log_form_test.dart

void main() {
  group('ActivityLogForm', () {
    testWidgets('Transport tab validates distance input', (tester) async {
      await tester.pumpWidget(
        ProviderContainer(
          child: MaterialApp(
            home: Scaffold(
              body: ActivityLogForm(),
            ),
          ),
        ),
      );

      // Find distance input field
      final distanceField = find.byType(TextField).first;

      // Test invalid input
      await tester.enterText(distanceField, '-100');
      await tester.pumpAndSettle();

      expect(find.text('Distance cannot be negative'), findsOneWidget);

      // Test valid input
      await tester.enterText(distanceField, '25');
      await tester.pumpAndSettle();

      expect(find.text('Distance cannot be negative'), findsNothing);
    });
  });
}
```

**Integration Test (Critical User Flow):**

```dart
// test/integration/onboard_log_levelup_test.dart

void main() {
  group('Integration: Onboard → Log → Level Up', () {
    testWidgets('User can complete full flow', (tester) async {
      // Setup
      final supabase = MockSupabaseClient();
      await tester.pumpWidget(
        ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(supabase),
          ],
          child: const MyApp(),
        ),
      );

      // 1. Onboarding
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Swipe through slides
      for (int i = 0; i < 4; i++) {
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();
      }

      // Click "Get Started"
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // 2. Sign Up
      expect(find.byType(SignUpScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // 3. Profile Setup
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      // ... fill form fields ...
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 4. Dashboard
      expect(find.byType(DashboardScreen), findsOneWidget);

      // 5. Log Activity
      await tester.tap(find.byIcon(Icons.add)); // FAB
      await tester.pumpAndSettle();

      // ... log transport, food, energy ...
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Verify XP increase and animation
      expect(find.byType(ConfettiWidget), findsOneWidget); // celebration
    });
  });
}
```

---

### 5.11 Project Structure (Resolves Gap 1.11)

**Recommended Folder Layout:**

```
neutrawise/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   ├── constants.dart (level thresholds, API endpoints, etc.)
│   │   ├── environment.dart
│   │   └── logger.dart
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local/ (Hive)
│   │   │   │   ├── daily_logs_hive.dart
│   │   │   │   └── user_cache.dart
│   │   │   └── remote/ (Supabase)
│   │   │       ├── supabase_client.dart
│   │   │       └── off_api_client.dart
│   │   └── repositories/
│   │       ├── auth_repository.dart
│   │       ├── activity_repository.dart
│   │       ├── user_repository.dart
│   │       ├── leaderboard_repository.dart
│   │       └── sync_repository.dart
│   ├── domain/
│   │   ├── models/
│   │   │   ├── user_profile.dart
│   │   │   ├── daily_log.dart
│   │   │   ├── daily_result.dart
│   │   │   ├── food_entry.dart
│   │   │   ├── transport_entry.dart
│   │   │   ├── energy_log.dart
│   │   │   └── badge.dart
│   │   ├── co2_engine/
│   │   │   ├── emission_factors.dart (SINGLE SOURCE OF TRUTH)
│   │   │   ├── co2_calculator.dart
│   │   │   ├── transport_calculator.dart
│   │   │   ├── food_calculator.dart
│   │   │   └── energy_calculator.dart
│   │   ├── gamification/
│   │   │   ├── gamification_engine.dart
│   │   │   ├── xp_calculator.dart
│   │   │   ├── level_calculator.dart
│   │   │   ├── badge_evaluator.dart
│   │   │   └── streak_manager.dart
│   │   ├── validators/
│   │   │   ├── input_validators.dart
│   │   │   ├── transport_validator.dart
│   │   │   ├── food_validator.dart
│   │   │   └── energy_validator.dart
│   │   ├── result/
│   │   │   └── result.dart (Result<T> type)
│   │   └── usecases/ (if needed)
│   ├── providers/ (Riverpod)
│   │   ├── auth_provider.dart
│   │   ├── user_provider.dart
│   │   ├── leaderboard_provider.dart
│   │   ├── activity_provider.dart
│   │   ├── sync_manager_provider.dart
│   │   └── theme_provider.dart
│   ├── features/ (Feature-based UI)
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── onboarding_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── signup_screen.dart
│   │   │   │   └── profile_setup_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── onboarding_slide.dart
│   │   │   │   ├── profile_transport_form.dart
│   │   │   │   ├── profile_residency_form.dart
│   │   │   │   └── profile_energy_form.dart
│   │   │   └── providers/
│   │   │       └── auth_form_provider.dart
│   │   ├── dashboard/
│   │   │   ├── screens/
│   │   │   │   └── dashboard_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── co2_ring_chart.dart
│   │   │   │   ├── category_cards.dart
│   │   │   │   ├── weekly_graph.dart
│   │   │   │   ├── eco_tip_card.dart
│   │   │   │   └── streak_banner.dart
│   │   │   └── providers/
│   │   │       └── dashboard_provider.dart
│   │   ├── activity_log/
│   │   │   ├── screens/
│   │   │   │   └── activity_log_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── transport_tab.dart
│   │   │   │   ├── food_tab.dart
│   │   │   │   ├── energy_tab.dart
│   │   │   │   ├── food_search_field.dart
│   │   │   │   └── category_selector.dart
│   │   │   └── providers/
│   │   │       └── activity_form_provider.dart
│   │   ├── insights/
│   │   │   ├── screens/
│   │   │   │   └── insights_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── trend_chart.dart
│   │   │   │   ├── category_breakdown.dart
│   │   │   │   ├── equivalences_strip.dart
│   │   │   │   └── monthly_target_card.dart
│   │   │   └── providers/
│   │   │       └── insights_provider.dart
│   │   ├── gamification/
│   │   │   ├── screens/
│   │   │   │   └── gamification_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── level_banner.dart
│   │   │   │   ├── challenge_card.dart
│   │   │   │   ├── badge_grid.dart
│   │   │   │   ├── leaderboard_tab.dart
│   │   │   │   └── challenge_modal.dart
│   │   │   └── providers/
│   │   │       └── gamification_provider.dart
│   │   ├── profile/
│   │   │   ├── screens/
│   │   │   │   └── profile_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── user_stats.dart
│   │   │   │   ├── badge_showcase.dart
│   │   │   │   └── settings_section.dart
│   │   │   └── providers/
│   │   │       └── profile_provider.dart
│   │   └── ai_assistant/
│   │       ├── screens/
│   │       │   └── ai_assistant_screen.dart (Coming Soon)
│   │       └── widgets/
│   │           └── coming_soon_placeholder.dart
│   ├── routing/
│   │   ├── router.dart (go_router config)
│   │   └── auth_guard.dart
│   ├── services/
│   │   ├── push_notification_service.dart
│   │   ├── sync_manager.dart
│   │   ├── connectivity_service.dart
│   │   ├── biometric_auth_service.dart (future)
│   │   └── crash_reporting.dart (future)
│   ├── widgets/ (Shared/reusable components)
│   │   ├── buttons/
│   │   │   ├── primary_button.dart
│   │   │   └── secondary_button.dart
│   │   ├── cards/
│   │   │   ├── card_base.dart
│   │   │   └── stat_card.dart
│   │   ├── forms/
│   │   │   ├── text_input.dart
│   │   │   ├── numeric_input.dart
│   │   │   └── dropdown_field.dart
│   │   ├── charts/
│   │   │   ├── ring_chart.dart
│   │   │   ├── bar_chart.dart
│   │   │   └── line_chart.dart
│   │   ├── loaders/
│   │   │   ├── loading_dialog.dart
│   │   │   └── loading_indicator.dart
│   │   ├── errors/
│   │   │   ├── error_dialog.dart
│   │   │   └── error_snackbar.dart
│   │   ├── modals/
│   │   │   ├── bottom_sheet_base.dart
│   │   │   └── celebration_modal.dart
│   │   └── theme/
│   │       ├── app_colors.dart
│   │       ├── app_typography.dart
│   │       ├── app_spacing.dart
│   │       └── app_theme.dart
│   └── utils/
│       ├── extensions.dart
│       ├── formatters.dart
│       └── helpers.dart
├── test/
│   ├── domain/
│   │   ├── co2_engine/
│   │   │   ├── co2_calculator_test.dart
│   │   │   └── emission_factors_test.dart
│   │   ├── gamification/
│   │   │   └── gamification_engine_test.dart
│   │   └── validators/
│   │       └── input_validators_test.dart
│   ├── data/
│   │   └── repositories/
│   │       └── sync_repository_test.dart
│   ├── features/
│   │   ├── auth/
│   │   │   └── onboarding_screen_test.dart
│   │   └── activity_log/
│   │       └── activity_log_form_test.dart
│   └── integration/
│       └── onboard_log_levelup_test.dart
├── supabase/
│   ├── migrations/
│   │   ├── 001_initial_schema.sql
│   │   ├── 002_rls_policies.sql
│   │   └── 003_push_notifications.sql
│   ├── functions/
│   │   ├── schedule_push_notification/
│   │   │   └── index.ts
│   │   ├── validate_activity_log/
│   │   │   └── index.ts
│   │   └── compute_leaderboard/
│   │       └── index.ts
│   ├── seed.sql
│   └── .env.example
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── .github/
    └── workflows/
        ├── test.yml
        └── deploy.yml
```

---

## 6. Security Checklist

- ✅ **RLS Policies:** All user-specific tables have RLS enabled
- ✅ **Input Validation:** Client-side + server-side validation
- ✅ **Token Refresh:** Automatic via Supabase SDK
- ✅ **API Keys:** Stored in Supabase secrets, not in app code
- ✅ **Sensitive Data:** User passwords handled by Supabase Auth
- ⚠️ **HTTPS Enforcement:** Configure in Supabase domain settings
- ⚠️ **Rate Limiting:** Implement in Edge Functions (future)
- ⚠️ **Data Encryption at Rest:** Supabase handles; can enable encryption zones (future)

---

## 7. Scalability Checklist

- ✅ **Database Indexes:** Added on frequently queried columns
- ✅ **Realtime Subscriptions:** Paginated & on-demand (not continuous)
- ✅ **Offline-First:** Local caching with Hive
- ✅ **API Caching:** Food search caching (future: backend proxy)
- ⚠️ **CDN:** Supabase doesn't include CDN; consider AWS CloudFront (v1.1+)
- ⚠️ **Monitoring:** Add Sentry or DataDog (v1.1+)

---

## Summary

The provided implementation plan is **solid and executable**. The 11 gaps identified are addressable through the detailed solutions in §5. Key takeaways:

1. **Offline Sync** is critical—implement Optimistic UI + conflict resolution
2. **CO₂ Engine** is the heart—100% test coverage, single source of truth for emission factors
3. **Push Notifications** are engagement drivers—must be production-ready
4. **Gamification** logic should be centralized—not scattered across UI
5. **Security** requires RLS policies + input validation—both ends
6. **Testing** strategy is essential—target 90%+ coverage on business logic
7. **Project structure** must be consistent—make onboarding smooth

**Estimated effort:** 14–18 weeks for full v1 (5 phases, 2–4 weeks per phase).

---

*NeutraWise Implementation Plan — Gap Analysis & Enhanced Roadmap*  
*Date: May 2026*  
*Authors: Architecture Review Team*
