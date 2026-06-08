/*
  ============================================================
  RailScooter / PiScoot Fleet Management — FULL DB REBUILD
  ============================================================

  HOW TO RUN:
  1. Go to Supabase Dashboard → SQL Editor → New Query
  2. Paste this ENTIRE file
  3. Click Run
  4. Done. All tables, policies, trigger, indexes, and sample
     data will be recreated from scratch.

  ⚠️  WARNING: This drops all existing data first.
      Only run this if you want a completely clean slate.
  ============================================================
*/

-- ─────────────────────────────────────────────────────────────
-- STEP 0: Tear down everything cleanly
-- ─────────────────────────────────────────────────────────────

-- Drop trigger & function first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_auth_user();

-- Drop tables in reverse-FK order (children before parents)
DROP TABLE IF EXISTS public.vehicle_alerts      CASCADE;
DROP TABLE IF EXISTS public.vehicle_tracking    CASCADE;
DROP TABLE IF EXISTS public.geofences           CASCADE;
DROP TABLE IF EXISTS public.alert_rules         CASCADE;
DROP TABLE IF EXISTS public.vehicle_assignments CASCADE;
DROP TABLE IF EXISTS public.vehicles            CASCADE;
DROP TABLE IF EXISTS public.app_users           CASCADE;
DROP TABLE IF EXISTS public.departments         CASCADE;


-- ─────────────────────────────────────────────────────────────
-- STEP 1: departments
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.departments (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text        NOT NULL,
  code            text        UNIQUE NOT NULL,
  description     text        NOT NULL DEFAULT '',
  head_name       text        NOT NULL DEFAULT '',
  contact_email   text        NOT NULL DEFAULT '',
  contact_phone   text        NOT NULL DEFAULT '',
  location        text        NOT NULL DEFAULT '',
  is_active       boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dept_select" ON public.departments FOR SELECT TO authenticated USING (true);
CREATE POLICY "dept_insert" ON public.departments FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "dept_update" ON public.departments FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "dept_delete" ON public.departments FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);


-- ─────────────────────────────────────────────────────────────
-- STEP 2: app_users  (profile table — linked to auth.users)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.app_users (
  id              uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name       text        NOT NULL DEFAULT '',
  employee_id     text        UNIQUE,
  role            text        NOT NULL DEFAULT 'trackman'
                              CHECK (role IN ('admin', 'trackman', 'manager', 'viewer')),
  department_id   uuid        REFERENCES public.departments(id) ON DELETE SET NULL,
  phone           text        NOT NULL DEFAULT '',
  avatar_url      text        NOT NULL DEFAULT '',
  is_active       boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select" ON public.app_users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert" ON public.app_users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "users_update" ON public.app_users FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);


-- ─────────────────────────────────────────────────────────────
-- STEP 3: Auto-create app_users row whenever someone signs up
--
--   SECURITY DEFINER = runs as DB superuser → bypasses RLS.
--   This is the canonical Supabase pattern and works even when
--   email confirmation is enabled (no client session needed).
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.app_users (id, full_name, role, is_active)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    ),
    CASE
      WHEN EXISTS (SELECT 1 FROM public.app_users) THEN 'trackman'
      ELSE 'admin'
    END,
    true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();


-- ─────────────────────────────────────────────────────────────
-- STEP 4: vehicles
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.vehicles (
  id                      uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id              text    UNIQUE NOT NULL,
  variant                 text    NOT NULL DEFAULT 'PiScoot',
  battery_type            text    NOT NULL DEFAULT 'LiFe',
  battery_capacity        text    NOT NULL DEFAULT '48V 25Ah',
  manufacturing_date      date,
  firmware_version        text    NOT NULL DEFAULT 'v1.0.0',
  last_maintenance_date   date,
  status                  text    NOT NULL DEFAULT 'active'
                                  CHECK (status IN ('active', 'idle', 'maintenance', 'offline')),
  gps_enabled             boolean NOT NULL DEFAULT true,
  trackman_enabled        boolean NOT NULL DEFAULT false,
  trackman_safety_enabled boolean NOT NULL DEFAULT false,
  notes                   text    NOT NULL DEFAULT '',
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vehicles_select" ON public.vehicles FOR SELECT TO authenticated USING (true);
CREATE POLICY "vehicles_insert" ON public.vehicles FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "vehicles_update" ON public.vehicles FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "vehicles_delete" ON public.vehicles FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);


