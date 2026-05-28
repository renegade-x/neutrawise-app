# NeutraWise
## Algorithm Specification Document
**CO2 Calculation Engine &nbsp;•&nbsp; v1.0 &nbsp;•&nbsp; May 2026**

---

# Part I — Inconsistency Analysis

The following issues were identified by line-by-line cross-file review before the specification was written. All issues have been resolved in Part II. Severity ratings: **CRITICAL** = incorrect CO2 output; **WARNING** = silent failure risk; **NOTE** = design ambiguity.

---

## 1.1 &nbsp;CRITICAL — EV factor in TRANSPORT_FACTORS is dead code

| Severity | Issue |
|---|---|
| 🔴 **CRITICAL** | **`TRANSPORT_FACTORS.ev = 0.053` is never used.** `emissionFactors.js` defines `ev: 0.053` with a comment *'base; multiplied by grid factor at runtime'*. But the runtime function `deriveTransportFactor()` in `signupProcessor.js` never reads this value. It independently computes the EV factor from `EV_EFFICIENCY_KWH_PER_KM × gridIntensity`. The constant `0.053` is therefore dead code, and any developer who later uses `TRANSPORT_FACTORS.ev` directly will get the wrong answer — it is a static global average, not the grid-adjusted value. **Fix:** Remove `ev` from `TRANSPORT_FACTORS` entirely. Add a comment on the EV block in `deriveTransportFactor()` explicitly stating that EV factors are never table-looked-up. |

---

## 1.2 &nbsp;CRITICAL — Category mapper is duplicated but diverges between files

| Severity | Issue |
|---|---|
| 🔴 **CRITICAL** | **`mapOFFCategoryToFactor()` and `mapCategoryToKey()` are near-identical copies with one silent divergence.** `dailyLogProcessor.js` defines `mapOFFCategoryToFactor()`. `foodSearch.js` defines `mapCategoryToKey()`. They claim to mirror each other, but `mapOFFCategoryToFactor()` includes the check `cat.includes('pig')` for pork, while `mapCategoryToKey()` does not. A product tagged `'en:pig-meat'` would resolve to `'pork'` in the daily processor but fall through to `'vegetables_avg'` in the food search layer, producing a wildly different CO2 estimate for the same product depending on which path is taken. **Fix:** Extract a single shared `mapOFFCategoryToFactorKey()` function into `emissionFactors.js` and import it into both files. |

---

## 1.3 &nbsp;CRITICAL — Food CO2 unit conversion is applied twice in foodSearch.js

| Severity | Issue |
|---|---|
| 🔴 **CRITICAL** | **`estimateCO2ForServing()` in `FoodSearchResult` double-divides by 1000.** In `normaliseOFFProduct()`, `co2Per100g` is stored as `gCO2e/100g`. In `estimateCO2ForServing()`, the code does `(co2Per100g / 1000) * (servingGrams / 100)` — correct. However, `buildFoodEntry()` passes `result.co2Per100g` directly to `processDailyLog`, which then applies the `/1000` conversion again via `calculateFoodItemCO2()`. The actual math is consistent, but the unit contract is undocumented, making it a high-probability future bug if a developer "fixes" the apparent redundancy and breaks one path. **Fix:** Document the unit contract explicitly in both the `FoodEntry` typedef and the `co2Per100g` field: *"unit: gCO2e per 100g (raw from OFF, unconverted). Both `estimateCO2ForServing()` and `calculateFoodItemCO2()` apply the `/1000` conversion independently from this raw value."* |

---

## 1.4 &nbsp;WARNING — Heating CO2 extraction in daily processor is fragile

| Severity | Issue |
|---|---|
| 🟠 **WARNING** | **`calculateDailyEnergyCO2()` reverse-engineers `heatingCO2` via subtraction, not storage.** `heatingCO2` is derived as `userProfile.dailyEnergyBaselineCO2 - (userProfile.dailyEnergyBaselineKwh * userProfile.gridIntensity)`. Two problems: (1) floating-point subtraction accumulates error, which is why `heatingCO2Safe = Math.max(0, heatingCO2)` was needed as a guard. (2) If either field is updated independently (e.g. user updates their electricity bill), the reverse-engineered value will be wrong. **Fix:** Store `dailyHeatingBaselineCO2` as its own explicit field in `UserProfile`. Read it directly in `calculateDailyEnergyCO2()`. Remove the `heatingCO2Safe` guard — it becomes unnecessary. |

