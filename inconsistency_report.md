# NeutraWise Specification vs. Implementation Inconsistency Report

This document compiles the inconsistencies identified between the canonical specifications (`NeutraWise_Requirements.md`, `NeutraWise_Algorithm_Specification_v1.0.md`, `NeutraWise_Gamification_System.md`, `gap_analysis.md`) and the actual implementation in the Flutter codebase.

---

## 1. Onboarding & Authentication Flow

| Specification / Requirement | Actual Code Implementation | Severity |
| :--- | :--- | :--- |
| **Mascot Presence:** A friendly eco-themed mascot character should appear across all onboarding slides. | Uses standard Material Icons (`eco`, `military_tech`, `public`) rather than any mascot illustrations/graphics. | 🟢 **NOTE** |
| **Onboarding Slides Skip Logic:** "Skip" button should only be available on slides 1–4, and **not skippable** on the final slide. | The "Skip" button is rendered globally in the layout and remains visible/functional on the final slide. | 🟡 **WARNING** |
| **Onboarding Content Count:** Spec mentions 3–5 slides. | Exactly 3 slides are implemented. | 🟢 **NOTE** |

---

## 2. Profile Setup Screen

The Profile Setup Screen contains the most significant UI and input gaps compared to the specifications:

| Specification / Requirement | Actual Code Implementation | Severity |
| :--- | :--- | :--- |
| **Transport - "None" Option:** "None" option should be present; if selected, it skips all subsequent transport fields. | No "None" option exists in the primary transport dropdown list. | 🔴 **CRITICAL** |
| **Detailed Vehicle Fields:** Should prompt for vehicle fuel type, engine size (litres), and vehicle model (text input). | Omitted. The setup form only asks for the primary transport category and completely skips these details. | 🔴 **CRITICAL** |
| **Residency Details:** Should prompt for home type (Flat / Small House / Large House), number of residents (stepper), and heating type. | The home type list is reduced to just `apartment` or `house`. Residents are hardcoded to `2`, and heating type is hardcoded to `natural_gas` (no inputs). | 🔴 **CRITICAL** |
| **Electricity Usage Fallback:** Should prompt for monthly electricity usage with an "I don't know" option to fallback to a home-type lookup. | Omitted. The input field is a simple text input with no "I don't know" button or fallback lookup trigger. | 🟡 **WARNING** |
| **Dietary Preference Options:** Specify `Vegan / Vegetarian / Pescatarian / Flexitarian / Omnivore / Carnivore`. | The options are `meat_heavy`, `omnivore`, `pescatarian`, `vegetarian`, `vegan`. It misses `flexitarian` and uses `meat_heavy` instead of `carnivore`. | 🟡 **WARNING** |
| **Country Input:** Must collect the user's country code to determine grid intensity for EV and electricity baseline. | No country field is collected in the setup form; the calculator defaults to PK (`gridIntensityPK`). | 🔴 **CRITICAL** |

---

## 3. CO₂ Calculation Engine

| Specification / Requirement | Actual Code Implementation | Severity |
| :--- | :--- | :--- |
| **Transport Baseline Multipliers:** Vehicle age multipliers should map to `pre_2010`, `2010_2019`, and `2020_plus`. | The code maps multipliers to outdated ranges: `pre_2000` (1.15), `2000_2009` (1.05), `2010_2019` (0.95), and `post_2020` (0.85). | 🟡 **WARNING** |
| **Dietary baseline values:** Baseline daily emissions should be: vegan (1.5), vegetarian (2.5), pescatarian (3.4), flexitarian (4.2), omnivore (5.5), carnivore (7.2). | The code uses: `vegan` (2.9), `vegetarian` (3.8), `pescatarian` (4.0), `omnivore` (5.5), `meat_heavy` (7.2). | 🟡 **WARNING** |
| **Heating baseline calculation:** Calculate heating emissions based on home type, residents, and seasonal coefficients. | Omitted. It simply checks if heating is `natural_gas` and returns a flat/static `1.5` baseline. | 🔴 **CRITICAL** |
| **EV Factor Derivation:** Should never use a static global factor; it must calculate: `EV_EFFICIENCY_KWH_PER_KM[engineSize] × gridIntensity`. | The code uses `EmissionFactors.baseTransportFactors['ev_efficiency'] * EmissionFactors.gridIntensityPK`, neglecting the engine size variance. | 🟡 **WARNING** |

---

## 4. Gamification & XP System

| Specification / Requirement | Actual Code Implementation | Severity |
| :--- | :--- | :--- |
| **XP Multiplier Stacking:** final XP = `round(baseXP * streakMultiplier) + performanceBonus`. | The formula implemented in `CO2Calculator.processDailyLog` is: `(baseXP * streakMultiplier).round() + performanceBonus`. This is aligned, but the caps and limits are applied slightly differently. | 🟢 **NOTE** |
| **Streak Freeze Award:** Level 4 unlocks a Streak Freeze power-up, allowing a user to protect their streak. | The streak freeze mechanism is partially mocked in the UI and does not dynamically trigger streak saves on backend cron expirations. | 🟡 **WARNING** |
| **Leaderboard Reset cycles:** Global reset monthly; Weekly Sprint resets weekly (Mondays). | Implemented via database views / cron triggers, but client-side triggers don't explicitly refresh/simulate local timezone calculations for reset cycles. | 🟢 **NOTE** |