-- ─────────────────────────────────────────────────────────────
-- STEP 5: vehicle_assignments
-- NOTE: Two separate FKs to app_users are given explicit names
--       so PostgREST can distinguish them (avoids PGRST201 error).
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.vehicle_assignments (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id          uuid        NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  department_id       uuid        REFERENCES public.departments(id) ON DELETE SET NULL,
  -- NOTE: assigned_user_id and assigned_by both reference app_users.
  -- We give them EXPLICIT constraint names so PostgREST can tell them apart.
  -- Flutter uses:  app_users!vehicle_assignments_assigned_user_id_fkey(...)
  assigned_user_id    uuid,
  assigned_by         uuid,
  assigned_at         timestamptz NOT NULL DEFAULT now(),
  unassigned_at       timestamptz,
  is_active           boolean     NOT NULL DEFAULT true,
  notes               text        NOT NULL DEFAULT '',
  created_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT vehicle_assignments_assigned_user_id_fkey
    FOREIGN KEY (assigned_user_id) REFERENCES public.app_users(id) ON DELETE SET NULL,
  CONSTRAINT vehicle_assignments_assigned_by_fkey
    FOREIGN KEY (assigned_by)      REFERENCES public.app_users(id) ON DELETE SET NULL
);

ALTER TABLE public.vehicle_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "assignments_select" ON public.vehicle_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "assignments_insert" ON public.vehicle_assignments FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "assignments_update" ON public.vehicle_assignments FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "assignments_delete" ON public.vehicle_assignments FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);


-- ─────────────────────────────────────────────────────────────
-- STEP 6: alert_rules
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.alert_rules (
  id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                    text        NOT NULL,
  description             text        NOT NULL DEFAULT '',
  rule_type               text        NOT NULL DEFAULT 'speed'
                                      CHECK (rule_type IN ('speed','battery','geofence','idle_time','movement')),
  severity                text        NOT NULL DEFAULT 'medium'
                                      CHECK (severity IN ('low','medium','high','critical')),
  condition_operator      text        NOT NULL DEFAULT 'gt'
                                      CHECK (condition_operator IN ('gt','lt','eq','gte','lte')),
  condition_value         numeric     NOT NULL DEFAULT 0,
  condition_unit          text        NOT NULL DEFAULT '',
  is_active               boolean     NOT NULL DEFAULT true,
  applies_to_all_vehicles boolean     NOT NULL DEFAULT true,
  notification_email      boolean     NOT NULL DEFAULT true,
  notification_push       boolean     NOT NULL DEFAULT true,
  notification_sms        boolean     NOT NULL DEFAULT false,
  created_by              uuid        REFERENCES public.app_users(id) ON DELETE SET NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.alert_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "alert_rules_select" ON public.alert_rules FOR SELECT TO authenticated USING (true);
CREATE POLICY "alert_rules_insert" ON public.alert_rules FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "alert_rules_update" ON public.alert_rules FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "alert_rules_delete" ON public.alert_rules FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);