---

## 1.5 &nbsp;WARNING — Solar deviation tags conflict with sign-up solar reduction

| Severity | Issue |
|---|---|
| 🟠 **WARNING** | **Users with `hasSolar=true` get the solar discount applied at baseline AND again daily.** At sign-up, `effectiveKwh = dailyKwh * 0.75`. The `ENERGY_DEVIATION_KWH` table also offers `solar_panels_sunny: -4.0` and `solar_panels_cloudy: -1.5` as daily deviations. A `hasSolar=true` user who taps `solar_panels_sunny` receives the 25% baseline reduction AND an additional −4 kWh that day, double-counting the solar benefit. **Fix (recommended — Option A):** Remove `solar_panels_sunny` and `solar_panels_cloudy` from `ENERGY_DEVIATION_KWH` for `hasSolar=true` users. Only surface these tags for `hasSolar=false` users as a one-time reporting event when they install panels. |

---

## 1.6 &nbsp;WARNING — XP system contradicts the gamification document

| Severity | Issue |
|---|---|
| 🟠 **WARNING** | **`calculateDailyXP()` awards 10–40 XP for logging, but `NeutraWise_Gamification_System.docx` specifies 20–50 XP.** The gamification spec defines: full log = 50 XP; partial log = 20 XP. The code awards: base 10 XP + 5 for completeness = 15 XP max, plus up to 25 XP performance bonus = 40 XP total. The streak multiplier (×1.5 at 7+ days) specified in the gamification doc is also not implemented. **Fix:** Align `calculateDailyXP()` with the gamification spec. Performance bonus stacks on top of, not instead of, the base XP. Pass `streakDays` into the function and apply the multiplier. |

---

## 1.7 &nbsp;WARNING — loggedAllCategories check ignores energy

| Severity | Issue |
|---|---|
| 🟠 **WARNING** | **`processDailyLog()` treats energy as always logged, silently.** The completeness check is `loggedAllCategories = transport?.length > 0 && food?.length > 0`. Energy is excluded. A user who submits only transport and food entries with `energy: { deviations: [] }` is considered to have logged all three categories and earns the full completeness bonus, even though they made no active energy input. **Fix:** Require a boolean flag `energyLog.confirmed = true` in the completeness check. The UI sets this flag when the user taps any deviation chip or explicitly taps *"Typical day"* to confirm. |

---

## 1.8 &nbsp;NOTE — Default avgDailyKm of 10km silently skews baseline

| Severity | Issue |
|---|---|
| 🔵 **NOTE** | **`avgDailyKm` defaults to 10km at sign-up if the user skips it.** For a walker or public-transport user, 10km is reasonable. But for a car user who drives 50km daily, the underestimated baseline means every actual logged day appears as a large emitter, and `co2SavedVsBaseline` will be persistently negative. **Fix:** Make `avgDailyKm` a required field for users who select `car`, `motorcycle`, or `ev` as `primaryTransport`. For other modes, ask for average weekly trips. If still not provided, surface a first-log prompt: *"We need your typical commute distance to set your baseline accurately."* |

---

## 1.9 &nbsp;NOTE — pizza_slice factor unit is inconsistent

| Severity | Issue |
|---|---|
| 🔵 **NOTE** | **`FOOD_CATEGORY_FACTORS.pizza_slice = 0.5` is labelled *'per 100g'* but all other values are per kg.** The comment is wrong — `0.5 kgCO2e/kg` is a reasonable pizza figure. The comment implies `0.5 kgCO2e/100g = 5.0 kgCO2e/kg`, which would be closer to beef. **Fix:** Remove the `'per 100g'` comment. Add a file-top contract comment: *"ALL values in this table are kgCO2e per kg of food as produced. No exceptions."* Also audit `fast_food_burger = 4.0` with its `'per serving ~200g'` comment — that annotation labels a typical serving size, not a unit change. |

---

## Analysis Summary

| # | Issue | Severity | Status |
|---|---|---|---|
| 1.1 | `TRANSPORT_FACTORS.ev` is dead code | CRITICAL | Fixed in spec |
| 1.2 | Category mapper duplicated and diverges (pig) | CRITICAL | Fixed in spec |
| 1.3 | CO2 unit conversion path confusion risk | CRITICAL | Documented in spec |
| 1.4 | Heating CO2 derived by subtraction, fragile | WARNING | Fixed in spec |
| 1.5 | Solar double-counted for `hasSolar=true` users | WARNING | Fixed in spec |
| 1.6 | XP values contradict gamification spec | WARNING | Fixed in spec |
| 1.7 | Energy not checked in completeness test | WARNING | Fixed in spec |
| 1.8 | `avgDailyKm` default skews baseline silently | NOTE | Addressed in spec |
| 1.9 | `pizza_slice` comment implies wrong unit | NOTE | Fixed in spec |

