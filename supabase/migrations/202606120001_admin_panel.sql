/*
  ============================================================
  RailScooter — Admin Panel Migration
  ============================================================

  HOW TO APPLY:
  Option A (Supabase CLI):
    supabase db push

  Option B (Manual — Supabase Dashboard):
    1. Go to Supabase Dashboard → SQL Editor → New Query
    2. Paste this file and click Run

  WHAT THIS DOES:
  - Adds `approval_status` column to app_users
  - Updates the new-user trigger to set status = 'pending'
  - Creates activity_log table (for real-time God View feed)
  - Creates broadcast_messages table (for admin alerts)
  - Adds RLS policies for all new tables/columns
  ============================================================
*/


-- ─────────────────────────────────────────────────────────────
-- STEP 1: Add approval_status to app_users
-- Existing users keep 'approved'. New users will be 'pending'.
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved'
  CHECK (approval_status IN ('pending', 'approved', 'rejected'));


-- ─────────────────────────────────────────────────────────────
-- STEP 2: Update the new-user trigger
-- New sign-ups should land in 'pending' (not auto-approved).
-- The very first user (admin) is still auto-approved.
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_first_user boolean;
BEGIN
  SELECT NOT EXISTS (SELECT 1 FROM public.app_users) INTO is_first_user;

  INSERT INTO public.app_users (id, full_name, role, is_active, approval_status)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    ),
    CASE WHEN is_first_user THEN 'admin' ELSE 'trackman' END,
    CASE WHEN is_first_user THEN true ELSE false END,   -- pending users start inactive
    CASE WHEN is_first_user THEN 'approved' ELSE 'pending' END
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;


-- ─────────────────────────────────────────────────────────────
-- STEP 3: activity_log table
-- Stores all significant events for the real-time God View feed.
-- Enable Realtime on this table in:
--   Supabase Dashboard → Database → Replication → activity_log ✓
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.activity_log (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    uuid        REFERENCES public.app_users(id) ON DELETE SET NULL,
  actor_name  text        NOT NULL DEFAULT '',
  event_type  text        NOT NULL
                          CHECK (event_type IN (
                            'user_approved', 'user_rejected', 'user_suspended',
                            'user_reactivated', 'user_edited', 'user_deleted',
                            'clock_in', 'clock_out',
                            'report_submitted', 'alert_acknowledged',
                            'vehicle_updated', 'broadcast_sent', 'other'
                          )),
  description text        NOT NULL DEFAULT '',
  metadata    jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read the log (admin sees everything)
CREATE POLICY "activity_log_select" ON public.activity_log
  FOR SELECT TO authenticated USING (true);

-- Only fleet managers (admin/manager) can insert log entries
CREATE POLICY "activity_log_insert" ON public.activity_log
  FOR INSERT TO authenticated WITH CHECK (public.is_fleet_manager());

CREATE INDEX IF NOT EXISTS idx_activity_log_created ON public.activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_type    ON public.activity_log(event_type);
CREATE INDEX IF NOT EXISTS idx_activity_log_actor   ON public.activity_log(actor_id);


-- ─────────────────────────────────────────────────────────────
-- STEP 4: broadcast_messages table
-- Stores admin broadcast alerts visible to target roles.
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.broadcast_messages (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text        NOT NULL,
  body        text        NOT NULL,
  target_role text        NOT NULL DEFAULT 'all'
                          CHECK (target_role IN ('all', 'manager', 'trackman')),
  sent_by     uuid        REFERENCES public.app_users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.broadcast_messages ENABLE ROW LEVEL SECURITY;

-- Users can read broadcasts targeted at them or 'all'
CREATE POLICY "broadcasts_select" ON public.broadcast_messages
  FOR SELECT TO authenticated
  USING (
    target_role = 'all'
    OR target_role = public.current_app_user_role()
    OR public.current_app_user_role() = 'admin'
  );

-- Only admins can send broadcasts
CREATE POLICY "broadcasts_insert" ON public.broadcast_messages
  FOR INSERT TO authenticated
  WITH CHECK (public.current_app_user_role() = 'admin');

CREATE INDEX IF NOT EXISTS idx_broadcasts_created ON public.broadcast_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_broadcasts_role    ON public.broadcast_messages(target_role);


-- ─────────────────────────────────────────────────────────────
-- STEP 5: Allow admins to update any app_user row
-- The existing trigger blocks non-managers from changing
-- authorization fields. Admin should bypass this for the
-- approval flow. We update the users_update RLS policy.
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "users_update" ON public.app_users;
CREATE POLICY "users_update" ON public.app_users
  FOR UPDATE TO authenticated
  USING (
    public.current_app_user_role() = 'admin'
    OR public.is_fleet_manager()
    OR id = auth.uid()
  )
  WITH CHECK (
    public.current_app_user_role() = 'admin'
    OR public.is_fleet_manager()
    OR id = auth.uid()
  );

-- Allow admins to delete users (managers cannot, only admins)
DROP POLICY IF EXISTS "users_delete" ON public.app_users;
CREATE POLICY "users_delete" ON public.app_users
  FOR DELETE TO authenticated
  USING (public.current_app_user_role() = 'admin' AND id != auth.uid());


-- ─────────────────────────────────────────────────────────────
-- Done!
-- New objects: activity_log, broadcast_messages
-- Modified:    app_users (approval_status col), handle_new_auth_user trigger
--              users_update policy, users_delete policy
-- ─────────────────────────────────────────────────────────────
