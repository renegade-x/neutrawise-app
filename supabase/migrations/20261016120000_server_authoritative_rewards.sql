-- Make profile baselines, daily log calculations and game rewards server owned.
-- Existing migrations remain immutable; this migration supersedes their client
-- write paths while retaining the current table layout.

-- ---------------------------------------------------------------------------
-- Profile inputs are editable; calculated baseline fields are server-derived.
-- ---------------------------------------------------------------------------
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS monthly_energy_kwh numeric;
ALTER TABLE public.xp_ledger ADD COLUMN IF NOT EXISTS server_verified boolean NOT NULL DEFAULT false;
UPDATE public.users SET monthly_energy_kwh =
  daily_energy_baseline_kwh * 30 * GREATEST(COALESCE(residents, 1), 1)
    / CASE WHEN COALESCE(has_solar, false) THEN .75 ELSE 1 END
  WHERE monthly_energy_kwh IS NULL AND COALESCE(daily_energy_baseline_kwh, 0) > 0;

CREATE OR REPLACE FUNCTION public._profile_transport_factor(
  p_mode text, p_fuel text, p_engine text, p_age text, p_grid numeric
) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE
  v_base numeric := 0;
  v_size text := COALESCE(NULLIF(lower(btrim(p_engine)), ''), 'medium');
  v_age numeric := CASE lower(COALESCE(p_age, ''))
    WHEN 'pre_2010' THEN 1.15 WHEN '2020_plus' THEN 0.85 ELSE 1 END;
BEGIN
  CASE lower(COALESCE(p_mode, ''))
    WHEN 'car' THEN
      v_base := CASE lower(COALESCE(p_fuel, 'petrol'))
        WHEN 'diesel' THEN CASE v_size WHEN 'small' THEN .17 WHEN 'large' THEN .27 ELSE .22 END
        WHEN 'hybrid' THEN .12
        ELSE CASE v_size WHEN 'small' THEN .18 WHEN 'large' THEN .28 ELSE .23 END
      END;
      RETURN v_base * v_age;
    WHEN 'ev' THEN
      v_base := CASE v_size WHEN 'small' THEN .15 WHEN 'large' THEN .22 ELSE .18 END;
      RETURN v_base * COALESCE(p_grid, .45);
    WHEN 'motorcycle' THEN RETURN .10 * v_age;
    WHEN 'bus' THEN RETURN .089;
    WHEN 'train' THEN RETURN .041;
    WHEN 'metro' THEN RETURN .035;
    WHEN 'bicycle' THEN RETURN 0;
    WHEN 'walking' THEN RETURN 0;
    ELSE RETURN 0;
  END CASE;
END $$;
REVOKE ALL ON FUNCTION public._profile_transport_factor(text,text,text,text,numeric) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._food_factor(p_category text)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE c text := lower(btrim(COALESCE(p_category, '')));
BEGIN
  CASE
    WHEN c IN ('beef') OR c LIKE '%beef%' OR c LIKE '%veal%' OR c LIKE '%nihari%' OR c LIKE '%paye%' OR c LIKE '%chapli%' THEN RETURN 60.0;
    WHEN c IN ('shrimp_farmed') OR c LIKE '%shrimp%' OR c LIKE '%prawn%' THEN RETURN 26.9;
    WHEN c IN ('lamb_mutton') OR c LIKE '%lamb%' OR c LIKE '%mutton%' THEN RETURN 39.2;
    WHEN c IN ('butter') OR c LIKE '%butter%' OR c LIKE '%ghee%' THEN RETURN 23.8;
    WHEN c IN ('chocolate') OR c LIKE '%chocolate%' THEN RETURN 19.0;
    WHEN c IN ('pork') OR c LIKE '%pork%' OR c LIKE '%bacon%' THEN RETURN 12.3;
    WHEN c IN ('poultry_chicken') OR c LIKE '%chicken%' OR c LIKE '%poultry%' OR c LIKE '%seekh%' THEN RETURN 9.9;
    WHEN c IN ('fish_wild') OR c LIKE '%fish%' OR c LIKE '%seafood%' OR c LIKE '%machli%' THEN RETURN 3.0;
    WHEN c IN ('cheese') OR c LIKE '%cheese%' OR c LIKE '%paneer%' THEN RETURN 21.0;
    WHEN c IN ('milk_dairy') OR c LIKE '%milk%' OR c LIKE '%dairy%' OR c LIKE '%kheer%' OR c LIKE '%lassi%' THEN RETURN 3.2;
    WHEN c IN ('eggs') OR c LIKE '%egg%' OR c LIKE '%anda%' THEN RETURN 4.5;
    WHEN c IN ('yogurt') OR c LIKE '%yogurt%' OR c LIKE '%yoghurt%' OR c LIKE '%dahi%' OR c LIKE '%raita%' THEN RETURN 2.9;
    WHEN c IN ('tofu') OR c LIKE '%tofu%' OR c LIKE '%soy%' THEN RETURN 3.0;
    WHEN c IN ('rice_white') OR c LIKE '%rice%' OR c LIKE '%pulao%' OR c LIKE '%chawal%' OR c LIKE '%biryani%' THEN RETURN 4.0;
    WHEN c IN ('pasta') OR c LIKE '%pasta%' OR c LIKE '%noodle%' THEN RETURN 1.9;
    WHEN c IN ('wheat_bread') OR c LIKE '%grain%' OR c LIKE '%bread%' OR c LIKE '%wheat%' OR c LIKE '%roti%' OR c LIKE '%naan%' OR c LIKE '%paratha%' OR c LIKE '%puri%' OR c LIKE '%flour%' OR c LIKE '%halwa%' THEN RETURN 1.6;
    WHEN c IN ('legumes_dried') OR c LIKE '%legume%' OR c LIKE '%lentil%' OR c LIKE '%bean%' OR c LIKE '%daal%' OR c LIKE '%chana%' OR c LIKE '%haleem%' THEN RETURN .9;
    WHEN c IN ('nuts_mixed') OR c LIKE '%nut%' OR c LIKE '%almond%' OR c LIKE '%peanut%' OR c LIKE '%walnut%' THEN RETURN 2.3;
    WHEN c IN ('coffee_brewed') OR c LIKE '%coffee%' THEN RETURN 17.0;
    -- Substring matching "tea" also catches "steak".
    WHEN c IN ('tea', 'chai') OR c LIKE '% tea%' OR c LIKE 'tea %'
      OR c LIKE '% chai%' OR c LIKE 'chai %' THEN RETURN 3.5;
    WHEN c IN ('potatoes') OR c LIKE '%potato%' OR c LIKE '%aloo%' THEN RETURN .46;
    WHEN c IN ('fruit_avg') OR c LIKE '%fruit%' OR c LIKE '%apple%' OR c LIKE '%mango%' OR c LIKE '%banana%' OR c LIKE '%orange%' THEN RETURN .7;
    ELSE RETURN .4;
  END CASE;