---

# Part II — Unified Algorithm Specification

This section is the canonical reference for the NeutraWise CO2 calculation engine. It supersedes all inline comments in individual source files. All issues identified in Part I are resolved here.

---

## 2.1 &nbsp;System Architecture

**Two processing stages, one `UserProfile` object:**

| Stage | Trigger | Output | Stored? |
|---|---|---|---|
| Sign-Up Processor | User completes onboarding | `UserProfile` (baseline + factors) | Yes — DB |
| Daily Log Processor | User submits daily log | `DailyResult` (CO2 + XP + delta) | Yes — DB |
| Food Search API | User types in food log screen | `FoodSearchResult[]` (live) | No — ephemeral |

---

## 2.2 &nbsp;Shared Constants Contract

All emission factor tables live exclusively in `emissionFactors.js`. No algorithm file may hardcode an emission factor. Every table entry follows this unit contract:

| Table | Unit | Notes |
|---|---|---|
| `TRANSPORT_FACTORS` | kgCO2e per km per passenger | EV key removed — EV computed at runtime |
| `VEHICLE_AGE_MULTIPLIER` | dimensionless multiplier | Applied to car/motorcycle only, not EV |
| `EV_EFFICIENCY_KWH_PER_KM` | kWh per km | Multiplied by `gridIntensity` at runtime |
| `FOOD_CATEGORY_FACTORS` | kgCO2e per kg of food | ALL entries; no exceptions |
| `STANDARD_SERVING_WEIGHTS_G` | grams | Default serving; overridden by OFF or user input |
| `PORTION_MULTIPLIERS` | dimensionless multiplier | Applied to `STANDARD_SERVING_WEIGHTS_G` |
| `GRID_INTENSITY_BY_COUNTRY` | kgCO2e per kWh | ISO 3166-1 alpha-2 keys |
| `HEATING_FACTORS` | kgCO2e per kWh of heat delivered | `null` for `electric`/`heat_pump` |
| `BASE_DAILY_KWH_BY_HOME` | kWh per day per household | Divide by residents for per-person |
| `ENERGY_DEVIATION_KWH` | kWh delta (positive or negative) | Solar deviations for `hasSolar=false` only |

---

## 2.3 &nbsp;Sign-Up Processor — `processSignUpProfile()`

### Inputs (SignUpProfile)

| Field | Type | Required? | Notes |
|---|---|---|---|
| `primaryTransport` | string | Yes | `car` \| `ev` \| `motorcycle` \| `bus` \| `train` \| `metro` \| `bicycle` \| `walking` \| `ferry` \| `taxi` \| `rideshare` |
| `fuelType` | string | If car/motorcycle | `petrol` \| `diesel` \| `hybrid` \| `electric` |
| `engineSize` | string | If car/ev/motorcycle | `small` \| `medium` \| `large` |
| `vehicleAge` | string | If car/motorcycle | `pre_2010` \| `2010_2019` \| `2020_plus` |
| `avgDailyKm` | number | Required for car/ev/motorcycle | Round trip commute. No default — prompt if missing. |
| `country` | string | Yes | ISO 3166-1 alpha-2 |
| `homeType` | string | Yes | `apartment_small` \| `apartment_large` \| `house_small` \| `house_medium` \| `house_large` |
| `residents` | number | Yes | Minimum 1 |
| `heatingType` | string | Yes | `natural_gas` \| `electric` \| `heat_pump` \| `lpg` \| `oil` \| `district` \| `biomass_wood` \| `coal` |
| `hasSolar` | boolean | Yes | Affects which deviation tags are shown daily |
| `monthlyKwh` | number | Recommended | From electricity bill. If omitted, home-type lookup used. |
| `dietaryPreference` | string | Yes | `vegan` \| `vegetarian` \| `pescatarian` \| `flexitarian` \| `omnivore` \| `carnivore` |

### Transport Factor Derivation

**Rule 1:** Fixed-mode transport (bus, train, metro, etc.) → return `TRANSPORT_FACTORS[mode]` directly. No age or engine multiplier.