-- ─────────────────────────────────────────────────────────────
-- STEP 7: geofences
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.geofences (
  id              uuid              PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text              NOT NULL,
  description     text              NOT NULL DEFAULT '',
  fence_type      text              NOT NULL DEFAULT 'operational'
                                    CHECK (fence_type IN ('operational','restricted','depot')),
  center_lat      double precision  NOT NULL DEFAULT 0,
  center_lng      double precision  NOT NULL DEFAULT 0,
  radius_meters   double precision  NOT NULL DEFAULT 500,
  polygon_points  jsonb,
  is_active       boolean           NOT NULL DEFAULT true,
  alert_on_enter  boolean           NOT NULL DEFAULT false,
  alert_on_exit   boolean           NOT NULL DEFAULT true,
  color_hex       text              NOT NULL DEFAULT '#F58220',
  department_id   uuid              REFERENCES public.departments(id) ON DELETE SET NULL,
  created_by      uuid              REFERENCES public.app_users(id) ON DELETE SET NULL,
  created_at      timestamptz       NOT NULL DEFAULT now(),
  updated_at      timestamptz       NOT NULL DEFAULT now()
);

ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "geofences_select" ON public.geofences FOR SELECT TO authenticated USING (true);
CREATE POLICY "geofences_insert" ON public.geofences FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "geofences_update" ON public.geofences FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "geofences_delete" ON public.geofences FOR DELETE TO authenticated USING (auth.uid() IS NOT NULL);


-- ─────────────────────────────────────────────────────────────
-- STEP 8: vehicle_tracking
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.vehicle_tracking (
  id               uuid             PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id       uuid             NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  latitude         double precision NOT NULL,
  longitude        double precision NOT NULL,
  speed_kmh        double precision NOT NULL DEFAULT 0,
  heading_degrees  double precision NOT NULL DEFAULT 0,
  battery_percent  integer          NOT NULL DEFAULT 100 CHECK (battery_percent BETWEEN 0 AND 100),
  is_online        boolean          NOT NULL DEFAULT true,
  signal_strength  integer          NOT NULL DEFAULT 100,
  recorded_at      timestamptz      NOT NULL DEFAULT now()
);

ALTER TABLE public.vehicle_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tracking_select" ON public.vehicle_tracking FOR SELECT TO authenticated USING (true);
CREATE POLICY "tracking_insert" ON public.vehicle_tracking FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);


-- ─────────────────────────────────────────────────────────────
-- STEP 9: vehicle_alerts
-- ─────────────────────────────────────────────────────────────

CREATE TABLE public.vehicle_alerts (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id       uuid        NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  alert_rule_id    uuid        REFERENCES public.alert_rules(id) ON DELETE SET NULL,
  alert_type       text        NOT NULL DEFAULT 'speed',
  severity         text        NOT NULL DEFAULT 'medium'
                               CHECK (severity IN ('low','medium','high','critical')),
  message          text        NOT NULL DEFAULT '',
  latitude         double precision,
  longitude        double precision,
  is_acknowledged  boolean     NOT NULL DEFAULT false,
  acknowledged_by  uuid        REFERENCES public.app_users(id) ON DELETE SET NULL,
  acknowledged_at  timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.vehicle_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "alerts_select" ON public.vehicle_alerts FOR SELECT TO authenticated USING (true);
CREATE POLICY "alerts_insert" ON public.vehicle_alerts FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "alerts_update" ON public.vehicle_alerts FOR UPDATE TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);


-- -------------------------------------------------------------
-- STEP 9B: Role and department-aware authorization
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.current_app_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.app_users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.current_app_user_department()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT department_id FROM public.app_users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.is_fleet_manager()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.current_app_user_role() IN ('admin', 'manager'), false)
$$;