END $$;
REVOKE ALL ON FUNCTION public._food_factor(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.recompute_profile_baselines()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_grid numeric;
  v_transport numeric;
  v_daily_kwh numeric;
  v_heat_kwh numeric;
  v_heat_factor numeric;
  v_heat numeric := 0;
  v_food numeric;
  v_residents integer := COALESCE(NEW.residents, 1);
BEGIN
  IF v_residents < 1 OR v_residents > 50 THEN
    RAISE EXCEPTION 'residents out of range' USING ERRCODE = '22023';
  END IF;
  NEW.residents := v_residents;
  IF COALESCE(NEW.avg_daily_km, 0) < 0 OR COALESCE(NEW.avg_daily_km, 0) > 1000 THEN
    RAISE EXCEPTION 'average daily distance out of range' USING ERRCODE = '22023';
  END IF;
  IF NEW.monthly_energy_kwh < 0 OR NEW.monthly_energy_kwh > 50000 THEN
    RAISE EXCEPTION 'monthly energy out of range' USING ERRCODE = '22023';
  END IF;

  v_grid := CASE upper(btrim(COALESCE(NEW.country_code, '')))
    WHEN 'PK' THEN .45 WHEN 'US' THEN .38 WHEN 'GB' THEN .25 WHEN 'DE' THEN .18 ELSE .45 END;
  v_transport := public._profile_transport_factor(
    NEW.primary_transport, NEW.fuel_type, NEW.engine_size, NEW.vehicle_age, v_grid);
  v_daily_kwh := CASE
    WHEN NEW.monthly_energy_kwh IS NOT NULL THEN NEW.monthly_energy_kwh / 30 / v_residents
    ELSE CASE NEW.home_type
      WHEN 'apartment_small' THEN 8 WHEN 'apartment_large' THEN 12
      WHEN 'house_small' THEN 15 WHEN 'house_medium' THEN 22 WHEN 'house_large' THEN 30
      ELSE 15 END / v_residents
  END;
  IF COALESCE(NEW.has_solar, false) THEN v_daily_kwh := v_daily_kwh * .75; END IF;

  IF lower(COALESCE(NEW.heating_type, '')) NOT IN ('electric', 'heat_pump') THEN
    v_heat_kwh := CASE NEW.home_type
      WHEN 'apartment_small' THEN 12 WHEN 'apartment_large' THEN 18
      WHEN 'house_small' THEN 25 WHEN 'house_medium' THEN 35 WHEN 'house_large' THEN 50
      ELSE 0 END;
    v_heat_factor := CASE lower(COALESCE(NEW.heating_type, ''))
      WHEN 'natural_gas' THEN .202 WHEN 'lpg' THEN .227 WHEN 'oil' THEN .268
      WHEN 'district' THEN .080 WHEN 'biomass_wood' THEN .015 WHEN 'coal' THEN .354 ELSE 0 END;
    v_heat := (v_heat_kwh * .667 / v_residents) * v_heat_factor;
  END IF;

  v_food := CASE lower(COALESCE(NEW.dietary_preference, ''))
    WHEN 'vegan' THEN 1.5 WHEN 'vegetarian' THEN 2.5 WHEN 'pescatarian' THEN 3.4
    WHEN 'flexitarian' THEN 4.2 WHEN 'omnivore' THEN 5.5 WHEN 'carnivore' THEN 7.2 ELSE 5.5 END;
  NEW.transport_factor := v_transport;
  NEW.grid_intensity := v_grid;
  NEW.daily_energy_baseline_kwh := v_daily_kwh;
  NEW.daily_heating_baseline_co2 := v_heat;
  NEW.daily_energy_baseline_co2 := (v_daily_kwh * v_grid) + v_heat;
  NEW.daily_food_baseline_co2 := v_food;
  NEW.total_daily_baseline_co2 :=
    (v_transport * COALESCE(NEW.avg_daily_km, 0)) + NEW.daily_energy_baseline_co2 + v_food;
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_recompute_profile_baselines ON public.users;
CREATE TRIGGER trg_recompute_profile_baselines
  BEFORE INSERT OR UPDATE OF primary_transport, fuel_type, engine_size, vehicle_age,
    avg_daily_km, home_type, residents, heating_type, has_solar, monthly_energy_kwh,
    dietary_preference, country_code
  ON public.users FOR EACH ROW EXECUTE FUNCTION public.recompute_profile_baselines();

-- The app may write profile inputs and preferences, never calculated baselines
-- or gamification state. Preserve the profile row's normal RLS policy.
REVOKE INSERT, UPDATE, DELETE ON public.users FROM PUBLIC, anon, authenticated;
GRANT INSERT (id, name, email, city, country_code, avatar_url, primary_transport,
  fuel_type, engine_size, vehicle_age, vehicle_model, avg_daily_km, home_type,
  residents, heating_type, has_solar, monthly_energy_kwh, dietary_preference,
  dark_mode_enabled, notifications_enabled, quiet_hours_start, quiet_hours_end)
  ON public.users TO authenticated;
GRANT UPDATE (id, name, email, city, country_code, avatar_url, primary_transport,
  fuel_type, engine_size, vehicle_age, vehicle_model, avg_daily_km, home_type,
  residents, heating_type, has_solar, monthly_energy_kwh, dietary_preference,
  dark_mode_enabled, notifications_enabled, quiet_hours_start, quiet_hours_end)
  ON public.users TO authenticated;

-- ---------------------------------------------------------------------------
-- Daily log writes contain only raw user inputs; triggers own derived values.
-- ---------------------------------------------------------------------------
ALTER TABLE public.daily_logs ADD COLUMN IF NOT EXISTS energy_confirmed boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.recompute_daily_log()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  u public.users%ROWTYPE;
  e jsonb;
  v_mode text;
  v_category text;
  v_distance numeric;
  v_grams numeric;
  v_factor numeric;
  v_item_co2 numeric;
  v_transport numeric := 0;
  v_food numeric := 0;
  v_energy numeric;
  v_delta numeric := 0;
  v_baseline numeric;
  v_total numeric;
  v_saved numeric;
  v_percent numeric;
  v_local_today date;
  v_entries jsonb := '[]'::jsonb;
  v_food_entries jsonb := '[]'::jsonb;
BEGIN
  SELECT * INTO u FROM public.users WHERE id = NEW.user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002'; END IF;
  v_local_today := ((now() AT TIME ZONE 'UTC') + make_interval(mins => COALESCE(u.utc_offset_minutes, 0)))::date;
  IF TG_OP = 'UPDATE' AND auth.uid() = OLD.user_id AND OLD.date < v_local_today
     AND EXISTS (SELECT 1 FROM public.xp_ledger x WHERE x.user_id = OLD.user_id
       AND x.source = 'daily_log' AND x.source_key = OLD.date::text AND x.amount > 0)
     AND (NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.date IS DISTINCT FROM OLD.date
       OR NEW.transport_entries IS DISTINCT FROM OLD.transport_entries
       OR NEW.food_entries IS DISTINCT FROM OLD.food_entries
       OR NEW.energy_deviations IS DISTINCT FROM OLD.energy_deviations
       OR NEW.energy_confirmed IS DISTINCT FROM OLD.energy_confirmed) THEN
    RAISE EXCEPTION 'rewarded activity logs are locked after the local day ends' USING ERRCODE = '22023';
  END IF;
  IF NEW.date IS NULL OR NEW.date > current_date + 1 THEN
    RAISE EXCEPTION 'invalid log date' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(COALESCE(NEW.transport_entries, '[]'::jsonb)) <> 'array'
     OR jsonb_typeof(COALESCE(NEW.food_entries, '[]'::jsonb)) <> 'array'
     OR jsonb_typeof(COALESCE(NEW.energy_deviations, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'activity entries must be arrays' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(COALESCE(NEW.transport_entries, '[]'::jsonb)) > 100
     OR jsonb_array_length(COALESCE(NEW.food_entries, '[]'::jsonb)) > 100
     OR jsonb_array_length(COALESCE(NEW.energy_deviations, '[]'::jsonb)) > 20 THEN
    RAISE EXCEPTION 'too many activity entries' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(COALESCE(NEW.energy_deviations, '[]'::jsonb)) > 0 THEN
    NEW.energy_confirmed := true;
  END IF;

  FOR e IN SELECT value FROM jsonb_array_elements(COALESCE(NEW.transport_entries, '[]'::jsonb)) LOOP
    v_mode := lower(btrim(COALESCE(e->>'mode', '')));
    IF v_mode NOT IN ('car', 'petrol_car', 'diesel_car', 'driving', 'ev', 'motorcycle',
      'bus', 'train', 'metro', 'bicycle', 'cycling', 'walking', 'tram', 'taxi', 'rideshare', 'ferry') THEN
      RAISE EXCEPTION 'unknown transport mode' USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(COALESCE(e->'distance_km', e->'distanceKm')) IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'transport distance is required' USING ERRCODE = '22023';
    END IF;
    v_distance := COALESCE(e->>'distance_km', e->>'distanceKm')::numeric;
    IF v_distance < 0 OR v_distance > 1000 THEN
      RAISE EXCEPTION 'transport distance out of range' USING ERRCODE = '22023';
    END IF;
    v_factor := CASE v_mode
      WHEN 'car' THEN CASE WHEN u.primary_transport = 'car' THEN u.transport_factor ELSE .23 END
      WHEN 'petrol_car' THEN CASE WHEN u.primary_transport = 'car' THEN u.transport_factor ELSE .23 END
      WHEN 'diesel_car' THEN CASE WHEN u.primary_transport = 'car' THEN u.transport_factor ELSE .23 END
      WHEN 'driving' THEN CASE WHEN u.primary_transport = 'car' THEN u.transport_factor ELSE .23 END
      WHEN 'ev' THEN CASE WHEN u.primary_transport = 'ev' THEN u.transport_factor ELSE COALESCE(u.grid_intensity, .45) * .18 END
      WHEN 'motorcycle' THEN CASE WHEN u.primary_transport = 'motorcycle' THEN u.transport_factor ELSE .10 END
      WHEN 'bus' THEN .089 WHEN 'train' THEN .041 WHEN 'metro' THEN .035
      WHEN 'bicycle' THEN 0 WHEN 'cycling' THEN 0 WHEN 'walking' THEN 0
      WHEN 'tram' THEN .035
      WHEN 'taxi' THEN .23 WHEN 'rideshare' THEN .115 WHEN 'ferry' THEN .10 ELSE 0 END;
    v_item_co2 := v_distance * COALESCE(v_factor, 0);
    v_transport := v_transport + v_item_co2;
    v_entries := v_entries || jsonb_build_array(
      (e - 'co2_per_100g') || jsonb_build_object('calculated_co2', v_item_co2));
  END LOOP;

  FOR e IN SELECT value FROM jsonb_array_elements(COALESCE(NEW.food_entries, '[]'::jsonb)) LOOP
    IF jsonb_typeof(e->'grams') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'food grams are required' USING ERRCODE = '22023';
    END IF;
    v_grams := (e->>'grams')::numeric;
    IF v_grams < 0 OR v_grams > 100000 THEN
      RAISE EXCEPTION 'food grams out of range' USING ERRCODE = '22023';
    END IF;
    v_category := lower(btrim(COALESCE(e->>'category', '')));
    v_item_co2 := public._food_factor(v_category) * (v_grams / 1000);
    v_food := v_food + v_item_co2;
    v_food_entries := v_food_entries || jsonb_build_array(
      (e - 'co2_per_100g') || jsonb_build_object('calculated_co2', v_item_co2));
  END LOOP;

  IF COALESCE(NEW.energy_confirmed, false) THEN
    FOR e IN SELECT value FROM jsonb_array_elements(COALESCE(NEW.energy_deviations, '[]'::jsonb)) LOOP
      CASE lower(btrim(e #>> '{}'))
        WHEN 'typical_day' THEN v_delta := v_delta;
        WHEN 'more_than_usual' THEN v_delta := v_delta + 2.0;
        WHEN 'less_than_usual' THEN v_delta := v_delta - 2.0;
        WHEN 'no_ac' THEN v_delta := v_delta - 5.0;
        WHEN 'cold_showers' THEN v_delta := v_delta - 1.5;
        WHEN 'unplugged_devices' THEN v_delta := v_delta - .5;
        WHEN 'solar_panels_sunny' THEN v_delta := v_delta - 4.0;
        WHEN 'solar_panels_cloudy' THEN v_delta := v_delta - 1.5;
        WHEN 'low_screen_time' THEN v_delta := v_delta;
        WHEN 'ac_used' THEN v_delta := v_delta + 5.0;
        ELSE RAISE EXCEPTION 'unknown energy deviation' USING ERRCODE = '22023';
      END CASE;
    END LOOP;
  END IF;

  v_energy := GREATEST(0, COALESCE(u.daily_energy_baseline_kwh, 0) + v_delta)
    * COALESCE(u.grid_intensity, .45) + COALESCE(u.daily_heating_baseline_co2, 0);
  v_baseline := GREATEST(0, COALESCE(u.total_daily_baseline_co2, 0));
  v_total := v_transport + v_food + v_energy;
  v_saved := v_baseline - v_total;
  v_percent := CASE WHEN v_baseline > 0 THEN (v_saved / v_baseline) * 100 ELSE 0 END;

  NEW.transport_entries := v_entries;
  NEW.food_entries := v_food_entries;
  NEW.energy_deviations := COALESCE(NEW.energy_deviations, '[]'::jsonb);
  NEW.transport_co2 := v_transport;
  NEW.food_co2 := v_food;
  NEW.energy_co2 := v_energy;
  NEW.total_daily_co2 := v_total;
  NEW.baseline_co2 := v_baseline;
  NEW.co2_saved_vs_baseline := v_saved;
  NEW.percent_vs_baseline := v_percent;
  NEW.xp_earned := 0;
  NEW.emission_factor_version := 'server-1';
  NEW.server_timestamp := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_recompute_daily_log ON public.daily_logs;
CREATE TRIGGER trg_recompute_daily_log
  BEFORE INSERT OR UPDATE OF user_id, date, transport_entries, food_entries,
    energy_deviations, energy_confirmed
  ON public.daily_logs FOR EACH ROW EXECUTE FUNCTION public.recompute_daily_log();

REVOKE INSERT, UPDATE, DELETE ON public.daily_logs FROM PUBLIC, anon, authenticated;
GRANT INSERT (user_id, date, transport_entries, food_entries, energy_deviations,
  energy_confirmed, client_timestamp) ON public.daily_logs TO authenticated;
GRANT UPDATE (transport_entries, food_entries, energy_deviations,
  energy_confirmed, client_timestamp) ON public.daily_logs TO authenticated;

-- Recalculate stored baselines and log totals with the same server rules.
UPDATE public.users SET monthly_energy_kwh = monthly_energy_kwh;
UPDATE public.daily_logs SET
  energy_confirmed = COALESCE(energy_confirmed, false)
    OR jsonb_array_length(COALESCE(energy_deviations, '[]'::jsonb)) > 0,
  transport_entries = COALESCE(transport_entries, '[]'::jsonb),
  food_entries = COALESCE(food_entries, '[]'::jsonb),
  energy_deviations = COALESCE(energy_deviations, '[]'::jsonb);
UPDATE public.users u SET total_co2_saved = COALESCE((
  SELECT SUM(l.co2_saved_vs_baseline) FROM public.daily_logs l WHERE l.user_id = u.id
), 0);

-- ---------------------------------------------------------------------------
-- Rewards are computed from the saved log, with one idempotent amount per day.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.submit_log_rewards(date,boolean,int,numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.award_xp(text,text,int) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_log_rewards(p_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  u public.users%ROWTYPE;
  l public.daily_logs%ROWTYPE;
  v_local_date date;
  v_gap int;
  v_streak int;
  v_full int;
  v_held boolean;
  v_queued boolean;
  v_is_full boolean;
  v_streak_increased boolean := false;
  v_freeze_used boolean := false;
  v_freeze_awarded boolean := false;
  v_level_multiplier numeric := 1;
  v_streak_multiplier numeric := 1;
  v_log_xp int;
  v_milestone int := 0;
  v_log_delta int := 0;
  v_milestone_delta int := 0;
  v_saved_total numeric;
  v_last date;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  SELECT * INTO u FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002'; END IF;
  v_local_date := ((now() AT TIME ZONE 'UTC') + make_interval(mins => COALESCE(u.utc_offset_minutes, 0)))::date;
  IF p_date IS NULL OR p_date < v_local_date - 1 OR p_date > v_local_date THEN
    RAISE EXCEPTION 'log date out of range' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO l FROM public.daily_logs WHERE user_id = v_uid AND date = p_date FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'daily log not found' USING ERRCODE = 'P0002'; END IF;
  IF jsonb_array_length(COALESCE(l.transport_entries, '[]'::jsonb)) = 0
     AND jsonb_array_length(COALESCE(l.food_entries, '[]'::jsonb)) = 0
     AND NOT COALESCE(l.energy_confirmed, false) THEN
    RAISE EXCEPTION 'daily log has no activity' USING ERRCODE = '22023';
  END IF;

  v_is_full := jsonb_array_length(COALESCE(l.transport_entries, '[]'::jsonb)) > 0
    AND jsonb_array_length(COALESCE(l.food_entries, '[]'::jsonb)) > 0
    AND COALESCE(l.energy_confirmed, false);
  v_streak := CASE WHEN COALESCE(u.streak_days, 0) > 0 THEN u.streak_days ELSE COALESCE(u.current_streak, 0) END;
  v_full := COALESCE(u.full_log_streak_days, 0);
  v_held := COALESCE(u.streak_freeze_held, false);
  v_queued := COALESCE(u.streak_freeze_queued, false);
  v_last := u.last_log_date;

  IF u.last_log_date IS NULL THEN
    v_streak := 0;
    v_full := CASE WHEN v_is_full THEN 1 ELSE 0 END;
    v_last := p_date;
  ELSIF p_date > u.last_log_date THEN
    v_gap := p_date - u.last_log_date;
    IF v_gap = 1 THEN
      v_streak := v_streak + 1;
      v_streak_increased := true;
      IF v_is_full THEN v_full := v_full + 1; ELSE v_full := 0; END IF;
    ELSIF v_gap = 2 AND v_held THEN
      v_freeze_used := true;
      v_held := false;
      v_streak := v_streak + 1;
      v_streak_increased := true;
      IF v_is_full THEN v_full := v_full + 1; ELSE v_full := 0; END IF;
    ELSE
      v_streak := 0;
      v_full := CASE WHEN v_is_full THEN 1 ELSE 0 END;
    END IF;
    v_last := p_date;
  ELSIF p_date = u.last_log_date THEN
    -- A same-day edit may change the full-log run, but never increments streak.
    IF v_is_full AND v_full = 0 THEN v_full := 1; END IF;
    IF NOT v_is_full THEN v_full := 0; END IF;
  END IF;

  IF v_is_full THEN
    v_streak_multiplier := CASE WHEN COALESCE(u.full_log_streak_days, 0) >= 100 THEN 1.75
      WHEN COALESCE(u.full_log_streak_days, 0) >= 30 THEN 1.50
      WHEN COALESCE(u.full_log_streak_days, 0) >= 7 THEN 1.25 ELSE 1 END;
  END IF;
  v_level_multiplier := CASE WHEN COALESCE(u.level, 1) >= 9 THEN 1.20
    WHEN COALESCE(u.level, 1) >= 5 THEN 1.10 ELSE 1 END;
  v_log_xp := round((CASE WHEN v_is_full THEN 50 ELSE 20 END)
    * v_streak_multiplier * v_level_multiplier)::int;
  IF v_is_full THEN
    IF l.percent_vs_baseline >= 30 THEN v_log_xp := v_log_xp + 25;
    ELSIF l.percent_vs_baseline >= 15 THEN v_log_xp := v_log_xp + 15;
    ELSIF l.percent_vs_baseline >= 5 THEN v_log_xp := v_log_xp + 8;
    END IF;
  END IF;

  UPDATE public.users SET
    current_streak = v_streak, streak_days = v_streak,
    full_log_streak_days = v_full,
    longest_streak = GREATEST(COALESCE(longest_streak, 0), v_streak),
    last_log_date = v_last,
    streak_freeze_held = v_held, streak_freeze_queued = v_queued,
    streak_freeze_count = COALESCE(streak_freeze_count, 0) + CASE WHEN v_freeze_used THEN 1 ELSE 0 END,
    days_active = GREATEST(1, v_local_date - COALESCE(created_at::date, v_local_date) + 1),
    updated_at = now()
  WHERE id = v_uid;

  v_log_delta := public._apply_xp(v_uid, 'daily_log', p_date::text, v_log_xp, true);
  UPDATE public.xp_ledger SET server_verified = true
    WHERE user_id = v_uid AND source = 'daily_log' AND source_key = p_date::text;
  UPDATE public.daily_logs SET xp_earned = v_log_xp WHERE user_id = v_uid AND date = p_date;

  IF v_streak_increased THEN
    v_milestone := CASE v_streak WHEN 3 THEN 25 WHEN 7 THEN 75 WHEN 14 THEN 150
      WHEN 30 THEN 300 WHEN 60 THEN 600 WHEN 100 THEN 1000 ELSE 0 END;
    IF v_milestone > 0 THEN
      v_milestone_delta := public._apply_xp(v_uid, 'streak_milestone', v_streak::text, v_milestone, false);
      UPDATE public.xp_ledger SET server_verified = true
        WHERE user_id = v_uid AND source = 'streak_milestone' AND source_key = v_streak::text;
      IF v_milestone_delta > 0 AND v_streak = 30 THEN
        IF (SELECT level FROM public.users WHERE id = v_uid) >= 4 THEN v_held := true; v_freeze_awarded := true;
        ELSE v_queued := true; END IF;
      END IF;
    END IF;
  END IF;
  IF v_queued AND (SELECT level FROM public.users WHERE id = v_uid) >= 4 THEN
    v_held := true; v_queued := false; v_freeze_awarded := true;
  END IF;
  UPDATE public.users SET streak_freeze_held = v_held, streak_freeze_queued = v_queued WHERE id = v_uid;

  SELECT COALESCE(SUM(co2_saved_vs_baseline), 0) INTO v_saved_total
    FROM public.daily_logs WHERE user_id = v_uid;
  UPDATE public.users SET total_co2_saved = v_saved_total WHERE id = v_uid;
  PERFORM public.refresh_my_badges();
  SELECT * INTO u FROM public.users WHERE id = v_uid;
  RETURN jsonb_build_object(
    'lifetime_xp', u.lifetime_xp, 'monthly_xp', u.monthly_xp, 'level', u.level,
    'current_streak', u.current_streak, 'full_log_streak_days', u.full_log_streak_days,
    'longest_streak', u.longest_streak, 'last_log_date', u.last_log_date,
    'days_active', u.days_active, 'total_co2_saved', u.total_co2_saved,
    'streak_freeze_held', u.streak_freeze_held, 'streak_freeze_queued', u.streak_freeze_queued,
    'freeze_used', v_freeze_used, 'freeze_awarded', v_freeze_awarded,
    'streak_increased', v_streak_increased, 'milestone_xp', v_milestone, 'log_xp_delta', v_log_delta);
END $$;
REVOKE ALL ON FUNCTION public.submit_log_rewards(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_log_rewards(date) TO authenticated;

-- Weekly leaderboard XP comes from the protected ledger, not a client-writable log column.
CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_type text DEFAULT 'global', p_city text DEFAULT NULL, p_limit int DEFAULT 100
)
RETURNS TABLE (id uuid, name text, avatar_url text, xp int, level int, rank int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH lim AS (SELECT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 100) AS n)
  SELECT * FROM (
    SELECT u.id, u.name::text, u.avatar_url::text, COALESCE(u.xp, 0)::int AS xp,
      COALESCE(u.level, 1)::int AS level,
      ROW_NUMBER() OVER (ORDER BY COALESCE(u.xp, 0) DESC, u.id)::int AS rank
    FROM public.users u WHERE auth.uid() IS NOT NULL AND COALESCE(p_type, 'global') = 'global'
    UNION ALL
    SELECT u.id, u.name::text, u.avatar_url::text, COALESCE(u.xp, 0)::int,
      COALESCE(u.level, 1)::int,
      ROW_NUMBER() OVER (ORDER BY COALESCE(u.xp, 0) DESC, u.id)::int
    FROM public.users u WHERE auth.uid() IS NOT NULL AND p_type = 'city'
      AND NULLIF(btrim(p_city), '') IS NOT NULL
      AND lower(btrim(u.city)) = lower(btrim(p_city))
    UNION ALL
    SELECT u.id, u.name::text, u.avatar_url::text, s.week_xp::int,
      COALESCE(u.level, 1)::int,
      ROW_NUMBER() OVER (ORDER BY s.week_xp DESC, u.id)::int
    FROM (
      SELECT x.user_id, SUM(x.amount) AS week_xp
      FROM public.xp_ledger x
      WHERE x.source = 'daily_log' AND x.server_verified
        AND x.source_key::date >= date_trunc('week', current_date)::date
        AND x.source_key::date <= current_date
      GROUP BY x.user_id
    ) s JOIN public.users u ON u.id = s.user_id
    WHERE auth.uid() IS NOT NULL AND p_type = 'weekly_sprint'
  ) ranked ORDER BY ranked.rank LIMIT (SELECT n FROM lim);
$$;
REVOKE ALL ON FUNCTION public.get_leaderboard(text,text,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text,text,int) TO authenticated;

-- ---------------------------------------------------------------------------
-- Challenges are enrolled, audited and completed by the database.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert their own challenges" ON public.user_challenges;
DROP POLICY IF EXISTS "Users can update their own challenges" ON public.user_challenges;
REVOKE INSERT, UPDATE, DELETE ON public.user_challenges FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_challenges TO authenticated;

DROP POLICY IF EXISTS "Users can manage own challenge daily progress" ON public.challenge_daily_progress;
DROP POLICY IF EXISTS "Users can read own challenge daily progress" ON public.challenge_daily_progress;
CREATE POLICY "Users can read own challenge daily progress" ON public.challenge_daily_progress
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
REVOKE INSERT, UPDATE, DELETE ON public.challenge_daily_progress FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.challenge_daily_progress TO authenticated;

DROP POLICY IF EXISTS "Users insert own challenge completions" ON public.challenge_completions;
REVOKE INSERT, UPDATE, DELETE ON public.challenge_completions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.challenge_completions TO authenticated;
ALTER TABLE public.challenge_completions
  ADD COLUMN IF NOT EXISTS server_verified boolean NOT NULL DEFAULT false;

-- Rows written under the old client policies cannot be evidence for server
-- rewards. Restart active challenges from this migration boundary using the
-- current catalog rules, and clear client-supplied daily qualification flags.
DELETE FROM public.challenge_daily_progress;
UPDATE public.user_challenges uc SET
  challenge_name = c.name,
  category = c.category,
  difficulty = c.difficulty,
  duration_days = c.duration_days,
  required_days = c.required_days,
  consecutive = COALESCE(c.consecutive, false),
  strategy = c.strategy,
  completion_criteria = COALESCE(c.completion_criteria, '{}'::jsonb),
  xp_reward = c.xp_reward,
  started_at = CASE WHEN uc.status = 'in_progress' AND uc.completed_at IS NULL THEN now() ELSE uc.started_at END,
  progress_percent = CASE WHEN uc.status = 'in_progress' AND uc.completed_at IS NULL THEN 0 ELSE uc.progress_percent END,
  days_passed = CASE WHEN uc.status = 'in_progress' AND uc.completed_at IS NULL THEN 0 ELSE uc.days_passed END,
  last_audited_date = CASE WHEN uc.status = 'in_progress' AND uc.completed_at IS NULL THEN NULL ELSE uc.last_audited_date END,
  xp_earned = CASE WHEN uc.status = 'in_progress' AND uc.completed_at IS NULL THEN 0 ELSE uc.xp_earned END
FROM public.challenges c WHERE c.id = uc.challenge_id;

CREATE OR REPLACE FUNCTION public.enroll_my_challenge(p_challenge_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  u public.users%ROWTYPE;
  c public.challenges%ROWTYPE;
  v_slots int;
  v_active int;
  v_local_today date;
  v_row public.user_challenges%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  SELECT * INTO u FROM public.users WHERE id = v_uid FOR UPDATE;
  SELECT * INTO c FROM public.challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'challenge not found' USING ERRCODE = 'P0002'; END IF;
  v_local_today := ((now() AT TIME ZONE 'UTC') + make_interval(mins => COALESCE(u.utc_offset_minutes, 0)))::date;
  IF lower(COALESCE(c.completion_criteria->>'start_day', '')) = 'saturday'
     AND extract(isodow FROM v_local_today) <> 6 THEN
    RAISE EXCEPTION 'challenge must start on Saturday' USING ERRCODE = '22023';
  END IF;
  IF lower(c.difficulty) = 'hard' AND COALESCE(u.level, 1) < 6 THEN
    RAISE EXCEPTION 'hard challenges require level 6' USING ERRCODE = '22023';
  END IF;
  v_slots := CASE WHEN u.level >= 9 THEN 4 WHEN u.level >= 6 THEN 3 WHEN u.level >= 4 THEN 2 ELSE 1 END;
  SELECT count(*) INTO v_active FROM public.user_challenges
    WHERE user_id = v_uid AND status = 'in_progress' AND completed_at IS NULL;
  IF v_active >= v_slots THEN
    RAISE EXCEPTION 'active challenge slot limit reached' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.user_challenges (
    user_id, challenge_id, challenge_name, category, difficulty, duration_days,
    required_days, consecutive, strategy, completion_criteria, xp_reward,
    started_at, completed_at, progress_percent, days_passed, status,
    completion_number, cooldown_ends_at, xp_earned, last_audited_date
  ) VALUES (
    v_uid, c.id, c.name, c.category, c.difficulty, c.duration_days,
    c.required_days, COALESCE(c.consecutive, false), c.strategy,
    COALESCE(c.completion_criteria, '{}'::jsonb), c.xp_reward,
    now(), NULL, 0, 0, 'in_progress',
    COALESCE((SELECT max(completion_num) FROM public.challenge_completions
      WHERE user_id = v_uid AND challenge_id = c.id AND server_verified), 0) + 1,
    NULL, 0, NULL
  )
  ON CONFLICT (user_id, challenge_id) DO UPDATE SET
    challenge_name = EXCLUDED.challenge_name,
    category = EXCLUDED.category,
    difficulty = EXCLUDED.difficulty,
    duration_days = EXCLUDED.duration_days,
    required_days = EXCLUDED.required_days,
    consecutive = EXCLUDED.consecutive,
    strategy = EXCLUDED.strategy,
    completion_criteria = EXCLUDED.completion_criteria,
    xp_reward = EXCLUDED.xp_reward,
    started_at = now(), completed_at = NULL, progress_percent = 0,
    days_passed = 0, status = 'in_progress', cooldown_ends_at = NULL,
    xp_earned = 0, last_audited_date = NULL
  WHERE public.user_challenges.status IN ('completed','failed')
    AND (public.user_challenges.cooldown_ends_at IS NULL OR public.user_challenges.cooldown_ends_at <= now())
  RETURNING * INTO v_row;
  IF NOT FOUND THEN RAISE EXCEPTION 'challenge is active or cooling down' USING ERRCODE = '22023'; END IF;
  RETURN to_jsonb(v_row);
END $$;
REVOKE ALL ON FUNCTION public.enroll_my_challenge(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enroll_my_challenge(text) TO authenticated;

CREATE OR REPLACE FUNCTION public._challenge_day_qualifies(
  p_strategy text, p_criteria jsonb, p_transport jsonb, p_food jsonb,
  p_energy jsonb, p_energy_confirmed boolean
) RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE
  v_accept text[] := ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_criteria->'accepted_values', '[]'::jsonb)));
  v_exclude text[] := ARRAY(SELECT jsonb_array_elements_text(COALESCE(p_criteria->'excluded_values', '[]'::jsonb)));
  v_tag text := lower(COALESCE(p_criteria->>'tag', ''));
  v_count int;
  v_match boolean;
  v_sum numeric;
  v_cat text;
BEGIN
  IF jsonb_array_length(COALESCE(p_transport, '[]'::jsonb)) = 0
     AND jsonb_array_length(COALESCE(p_food, '[]'::jsonb)) = 0
     AND NOT COALESCE(p_energy_confirmed, false) THEN
    RETURN false;
  END IF;
  CASE p_strategy
    WHEN 'APP_BEHAVIOR' THEN RETURN true;
    WHEN 'LOG_FIELD_ZERO' THEN
      IF COALESCE(p_criteria->>'field', '') <> 'car_km' THEN RETURN false; END IF;
      SELECT COALESCE(SUM(COALESCE(x->>'distance_km', x->>'distanceKm')::numeric), 0) INTO v_sum
        FROM jsonb_array_elements(COALESCE(p_transport, '[]'::jsonb)) x
       WHERE lower(COALESCE(x->>'mode','')) IN ('car','petrol_car','diesel_car','driving','ev','motorcycle','taxi','rideshare');
      RETURN COALESCE(v_sum, 0) = 0;
    WHEN 'TRANSPORT_ANY_MATCH' THEN
      SELECT count(*) > 0 INTO v_match FROM jsonb_array_elements(COALESCE(p_transport, '[]'::jsonb)) x
       WHERE (CASE lower(COALESCE(x->>'mode','')) WHEN 'bicycle' THEN 'cycling' ELSE lower(COALESCE(x->>'mode','')) END) = ANY(v_accept)
         AND COALESCE(x->>'distance_km', x->>'distanceKm')::numeric > 0;
      RETURN COALESCE(v_match, false);
    WHEN 'TRANSPORT_ALL_MATCH' THEN
      SELECT count(*), COALESCE(bool_and(
        (CASE lower(COALESCE(x->>'mode','')) WHEN 'bicycle' THEN 'cycling' ELSE lower(COALESCE(x->>'mode','')) END) = ANY(v_accept)
        AND COALESCE(x->>'distance_km', x->>'distanceKm')::numeric > 0), false)
        INTO v_count, v_match FROM jsonb_array_elements(COALESCE(p_transport, '[]'::jsonb)) x;
      RETURN v_count > 0 AND v_match;
    WHEN 'FOOD_NONE_MATCH' THEN
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(p_food, '[]'::jsonb)) x
        WHERE COALESCE((x->>'grams')::numeric, 0) > 0) THEN RETURN false; END IF;
      FOR v_cat IN SELECT lower(replace(COALESCE(x->>'category',''), '_', ' '))
        FROM jsonb_array_elements(COALESCE(p_food, '[]'::jsonb)) x
        WHERE COALESCE((x->>'grams')::numeric, 0) > 0 LOOP
        IF EXISTS (SELECT 1 FROM unnest(v_exclude) e WHERE v_cat LIKE '%' || lower(e) || '%') THEN RETURN false; END IF;
      END LOOP;
      RETURN true;
    WHEN 'FOOD_ALL_MATCH' THEN
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(p_food, '[]'::jsonb)) x
        WHERE COALESCE((x->>'grams')::numeric, 0) > 0) THEN RETURN false; END IF;
      FOR v_cat IN SELECT lower(replace(COALESCE(x->>'category',''), '_', ' '))
        FROM jsonb_array_elements(COALESCE(p_food, '[]'::jsonb)) x
        WHERE COALESCE((x->>'grams')::numeric, 0) > 0 LOOP
        v_cat := CASE
          WHEN v_cat LIKE '%vegetable%' THEN 'vegetables'
          WHEN v_cat LIKE '%legume%' THEN 'legumes'
          WHEN v_cat LIKE '%tofu%' OR v_cat LIKE '%soy%' THEN 'tofu'
          WHEN v_cat LIKE '%fruit%' THEN 'fruit'
          WHEN v_cat LIKE '%grain%' OR v_cat LIKE '%rice%' OR v_cat LIKE '%pasta%' OR v_cat LIKE '%wheat%' OR v_cat LIKE '%bread%' THEN 'grains'
          WHEN v_cat LIKE '%nut%' THEN 'nuts'
          WHEN v_cat LIKE '%seed%' THEN 'seeds'
          ELSE v_cat END;
        IF NOT (v_cat = ANY(v_accept)) THEN RETURN false; END IF;
      END LOOP;
      RETURN true;
    WHEN 'LOG_TAG_PRESENT' THEN
      IF NOT COALESCE(p_energy_confirmed, false) THEN RETURN false; END IF;
      RETURN EXISTS (SELECT 1 FROM jsonb_array_elements_text(COALESCE(p_energy, '[]'::jsonb)) x
        WHERE lower(x) = v_tag OR (v_tag = 'cold_shower' AND lower(x) = 'cold_showers')
          OR (v_tag = 'cold_showers' AND lower(x) = 'cold_shower'));
    WHEN 'LOG_TAG_ABSENT' THEN
      IF NOT COALESCE(p_energy_confirmed, false) THEN RETURN false; END IF;
      RETURN NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(COALESCE(p_energy, '[]'::jsonb)) x
        WHERE lower(x) = v_tag OR (v_tag = 'ac' AND lower(x) = 'ac_used'));
    ELSE RETURN false;
  END CASE;
END $$;
REVOKE ALL ON FUNCTION public._challenge_day_qualifies(text,jsonb,jsonb,jsonb,jsonb,boolean) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.audit_my_challenges()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  u public.users%ROWTYPE;
  r record;
  l public.daily_logs%ROWTYPE;
  v_local_today date;
  v_start date;
  v_end date;
  v_last_audited date;
  v_day date;
  v_passed int;
  v_run int;
  v_qualified boolean;
  v_completed boolean;
  v_failed boolean;
  v_completion_num int;
  v_completion_id bigint;
  v_xp int;
  v_cooldown int;
  v_completed_rows jsonb := '[]'::jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  SELECT * INTO u FROM public.users WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002'; END IF;
  v_local_today := ((now() AT TIME ZONE 'UTC') + make_interval(mins => COALESCE(u.utc_offset_minutes, 0)))::date;

  FOR r IN
    SELECT uc.id, uc.challenge_id, uc.started_at, uc.status, c.name, c.category,
      c.difficulty, c.duration_days, c.required_days, c.consecutive, c.strategy,
      c.completion_criteria, c.xp_reward
    FROM public.user_challenges uc JOIN public.challenges c ON c.id = uc.challenge_id
    WHERE uc.user_id = v_uid AND uc.status = 'in_progress' AND uc.completed_at IS NULL
    ORDER BY uc.started_at FOR UPDATE OF uc
  LOOP
    v_start := ((r.started_at AT TIME ZONE 'UTC') + make_interval(mins => COALESCE(u.utc_offset_minutes, 0)))::date;
    v_end := v_start + GREATEST(COALESCE(r.duration_days, 1), 1) - 1;
    v_last_audited := LEAST(v_local_today - 1, v_end);
    v_passed := 0;
    v_run := 0;
    v_completed := false;
    v_failed := false;

    IF v_last_audited >= v_start THEN
      FOR v_day IN SELECT d::date FROM generate_series(
        v_start::timestamp, v_last_audited::timestamp, interval '1 day') AS d LOOP
        SELECT * INTO l FROM public.daily_logs WHERE user_id = v_uid AND date = v_day;
        v_qualified := FOUND AND EXISTS (SELECT 1 FROM public.xp_ledger x
          WHERE x.user_id = v_uid AND x.source = 'daily_log' AND x.source_key = v_day::text
            AND x.amount > 0 AND x.server_verified)
          AND public._challenge_day_qualifies(
          r.strategy, COALESCE(r.completion_criteria, '{}'::jsonb),
          COALESCE(l.transport_entries, '[]'::jsonb), COALESCE(l.food_entries, '[]'::jsonb),
          COALESCE(l.energy_deviations, '[]'::jsonb), COALESCE(l.energy_confirmed, false));
        INSERT INTO public.challenge_daily_progress(user_id, challenge_id, date, qualified)
          VALUES (v_uid, r.challenge_id, v_day, v_qualified)
          ON CONFLICT (user_id, challenge_id, date) DO UPDATE SET qualified = EXCLUDED.qualified;
        IF v_qualified THEN v_passed := v_passed + 1; v_run := v_run + 1;
        ELSIF COALESCE(r.consecutive, false) THEN v_run := 0;
        END IF;
        IF (CASE WHEN COALESCE(r.consecutive, false) THEN v_run ELSE v_passed END) >= GREATEST(COALESCE(r.required_days,1),1) THEN
          v_completed := true; EXIT;
        END IF;
      END LOOP;
    END IF;

    -- Today's qualification is recorded for UI feedback, then finalized after
    -- the local day closes so a same-day edit cannot retain a false completion.
    IF v_local_today <= v_end THEN
      SELECT * INTO l FROM public.daily_logs WHERE user_id = v_uid AND date = v_local_today;
      v_qualified := FOUND AND EXISTS (SELECT 1 FROM public.xp_ledger x
        WHERE x.user_id = v_uid AND x.source = 'daily_log' AND x.source_key = v_local_today::text
          AND x.amount > 0 AND x.server_verified)
        AND public._challenge_day_qualifies(
        r.strategy, COALESCE(r.completion_criteria, '{}'::jsonb),
        COALESCE(l.transport_entries, '[]'::jsonb), COALESCE(l.food_entries, '[]'::jsonb),
        COALESCE(l.energy_deviations, '[]'::jsonb), COALESCE(l.energy_confirmed, false));
      INSERT INTO public.challenge_daily_progress(user_id, challenge_id, date, qualified)
        VALUES (v_uid, r.challenge_id, v_local_today, v_qualified)
        ON CONFLICT (user_id, challenge_id, date) DO UPDATE SET qualified = EXCLUDED.qualified;
    END IF;

    IF NOT v_completed AND v_local_today > v_end THEN v_failed := true; END IF;
    IF v_completed THEN
      SELECT count(*) + 1 INTO v_completion_num FROM public.challenge_completions
        WHERE user_id = v_uid AND challenge_id = r.challenge_id AND server_verified;
      v_xp := round(COALESCE(r.xp_reward, 100) * GREATEST(.50, 1 - .10 * (v_completion_num - 1)))::int;
      v_cooldown := CASE lower(r.difficulty)
        WHEN 'hard' THEN 90 WHEN 'medium' THEN 30
        WHEN 'easy' THEN CASE WHEN r.duration_days = 1 THEN 7 ELSE 14 END ELSE 7 END;
      UPDATE public.user_challenges SET status = 'completed', completed_at = now(),
        days_passed = GREATEST(COALESCE(r.required_days,1),1), progress_percent = 100,
        completion_number = v_completion_num, xp_earned = v_xp,
        cooldown_ends_at = now() + make_interval(days => v_cooldown),
        last_audited_date = v_last_audited
        WHERE id = r.id;
      INSERT INTO public.challenge_completions(user_id, challenge_id, completed_at, xp_awarded, completion_num, server_verified)
        VALUES (v_uid, r.challenge_id, now(), v_xp, v_completion_num, true)
        RETURNING id INTO v_completion_id;
      PERFORM public._apply_xp(v_uid, 'challenge', r.challenge_id || ':server:' || v_completion_id::text, v_xp, false);
      UPDATE public.xp_ledger SET server_verified = true
        WHERE user_id = v_uid AND source = 'challenge'
          AND source_key = r.challenge_id || ':server:' || v_completion_id::text;
      v_completed_rows := v_completed_rows || jsonb_build_array(jsonb_build_object(
        'challenge_id', r.challenge_id, 'name', r.name, 'xp_earned', v_xp));
    ELSE
      UPDATE public.user_challenges SET
        status = CASE WHEN v_failed THEN 'failed' ELSE status END,
        days_passed = CASE WHEN COALESCE(r.consecutive, false) THEN v_run ELSE v_passed END,
        progress_percent = LEAST(100, round(100.0 * (CASE WHEN COALESCE(r.consecutive, false) THEN v_run ELSE v_passed END)
          / GREATEST(COALESCE(r.required_days,1),1))::int),
        last_audited_date = v_last_audited
        WHERE id = r.id;
    END IF;
  END LOOP;
  PERFORM public.refresh_my_badges();
  RETURN v_completed_rows;
END $$;
REVOKE ALL ON FUNCTION public.audit_my_challenges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audit_my_challenges() TO authenticated;

-- ---------------------------------------------------------------------------
-- Badges are calculated from saved server state; clients can only read them.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert their own badges" ON public.badges;
DROP POLICY IF EXISTS "Users can upgrade their own badges" ON public.badges;
REVOKE INSERT, UPDATE, DELETE ON public.badges FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.badges TO authenticated;

CREATE OR REPLACE FUNCTION public._grant_badge(p_user uuid, p_name text, p_tier text, p_category text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.badges(user_id, badge_name, badge_tier, category)
  VALUES (p_user, p_name, p_tier, p_category)
  ON CONFLICT (user_id, badge_name) DO UPDATE SET
    badge_tier = EXCLUDED.badge_tier, category = EXCLUDED.category
  WHERE public.badges.badge_tier IS DISTINCT FROM EXCLUDED.badge_tier
     OR public.badges.category IS DISTINCT FROM EXCLUDED.category;
$$;
REVOKE ALL ON FUNCTION public._grant_badge(uuid,text,text,text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.refresh_my_badges()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  u public.users%ROWTYPE;
  v_rank int;
  r record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  SELECT * INTO u FROM public.users WHERE id = v_uid;
  IF NOT FOUND THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.daily_logs WHERE user_id = v_uid) THEN
    PERFORM public._grant_badge(v_uid, 'Eco Newcomer ✨', 'Special', 'Special');
  END IF;
  IF u.current_streak >= 7 THEN PERFORM public._grant_badge(v_uid, 'Week Warrior 🔥', 'Special', 'Special'); END IF;
  IF u.current_streak >= 14 THEN PERFORM public._grant_badge(v_uid, 'Fortnight Fighter 💪', 'Special', 'Special'); END IF;
  IF u.current_streak >= 30 THEN PERFORM public._grant_badge(v_uid, 'Monthly Maven 🌿', 'Special', 'Special'); END IF;
  IF u.current_streak >= 60 THEN PERFORM public._grant_badge(v_uid, 'Eco Consistent 🌍', 'Special', 'Special'); END IF;
  IF u.current_streak >= 100 THEN PERFORM public._grant_badge(v_uid, 'Century Eco 🏆', 'Special', 'Special'); END IF;
  IF u.level >= 10 THEN PERFORM public._grant_badge(v_uid, 'Carbon Neutral 🌍', 'Special', 'Special'); END IF;
  IF COALESCE(u.streak_freeze_count, 0) > 0 THEN PERFORM public._grant_badge(v_uid, 'Streak Saver 🛡️', 'Special', 'Special'); END IF;
  IF (SELECT count(*) FROM public.user_quizzes WHERE user_id = v_uid AND is_perfect) >= 5 THEN
    PERFORM public._grant_badge(v_uid, 'Quiz Whiz 🧠', 'Special', 'Special');
  END IF;

  FOR r IN SELECT c.category, count(*) AS n
    FROM public.challenge_completions cc JOIN public.challenges c ON c.id = cc.challenge_id
    WHERE cc.user_id = v_uid AND cc.server_verified GROUP BY c.category LOOP
    IF lower(r.category) = 'transport' AND r.n >= 3 THEN
      PERFORM public._grant_badge(v_uid, 'Road to Green 🚗', CASE WHEN r.n >= 12 THEN 'Gold' WHEN r.n >= 7 THEN 'Silver' ELSE 'Bronze' END, 'Transport');
    ELSIF lower(r.category) = 'food' AND r.n >= 3 THEN
      PERFORM public._grant_badge(v_uid, 'Conscious Plate 🥗', CASE WHEN r.n >= 12 THEN 'Gold' WHEN r.n >= 7 THEN 'Silver' ELSE 'Bronze' END, 'Food');
    ELSIF lower(r.category) = 'energy' AND r.n >= 3 THEN
      PERFORM public._grant_badge(v_uid, 'Power Saver ⚡', CASE WHEN r.n >= 12 THEN 'Gold' WHEN r.n >= 7 THEN 'Silver' ELSE 'Bronze' END, 'Energy');
    ELSIF lower(r.category) = 'nature' AND r.n >= 1 THEN
      PERFORM public._grant_badge(v_uid, 'Nature Keeper 🌳', CASE WHEN r.n >= 3 THEN 'Gold' WHEN r.n >= 2 THEN 'Silver' ELSE 'Bronze' END, 'Nature');
    END IF;
  END LOOP;

  IF (SELECT count(DISTINCT lower(c.category)) FROM public.challenge_completions cc
      JOIN public.challenges c ON c.id = cc.challenge_id WHERE cc.user_id = v_uid AND cc.server_verified) >= 4 THEN
    PERFORM public._grant_badge(v_uid, 'All-Rounder 🌟', 'Gold', 'Special');
  END IF;
  SELECT 1 + count(*) INTO v_rank FROM public.users other
    WHERE other.xp > u.xp OR (other.xp = u.xp AND other.id < v_uid);
  IF v_rank = 1 AND COALESCE(u.xp,0) > 0 THEN
    PERFORM public._grant_badge(v_uid, 'Leaderboard Leader 👑', 'Special', 'Special');
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.refresh_my_badges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_my_badges() TO authenticated;

-- ---------------------------------------------------------------------------
-- Quiz content is issued without answer keys; scoring and XP stay server-side.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.quiz_sessions (
  quiz_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  question_ids text[] NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, window_start)
);
ALTER TABLE public.quiz_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quiz_sessions FROM PUBLIC, anon, authenticated;

REVOKE SELECT ON public.quiz_questions, public.question_bank, public.quizzes FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.quiz_questions, public.question_bank, public.quizzes FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "Anyone can view quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Authenticated users can view quizzes" ON public.quizzes;

DROP POLICY IF EXISTS "Users can insert their own quiz attempts" ON public.user_quizzes;
DROP POLICY IF EXISTS "Users can manage own user_quizzes" ON public.user_quizzes;
REVOKE INSERT, UPDATE, DELETE ON public.user_quizzes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_quizzes TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_quiz_session()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_now timestamp without time zone := now() AT TIME ZONE 'UTC';
  v_monday timestamp without time zone;
  v_tuesday timestamp without time zone;
  v_friday timestamp without time zone;
  v_start timestamp without time zone;
  v_end timestamp without time zone;
  v_next timestamp without time zone;
  v_session public.quiz_sessions%ROWTYPE;
  v_question_ids text[];
  v_questions jsonb;
  v_attempt jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  v_monday := date_trunc('week', v_now);
  v_tuesday := v_monday + interval '1 day' + time '09:00';
  v_friday := v_monday + interval '4 days' + time '09:00';
  IF v_now >= v_tuesday AND v_now < v_tuesday + interval '48 hours' THEN
    v_start := v_tuesday; v_end := v_tuesday + interval '48 hours';
  ELSIF v_now >= v_friday AND v_now < v_friday + interval '48 hours' THEN
    v_start := v_friday; v_end := v_friday + interval '48 hours';
  ELSE
    IF v_now < v_tuesday THEN v_next := v_tuesday;
    ELSIF v_now < v_friday THEN v_next := v_friday;
    ELSE v_next := v_tuesday + interval '7 days'; END IF;
    RETURN jsonb_build_object('available', false, 'next_window_start', v_next AT TIME ZONE 'UTC');
  END IF;

  SELECT * INTO v_session FROM public.quiz_sessions
    WHERE user_id = v_uid AND window_start = (v_start AT TIME ZONE 'UTC');
  IF NOT FOUND THEN
    SELECT array_agg(q.id::text ORDER BY q.rn) INTO v_question_ids FROM (
      SELECT id, row_number() OVER (ORDER BY random()) AS rn
      FROM public.quiz_questions ORDER BY random() LIMIT 10
    ) q;
    IF COALESCE(cardinality(v_question_ids), 0) <> 10 THEN
      RAISE EXCEPTION 'quiz question bank is unavailable' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO public.quiz_sessions(user_id, window_start, window_end, question_ids)
      VALUES (v_uid, v_start AT TIME ZONE 'UTC', v_end AT TIME ZONE 'UTC', v_question_ids)
      ON CONFLICT (user_id, window_start) DO NOTHING;
    SELECT * INTO v_session FROM public.quiz_sessions
      WHERE user_id = v_uid AND window_start = (v_start AT TIME ZONE 'UTC');
  END IF;

  INSERT INTO public.quizzes(id, title, topic, questions, start_time, end_time)
    VALUES (v_session.quiz_id, 'Bi-Weekly Eco Quiz', 'Sustainability & Carbon Science',
      '[]'::jsonb, v_session.window_start, v_session.window_end)
    ON CONFLICT (id) DO NOTHING;

  SELECT jsonb_agg(jsonb_build_object(
      'id', q.id, 'category', q.category, 'text', q.question,
      'options', q.options
    ) ORDER BY x.ordinality)
    INTO v_questions
    FROM unnest(v_session.question_ids) WITH ORDINALITY AS x(id, ordinality)
    JOIN public.quiz_questions q ON q.id = x.id;
  SELECT (to_jsonb(a) - 'id') INTO v_attempt FROM public.user_quizzes a
    WHERE a.user_id = v_uid AND a.quiz_id = v_session.quiz_id;
  RETURN jsonb_build_object(
    'available', true, 'quiz_id', v_session.quiz_id,
    'title', 'Bi-Weekly Eco Quiz', 'topic', 'Sustainability & Carbon Science',
    'start_time', v_session.window_start, 'end_time', v_session.window_end,
    'questions', COALESCE(v_questions, '[]'::jsonb), 'attempt', v_attempt);
END $$;
REVOKE ALL ON FUNCTION public.get_my_quiz_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_quiz_session() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_my_quiz_attempt(p_quiz_id uuid, p_answers integer[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  s public.quiz_sessions%ROWTYPE;
  v_existing public.user_quizzes%ROWTYPE;
  v_score int := 0;
  v_total int;
  v_xp int;
  v_level int;
  v_options jsonb;
  v_correct int;
  i int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000'; END IF;
  SELECT * INTO s FROM public.quiz_sessions WHERE quiz_id = p_quiz_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'quiz session not found' USING ERRCODE = 'P0002'; END IF;
  SELECT * INTO v_existing FROM public.user_quizzes WHERE user_id = v_uid AND quiz_id = p_quiz_id;
  IF FOUND THEN RETURN to_jsonb(v_existing) - 'id'; END IF;
  IF now() < s.window_start OR now() >= s.window_end THEN
    RAISE EXCEPTION 'quiz window has ended' USING ERRCODE = '22023';
  END IF;
  v_total := cardinality(s.question_ids);
  IF p_answers IS NULL OR cardinality(p_answers) <> v_total THEN
    RAISE EXCEPTION 'answer count does not match quiz' USING ERRCODE = '22023';
  END IF;
  FOR i IN 1..v_total LOOP
    SELECT correct_index, options INTO v_correct, v_options
      FROM public.quiz_questions WHERE id = s.question_ids[i];
    IF NOT FOUND THEN
      RAISE EXCEPTION 'quiz question is unavailable' USING ERRCODE = 'P0002';
    END IF;
    IF p_answers[i] IS NULL OR p_answers[i] < 0 OR p_answers[i] >= jsonb_array_length(v_options) THEN
      RAISE EXCEPTION 'invalid quiz answer' USING ERRCODE = '22023';
    END IF;
    IF p_answers[i] = v_correct THEN v_score := v_score + 1; END IF;
  END LOOP;
  SELECT level INTO v_level FROM public.users WHERE id = v_uid FOR UPDATE;
  v_xp := 30 + (v_score * 5) + CASE WHEN v_score = v_total AND v_level >= 5 THEN 50 ELSE 0 END;
  INSERT INTO public.user_quizzes(user_id, quiz_id, score, total_questions, xp_earned,
    is_perfect, answers, completed_at)
  VALUES (v_uid, p_quiz_id, v_score, v_total, v_xp, v_score = v_total,
    to_jsonb(p_answers), now())
  ON CONFLICT (user_id, quiz_id) DO NOTHING;
  SELECT * INTO v_existing FROM public.user_quizzes WHERE user_id = v_uid AND quiz_id = p_quiz_id;
  IF v_existing.xp_earned > 0 THEN
    PERFORM public._apply_xp(v_uid, 'quiz', p_quiz_id::text, v_existing.xp_earned, false);
    UPDATE public.xp_ledger SET server_verified = true
      WHERE user_id = v_uid AND source = 'quiz' AND source_key = p_quiz_id::text;
  END IF;
  PERFORM public.refresh_my_badges();
  RETURN to_jsonb(v_existing) - 'id';
END $$;
REVOKE ALL ON FUNCTION public.submit_my_quiz_attempt(uuid,integer[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_my_quiz_attempt(uuid,integer[]) TO authenticated;