**Rule 2:** EV → `transportFactor = EV_EFFICIENCY_KWH_PER_KM[engineSize] × gridIntensity`. Age multiplier NOT applied. `TRANSPORT_FACTORS.ev` does not exist.

**Rule 3:** Car or motorcycle → `key = fuelType + '_' + engineSize` → look up `TRANSPORT_FACTORS[key]` → multiply by `VEHICLE_AGE_MULTIPLIER[vehicleAge]`.

```
transportFactor (kgCO2e/km) = TRANSPORT_FACTORS[fuelType_engineSize] × VEHICLE_AGE_MULTIPLIER[vehicleAge]
```

**Daily transport baseline** (used only for baseline total, not for daily log):

```
dailyTransportCO2 = transportFactor × avgDailyKm
```

### Energy Baseline Derivation

**Step 1 — Electricity kWh per person per day:**
- If `monthlyKwh` provided: `dailyKwh = monthlyKwh / 30 / residents`
- Else: `dailyKwh = BASE_DAILY_KWH_BY_HOME[homeType] / residents`

**Step 2 — Solar adjustment (`hasSolar=true` only):**
- `effectiveKwh = dailyKwh × 0.75` &nbsp;&nbsp;(25% generation offset baked into baseline)
- Solar deviation tags (`solar_panels_sunny`, `solar_panels_cloudy`) are hidden in the UI for `hasSolar=true` users to prevent double-counting.

**Step 3 — Electricity CO2:**
```
electricityCO2 = effectiveKwh × GRID_INTENSITY_BY_COUNTRY[country]
```

**Step 4 — Heating CO2 (non-electric only):**
- If `heatingType` is `'electric'` or `'heat_pump'`: `heatingCO2 = 0` (captured in electricity)
- Else: `heatingCO2 = (heatingKwhMap[homeType] × 0.667 / residents) × HEATING_FACTORS[heatingType]`
- `0.667` = 8-month heating season fraction

**Step 5 — Store both components separately in UserProfile:**
```
dailyEnergyBaselineKwh  = effectiveKwh
dailyHeatingBaselineCO2 = heatingCO2      ← stored explicitly, NOT reverse-engineered later
dailyEnergyBaselineCO2  = electricityCO2 + heatingCO2
```

### Food Baseline Derivation

Maps dietary preference to typical daily food CO2 (kgCO2e/day) using Poore & Nemecek 2018:

| Preference | Daily baseline (kgCO2e) |
|---|---|
| vegan | 1.5 |
| vegetarian | 2.5 |
| pescatarian | 3.4 |
| flexitarian | 4.2 |
| omnivore | 5.5 |
| carnivore | 7.2 |

### UserProfile Output

**Formula — total daily baseline:**

```
totalDailyBaselineCO2 = dailyTransportCO2 + dailyEnergyBaselineCO2 + dailyFoodBaselineCO2
```

**Fields stored in DB:**

| Field | Type | Unit |
|---|---|---|
| `transportFactor` | number | kgCO2e/km |
| `vehicleProfile` | object | `{ mode, fuelType, engineSize, vehicleAge }` |
| `avgDailyKm` | number | km |
| `dailyTransportCO2` | number | kgCO2e |
| `dailyEnergyBaselineKwh` | number | kWh/day (post-solar) |
| `dailyHeatingBaselineCO2` | number | kgCO2e/day &nbsp;← NEW explicit field |
| `dailyEnergyBaselineCO2` | number | kgCO2e/day (electricity + heating) |
| `gridIntensity` | number | kgCO2e/kWh |
| `hasSolar` | boolean | — |
| `dietaryPreference` | string | — |
| `dailyFoodBaselineCO2` | number | kgCO2e/day |
| `totalDailyBaselineCO2` | number | kgCO2e/day |
| `countryCode` | string | ISO 3166-1 alpha-2 |
| `kwBaselineSource` | string | `'bill'` \| `'estimate'` |
| `createdAt` | string | ISO 8601 |

---

## 2.4 &nbsp;Food Search API Layer — `foodSearch.js`

### CO2 Data Resolution Chain (per product)

**Priority 1 (most accurate):** `OFF ecoscore_data.agribalyse.co2_total` is present and > 0
```
co2Per100g (stored as gCO2e/100g) = agribalyse.co2_total × 100
source = 'off_api'
```