CREATE OR REPLACE FUNCTION public.can_access_vehicle(target_vehicle_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_fleet_manager()
    OR EXISTS (
      SELECT 1
      FROM public.vehicle_assignments va
      WHERE va.vehicle_id = target_vehicle_id
        AND va.is_active
        AND (
          va.assigned_user_id = auth.uid()
          OR (
            public.current_app_user_department() IS NOT NULL
            AND va.department_id = public.current_app_user_department()
          )
        )
    )
$$;

CREATE OR REPLACE FUNCTION public.protect_app_user_authorization_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() = OLD.id
     AND NOT public.is_fleet_manager()
     AND (
       NEW.id IS DISTINCT FROM OLD.id
       OR NEW.role IS DISTINCT FROM OLD.role
       OR NEW.department_id IS DISTINCT FROM OLD.department_id
       OR NEW.employee_id IS DISTINCT FROM OLD.employee_id
       OR NEW.is_active IS DISTINCT FROM OLD.is_active
     )
  THEN
    RAISE EXCEPTION 'Only fleet managers can change authorization fields';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER protect_app_user_authorization_fields
  BEFORE UPDATE ON public.app_users
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_app_user_authorization_fields();

DROP POLICY "dept_select" ON public.departments;
DROP POLICY "dept_insert" ON public.departments;
DROP POLICY "dept_update" ON public.departments;
DROP POLICY "dept_delete" ON public.departments;
CREATE POLICY "dept_select" ON public.departments FOR SELECT TO authenticated
  USING (public.is_fleet_manager() OR id = public.current_app_user_department());
CREATE POLICY "dept_insert" ON public.departments FOR INSERT TO authenticated
  WITH CHECK (public.is_fleet_manager());
CREATE POLICY "dept_update" ON public.departments FOR UPDATE TO authenticated
  USING (public.is_fleet_manager()) WITH CHECK (public.is_fleet_manager());
CREATE POLICY "dept_delete" ON public.departments FOR DELETE TO authenticated
  USING (public.is_fleet_manager());

DROP POLICY "users_select" ON public.app_users;
DROP POLICY "users_update" ON public.app_users;
CREATE POLICY "users_select" ON public.app_users FOR SELECT TO authenticated
  USING (
    public.is_fleet_manager()
    OR id = auth.uid()
    OR (
      public.current_app_user_department() IS NOT NULL
      AND department_id = public.current_app_user_department()
    )
  );
CREATE POLICY "users_update" ON public.app_users FOR UPDATE TO authenticated
  USING (public.is_fleet_manager() OR id = auth.uid())
  WITH CHECK (public.is_fleet_manager() OR id = auth.uid());

DROP POLICY "vehicles_select" ON public.vehicles;
DROP POLICY "vehicles_insert" ON public.vehicles;
DROP POLICY "vehicles_update" ON public.vehicles;
DROP POLICY "vehicles_delete" ON public.vehicles;
CREATE POLICY "vehicles_select" ON public.vehicles FOR SELECT TO authenticated
  USING (public.can_access_vehicle(id));
CREATE POLICY "vehicles_insert" ON public.vehicles FOR INSERT TO authenticated
  WITH CHECK (public.is_fleet_manager());
CREATE POLICY "vehicles_update" ON public.vehicles FOR UPDATE TO authenticated
  USING (public.is_fleet_manager()) WITH CHECK (public.is_fleet_manager());
CREATE POLICY "vehicles_delete" ON public.vehicles FOR DELETE TO authenticated
  USING (public.is_fleet_manager());

DROP POLICY "assignments_select" ON public.vehicle_assignments;
DROP POLICY "assignments_insert" ON public.vehicle_assignments;
DROP POLICY "assignments_update" ON public.vehicle_assignments;
DROP POLICY "assignments_delete" ON public.vehicle_assignments;
CREATE POLICY "assignments_select" ON public.vehicle_assignments FOR SELECT TO authenticated
  USING (public.can_access_vehicle(vehicle_id));
CREATE POLICY "assignments_insert" ON public.vehicle_assignments FOR INSERT TO authenticated
  WITH CHECK (public.is_fleet_manager());
CREATE POLICY "assignments_update" ON public.vehicle_assignments FOR UPDATE TO authenticated
  USING (public.is_fleet_manager()) WITH CHECK (public.is_fleet_manager());
CREATE POLICY "assignments_delete" ON public.vehicle_assignments FOR DELETE TO authenticated
  USING (public.is_fleet_manager());

DROP POLICY "alert_rules_insert" ON public.alert_rules;
DROP POLICY "alert_rules_update" ON public.alert_rules;
DROP POLICY "alert_rules_delete" ON public.alert_rules;
CREATE POLICY "alert_rules_insert" ON public.alert_rules FOR INSERT TO authenticated
  WITH CHECK (public.is_fleet_manager());
CREATE POLICY "alert_rules_update" ON public.alert_rules FOR UPDATE TO authenticated
  USING (public.is_fleet_manager()) WITH CHECK (public.is_fleet_manager());
CREATE POLICY "alert_rules_delete" ON public.alert_rules FOR DELETE TO authenticated
  USING (public.is_fleet_manager());

DROP POLICY "geofences_select" ON public.geofences;
DROP POLICY "geofences_insert" ON public.geofences;
DROP POLICY "geofences_update" ON public.geofences;
DROP POLICY "geofences_delete" ON public.geofences;
CREATE POLICY "geofences_select" ON public.geofences FOR SELECT TO authenticated
  USING (
    public.is_fleet_manager()
    OR department_id IS NULL
    OR department_id = public.current_app_user_department()
  );
CREATE POLICY "geofences_insert" ON public.geofences FOR INSERT TO authenticated
  WITH CHECK (public.is_fleet_manager());
CREATE POLICY "geofences_update" ON public.geofences FOR UPDATE TO authenticated
  USING (public.is_fleet_manager()) WITH CHECK (public.is_fleet_manager());
CREATE POLICY "geofences_delete" ON public.geofences FOR DELETE TO authenticated
  USING (public.is_fleet_manager());

DROP POLICY "tracking_select" ON public.vehicle_tracking;
DROP POLICY "tracking_insert" ON public.vehicle_tracking;
CREATE POLICY "tracking_select" ON public.vehicle_tracking FOR SELECT TO authenticated
  USING (public.can_access_vehicle(vehicle_id));
CREATE POLICY "tracking_insert" ON public.vehicle_tracking FOR INSERT TO authenticated
  WITH CHECK (public.can_access_vehicle(vehicle_id));

DROP POLICY "alerts_select" ON public.vehicle_alerts;
DROP POLICY "alerts_insert" ON public.vehicle_alerts;
DROP POLICY "alerts_update" ON public.vehicle_alerts;
CREATE POLICY "alerts_select" ON public.vehicle_alerts FOR SELECT TO authenticated
  USING (public.can_access_vehicle(vehicle_id));
CREATE POLICY "alerts_insert" ON public.vehicle_alerts FOR INSERT TO authenticated
  WITH CHECK (public.can_access_vehicle(vehicle_id));
CREATE POLICY "alerts_update" ON public.vehicle_alerts FOR UPDATE TO authenticated
  USING (public.can_access_vehicle(vehicle_id))
  WITH CHECK (public.can_access_vehicle(vehicle_id));


-- ─────────────────────────────────────────────────────────────
-- STEP 10: Indexes  (performance)
-- ─────────────────────────────────────────────────────────────

CREATE INDEX idx_vehicles_status        ON public.vehicles(status);
CREATE INDEX idx_vehicles_vehicle_id    ON public.vehicles(vehicle_id);

CREATE INDEX idx_assignments_vehicle    ON public.vehicle_assignments(vehicle_id);
CREATE INDEX idx_assignments_active     ON public.vehicle_assignments(is_active);
CREATE INDEX idx_assignments_dept       ON public.vehicle_assignments(department_id);
CREATE INDEX idx_assignments_user       ON public.vehicle_assignments(assigned_user_id);

CREATE INDEX idx_tracking_vehicle       ON public.vehicle_tracking(vehicle_id);
CREATE INDEX idx_tracking_recorded      ON public.vehicle_tracking(recorded_at DESC);

CREATE INDEX idx_alerts_vehicle         ON public.vehicle_alerts(vehicle_id);
CREATE INDEX idx_alerts_acknowledged    ON public.vehicle_alerts(is_acknowledged);
CREATE INDEX idx_alerts_created         ON public.vehicle_alerts(created_at DESC);


-- ─────────────────────────────────────────────────────────────
-- STEP 11: Seed data  (departments, vehicles, rules, geofences)
-- app_users rows are created automatically by the trigger above
-- whenever a user signs up.
-- ─────────────────────────────────────────────────────────────

INSERT INTO public.departments (name, code, description, head_name, contact_email, location, is_active) VALUES
  ('Mechanical Department',  'MECH', 'Handles mechanical maintenance and operations', 'Rajesh Kumar',  'mech@railway.in', 'Platform A',   true),
  ('Electrical Department',  'ELEC', 'Manages electrical systems and charging',        'Priya Singh',   'elec@railway.in', 'Platform B',   true),
  ('Operations Department',  'OPS',  'Day-to-day railway operations',                  'Anand Mehta',   'ops@railway.in',  'Main Office',  true),
  ('Safety Department',      'SAFE', 'Safety inspections and compliance',               'Sunita Rao',    'safe@railway.in', 'Safety Block', true),
  ('Logistics Department',   'LOG',  'Cargo and goods movement',                        'Vikram Patel',  'log@railway.in',  'Warehouse',    true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.vehicles (vehicle_id, variant, battery_type, battery_capacity, manufacturing_date, firmware_version, last_maintenance_date, status, gps_enabled, trackman_enabled, trackman_safety_enabled) VALUES
  ('PS001',  'PiScoot',        'LiFe', '48V 25Ah', '2024-01-15', 'v2.1.0', '2024-02-20', 'active',      true,  true,  true),
  ('PSB002', 'PiScoot-Bolt',   'LiPo', '48V 30Ah', '2024-02-01', 'v2.0.8', '2024-03-10', 'idle',        true,  true,  false),
  ('PSA003', 'PiScoot-Aegis',  'NMC',  '52V 28Ah', '2024-01-20', 'v1.9.5', '2024-02-28', 'maintenance', true,  false, false),
  ('PS004',  'PiScoot',        'LiFe', '48V 25Ah', '2024-03-05', 'v2.1.0', null,          'active',      true,  true,  true),
  ('PSB005', 'PiScoot-Bolt',   'LiPo', '48V 30Ah', '2024-03-15', 'v2.0.8', '2024-04-01', 'offline',     false, false, false)
ON CONFLICT (vehicle_id) DO NOTHING;

INSERT INTO public.alert_rules (name, description, rule_type, severity, condition_operator, condition_value, condition_unit, is_active) VALUES
  ('Over Speed Alert',       'Trigger when scooter exceeds speed limit',       'speed',     'high',     'gt', 25, 'km/h',       true),
  ('Low Battery Warning',    'Alert when battery drops below threshold',        'battery',   'medium',   'lt', 20, '%',          true),
  ('Geofence Exit',          'Alert when vehicle exits operational zone',       'geofence',  'critical', 'eq',  1, 'exit',       true),
  ('Idle Too Long',          'Alert when vehicle idle for extended time',       'idle_time', 'low',      'gt', 30, 'minutes',    true),
  ('Unauthorized Movement',  'Alert for movement outside working hours',        'movement',  'high',     'eq',  1, 'after_hours',true)
ON CONFLICT DO NOTHING;

INSERT INTO public.geofences (name, description, fence_type, center_lat, center_lng, radius_meters, is_active, alert_on_enter, alert_on_exit, color_hex) VALUES
  ('Main Station Zone',          'Primary operational area around main station', 'operational', 28.6139, 77.2090, 500, true, false, true,  '#F58220'),
  ('Platform A Depot',           'Charging depot for Platform A vehicles',       'depot',       28.6145, 77.2085, 100, true, false, false, '#0D2F4F'),
  ('Restricted Maintenance Bay', 'Only authorized maintenance vehicles',          'restricted',  28.6132, 77.2095, 150, true, true,  true,  '#DC2626')
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────
-- Done!
-- Tables created: departments, app_users, vehicles,
--   vehicle_assignments, alert_rules, geofences,
--   vehicle_tracking, vehicle_alerts
-- Trigger created: on_auth_user_created → handle_new_auth_user()
-- Seed data inserted: 5 departments, 5 vehicles, 5 alert rules,
--   3 geofences
-- ─────────────────────────────────────────────────────────────