**Priority 2 (fallback):** OFF ecoscore absent → use shared category mapper
```
categoryKey  = mapOFFCategoryToFactorKey(offCategory)   ← shared function, single source of truth
co2Per100g   = FOOD_CATEGORY_FACTORS[categoryKey] × 10  (kgCO2e/kg → gCO2e/100g)
source       = 'category_fallback'
```

### Unit Contract for `co2Per100g`

**`co2Per100g` is ALWAYS stored and passed as `gCO2e per 100g` (unconverted raw value).** Both `estimateCO2ForServing()` and `calculateFoodItemCO2()` independently apply the `/1000` conversion to reach kgCO2e. This is intentional — each function is self-contained. Do not pre-convert before storing in `FoodEntry`.

```
estimateCO2ForServing(grams) = (co2Per100g / 1000) × (grams / 100)   → kgCO2e
```

### Category Mapper — Single Source of Truth

The function `mapOFFCategoryToFactorKey()` lives in `emissionFactors.js` and is imported by both `foodSearch.js` and `dailyLogProcessor.js`. **It must not be duplicated.**

Mapping priority order (first match wins):

| OFF tag contains… | Returns key | CO2 factor (kgCO2e/kg) |
|---|---|---|
| `beef` / `veal` | `beef` | 60.0 |
| `shrimp` / `prawn` | `shrimp_farmed` | 26.9 |
| `lamb` / `mutton` | `lamb_mutton` | 39.2 |
| `butter` | `butter` | 23.8 |
| `chocolate` | `chocolate` | 19.0 |
| `pork` / `pig` | `pork` | 12.3 |
| `chicken` / `poultry` | `poultry_chicken` | 9.9 |
| `fish` / `seafood` | `fish_wild` | 3.0 |
| `cheese` | `cheese` | 21.0 |
| `milk` / `dairy` | `milk_dairy` | 3.2 |
| `egg` | `eggs` | 4.5 |
| `yogurt` / `yoghurt` | `yogurt` | 2.9 |
| `tofu` / `soy` | `tofu` | 3.0 |
| `rice` | `rice_white` | 4.0 |
| `pasta` / `noodle` | `pasta` | 1.9 |
| `bread` / `wheat` | `wheat_bread` | 1.6 |
| `legume` / `lentil` / `bean` | `legumes_dried` | 0.9 |
| `nut` / `almond` | `nuts_mixed` | 2.3 |
| `coffee` | `coffee_brewed` | 17.0 |
| `tea` | `tea` | 3.5 |
| `potato` | `potatoes` | 0.46 |
| `vegetable` | `vegetables_avg` | 0.4 |
| `fruit` | `fruit_avg` | 0.7 |
| *(no match)* | `vegetables_avg` | 0.4 &nbsp;← safe underestimate fallback |

---

## 2.5 &nbsp;Daily Log Processor — `processDailyLog()`

### Inputs (DailyLog)

| Field | Type | Notes |
|---|---|---|
| `transport` | `TransportEntry[]` | One entry per journey leg. Empty array = zero transport day. |
| `food` | `FoodEntry[]` | One entry per food item across all meal slots. |
| `energy` | `EnergyLog` | `{ deviations: string[], confirmed: boolean }` |
| `date` | string | ISO date `'YYYY-MM-DD'` |
| `userProfile` | `UserProfile` | From `processSignUpProfile()`, read from DB. |
| `streakDays` | number | Current streak length — used for XP multiplier. |

### Transport CO2 Calculation

Per leg:
- **`mode === 'my_car'` or `useProfile=true`:** `factor = userProfile.transportFactor`
- **Any other mode:** `factor = TRANSPORT_FACTORS[entry.mode] ?? TRANSPORT_FACTORS.bus`
- `legCO2 = factor × distanceKm`

```
transportCO2 = sum of all legCO2 values
```

### Food CO2 Calculation

Per food item, the resolution chain (same priority as `foodSearch.js`):
- **`co2Per100g` present (gCO2e/100g):** `itemCO2 = (co2Per100g / 1000) × (servingGrams / 100)`
- **`co2Per100g` absent:** `categoryKey = mapOFFCategoryToFactorKey(offCategory)` then `itemCO2 = (FOOD_CATEGORY_FACTORS[categoryKey] / 10) × (servingGrams / 100)`

```
foodCO2 = sum of all itemCO2 values
```

### Energy CO2 Calculation

**Step 1 — Apply deviations to electricity baseline:**
```
deltaKwh = sum of ENERGY_DEVIATION_KWH[key] for each key in deviations[]
totalKwh = max(0, dailyEnergyBaselineKwh + deltaKwh)
```
Solar deviation tags (`solar_panels_sunny`/`cloudy`) are only available to `hasSolar=false` users (enforced in UI).

**Step 2 — Electricity CO2:**
```
electricityCO2 = totalKwh × gridIntensity
```

**Step 3 — Add heating CO2 (constant from profile):**
```
energyCO2 = electricityCO2 + userProfile.dailyHeatingBaselineCO2
```

### XP Calculation (aligned with gamification spec)

**Base XP from logging:**
- Full log (all 3 categories + `energy.confirmed=true`): **50 XP**
- Partial log (1–2 categories): **20 XP**

**Streak multiplier** (applied to base XP only):

| Streak length | Multiplier |
|---|---|
| 1–6 days | ×1.0 |
| 7–29 days | ×1.25 |
| 30+ days | ×1.5 |

**Performance bonus** (stacks on top, not multiplied):
- ≥ 30% below baseline: +25 XP
- ≥ 15% below baseline: +15 XP
- ≥ 5% below baseline: +8 XP

```
finalXP = round(baseXP × streakMultiplier) + performanceBonus
```

### Daily Result Output

| Field | Unit | Purpose |
|---|---|---|
| `transportCO2` | kgCO2e | Dashboard category card |
| `foodCO2` | kgCO2e | Dashboard category card |
| `energyCO2` | kgCO2e | Dashboard category card |
| `totalDailyCO2` | kgCO2e | Dashboard ring chart |
| `baselineCO2` | kgCO2e | Reference for delta |
| `co2SavedVsBaseline` | kgCO2e | +ve = better day; −ve = worse day |
| `percentVsBaseline` | % | Insights trend card |
| `equivalences.treeDaysAbsorbed` | days | `totalDailyCO2 / 0.0603` |
| `equivalences.carKmEquivalent` | km | `co2SavedVsBaseline / 0.18` |
| `equivalences.smartphoneCharges` | count | `co2SavedVsBaseline / 0.008` |
| `xpEarned` | XP | Gamification layer |
| `transportBreakdown` | array | Per-leg detail for Insights |
| `foodBreakdown` | array | Per-item detail with `mealSlot` |
| `foodByMealSlot` | object | Breakfast/lunch/dinner CO2 subtotals |
| `energyBreakdown` | object | kWh baseline, delta, total, CO2 |

---

## 2.6 &nbsp;CO2 Equivalence Formulas

| Metric | Formula | Basis |
|---|---|---|
| Tree-days absorbed | `savedKg / 0.0603` | 22 kg CO2 absorbed per tree per year ÷ 365 |
| Car-km equivalent | `savedKg / 0.18` | Average petrol car 180 gCO2/km |
| Smartphone charges | `savedKg / 0.008` | 8g CO2 per full smartphone charge |

> **Note:** Equivalences use `totalDailyCO2` for tree-days (showing today's footprint impact) and `co2SavedVsBaseline` for car-km and charges (showing the saving). Negative savings produce 0 — the card is hidden in the UI when the user exceeded their baseline.

---

## 2.7 &nbsp;Data Versioning & Updates

Emission factors will be updated annually as IEA and Poore & Nemecek data refreshes. The following policy applies:

- **`GRID_INTENSITY_BY_COUNTRY`:** Update annually from IEA Emissions Factors report. Trigger a `UserProfile` recompute for all users when the grid intensity of their country changes by > 5%.
- **`FOOD_CATEGORY_FACTORS`:** Stable — update only on major new meta-analysis publication. No user recompute required; only affects future logs.
- **`TRANSPORT_FACTORS`:** Update if DEFRA publishes material changes. No user recompute.
- **Heating factors:** Update annually. Trigger `UserProfile` recompute if a user's `heatingType` factor changes by > 10%.

All emission factor table versions should be stored with a version timestamp in the constants file header. The `DailyResult` object should store the `emissionFactorVersion` it was calculated with, to allow future recalculation audits.

---

## 2.8 &nbsp;Revision History

| Version | Date | Changes |
|---|---|---|
| 1.0 | May 2026 | Initial specification. All issues from Part I analysis resolved. Supersedes inline code comments. |

---

*NeutraWise Algorithm Specification &nbsp;|&nbsp; v1.0*
