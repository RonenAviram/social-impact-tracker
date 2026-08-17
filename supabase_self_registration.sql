-- =====================================================
-- Self-Registration Migration
-- Run in Supabase SQL Editor
-- =====================================================

-- === 1. SCHEMA CHANGES ===

-- profiles: add email + custom_org_name
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS custom_org_name TEXT;

-- email unique constraint (separate so IF NOT EXISTS works)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_email_key'
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_email_key UNIQUE (email);
  END IF;
END;
$$;

-- campaign_participants: add status
ALTER TABLE campaign_participants ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'cp_status_check'
  ) THEN
    ALTER TABLE campaign_participants ADD CONSTRAINT cp_status_check
      CHECK (status IN ('active', 'suspended'));
  END IF;
END;
$$;

-- === 2. ORGANIZATION "אחר" ===

INSERT INTO organizations (name) VALUES ('אחר')
ON CONFLICT (name) DO NOTHING;

-- === 3. RLS — add UPDATE policy for campaign_participants (needed for suspend/reactivate) ===

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'cp_update' AND tablename = 'campaign_participants'
  ) THEN
    EXECUTE 'CREATE POLICY "cp_update" ON campaign_participants FOR UPDATE USING (true)';
  END IF;
END;
$$;

-- Add DELETE policy for profiles (needed for seed cleanup)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'profiles_delete' AND tablename = 'profiles'
  ) THEN
    EXECUTE 'CREATE POLICY "profiles_delete" ON profiles FOR DELETE USING (true)';
  END IF;
END;
$$;

-- === 4. NEW RPCs ===

-- register_profile: create profile (or find by email) + add to campaign
CREATE OR REPLACE FUNCTION register_profile(
  p_name text,
  p_email text,
  p_org_id uuid,
  p_custom_org_name text DEFAULT NULL,
  p_campaign_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_profile_id uuid;
  v_org_name text;
  v_existing_name text;
BEGIN
  -- Get org name for response
  SELECT name INTO v_org_name FROM organizations WHERE id = p_org_id;
  IF v_org_name IS NULL THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  -- Try to find existing profile by email
  SELECT id, name INTO v_profile_id, v_existing_name
  FROM profiles
  WHERE email = lower(trim(p_email));

  IF v_profile_id IS NOT NULL THEN
    -- Profile exists — use it (don't update name/org)
    NULL;
  ELSE
    -- Create new profile
    INSERT INTO profiles (name, email, org_id, custom_org_name)
    VALUES (p_name, lower(trim(p_email)), p_org_id, p_custom_org_name)
    RETURNING id INTO v_profile_id;

    v_existing_name := p_name;
  END IF;

  -- Add to campaign if provided
  IF p_campaign_id IS NOT NULL AND v_profile_id IS NOT NULL THEN
    INSERT INTO campaign_participants (campaign_id, profile_id, status)
    VALUES (p_campaign_id, v_profile_id, 'active')
    ON CONFLICT (campaign_id, profile_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'profile_id', v_profile_id,
    'name', v_existing_name,
    'org_name', v_org_name,
    'email', lower(trim(p_email)),
    'is_existing', (v_existing_name != p_name OR v_profile_id IS NOT NULL)
  );
END;
$$;

-- find_profiles_by_name: for "already registered" dropdown
CREATE OR REPLACE FUNCTION find_profiles_by_name(p_name text)
RETURNS TABLE(
  profile_id uuid,
  name text,
  email text,
  org_name text,
  custom_org_name text
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, p.email, o.name, p.custom_org_name
  FROM profiles p
  JOIN organizations o ON o.id = p.org_id
  WHERE p.name = p_name
    AND p.is_active = true
  ORDER BY o.name;
END;
$$;

-- get_all_profiles_for_login: all names for login dropdown
CREATE OR REPLACE FUNCTION get_all_profiles_for_login()
RETURNS TABLE(
  profile_id uuid,
  name text,
  email text,
  org_name text,
  custom_org_name text
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, p.email, o.name, p.custom_org_name
  FROM profiles p
  JOIN organizations o ON o.id = p.org_id
  WHERE p.is_active = true
  ORDER BY p.name;
END;
$$;

-- suspend_participant
CREATE OR REPLACE FUNCTION suspend_participant(p_campaign_id uuid, p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE campaign_participants
  SET status = 'suspended'
  WHERE campaign_id = p_campaign_id AND profile_id = p_profile_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participant not found in this campaign';
  END IF;
END;
$$;

-- reactivate_participant
CREATE OR REPLACE FUNCTION reactivate_participant(p_campaign_id uuid, p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE campaign_participants
  SET status = 'active'
  WHERE campaign_id = p_campaign_id AND profile_id = p_profile_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participant not found in this campaign';
  END IF;
END;
$$;

-- === 5. UPDATE EXISTING RPCs ===

-- Drop functions whose return type changes (Postgres requires this)
DROP FUNCTION IF EXISTS get_campaign_pool(uuid);
DROP FUNCTION IF EXISTS get_all_profiles();
DROP FUNCTION IF EXISTS get_dashboard_data(uuid);

-- get_campaign_pool: add email, custom_org_name, status
CREATE OR REPLACE FUNCTION get_campaign_pool(p_campaign_id uuid)
RETURNS TABLE(profile_id uuid, name text, org_name text, email text, custom_org_name text, status text)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, o.name, p.email, p.custom_org_name, cp.status
  FROM campaign_participants cp
  JOIN profiles p ON p.id = cp.profile_id
  JOIN organizations o ON o.id = p.org_id
  WHERE cp.campaign_id = p_campaign_id
    AND p.is_active = true
  ORDER BY o.name, p.name;
END;
$$;

-- get_all_profiles: add email, custom_org_name
CREATE OR REPLACE FUNCTION get_all_profiles()
RETURNS TABLE(profile_id uuid, name text, org_name text, org_id uuid, role text, is_active boolean, email text, custom_org_name text)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, o.name, o.id, p.role, p.is_active, p.email, p.custom_org_name
  FROM profiles p
  JOIN organizations o ON o.id = p.org_id
  ORDER BY o.name, p.name;
END;
$$;

-- get_dashboard_data: add custom_org_name
CREATE OR REPLACE FUNCTION get_dashboard_data(p_campaign_id uuid)
RETURNS TABLE(
  entry_id uuid,
  profile_id uuid,
  profile_name text,
  org_name text,
  custom_org_name text,
  platform_id text,
  content_type text,
  link text,
  upload_date date,
  latest_metrics jsonb,
  latest_snapshot_date date
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.id,
    ce.profile_id,
    p.name,
    o.name,
    p.custom_org_name,
    ce.platform_id,
    ce.content_type,
    ce.link,
    ce.upload_date,
    ms.metrics,
    ms.snapshot_date
  FROM content_entries ce
  JOIN profiles p ON p.id = ce.profile_id
  JOIN organizations o ON o.id = p.org_id
  JOIN LATERAL (
    SELECT s.metrics, s.snapshot_date
    FROM metrics_snapshots s
    WHERE s.content_entry_id = ce.id
    ORDER BY s.snapshot_date DESC, s.created_at DESC
    LIMIT 1
  ) ms ON true
  WHERE ce.campaign_id = p_campaign_id
  ORDER BY ce.upload_date DESC;
END;
$$;

-- add_content_entry: add participant status check
CREATE OR REPLACE FUNCTION add_content_entry(
  p_profile_id uuid,
  p_campaign_id uuid,
  p_platform_id text,
  p_content_type text,
  p_link text,
  p_upload_date date,
  p_initial_metrics jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_entry_id uuid;
  v_status text;
  v_participant_status text;
BEGIN
  -- Check campaign is active
  SELECT status INTO v_status FROM campaigns WHERE id = p_campaign_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF v_status != 'active' THEN
    RAISE EXCEPTION 'Campaign is not active (status: %)', v_status;
  END IF;

  -- Check profile is active participant
  SELECT cp.status INTO v_participant_status
  FROM campaign_participants cp
  WHERE cp.campaign_id = p_campaign_id AND cp.profile_id = p_profile_id;

  IF v_participant_status IS NULL THEN
    RAISE EXCEPTION 'Profile is not a participant in this campaign';
  END IF;
  IF v_participant_status != 'active' THEN
    RAISE EXCEPTION 'Participant is suspended';
  END IF;

  -- Insert entry
  INSERT INTO content_entries (campaign_id, profile_id, platform_id, content_type, link, upload_date)
  VALUES (p_campaign_id, p_profile_id, p_platform_id, p_content_type, p_link, p_upload_date)
  RETURNING id INTO v_entry_id;

  -- Insert initial snapshot
  INSERT INTO metrics_snapshots (content_entry_id, snapshot_date, metrics)
  VALUES (v_entry_id, p_upload_date, p_initial_metrics);

  RETURN v_entry_id;
END;
$$;

-- update_metrics: add participant status check
CREATE OR REPLACE FUNCTION update_metrics(
  p_content_entry_id uuid,
  p_profile_id uuid,
  p_snapshot_date date,
  p_metrics jsonb
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_campaign_id uuid;
  v_participant_status text;
BEGIN
  -- Verify ownership and get campaign_id
  SELECT ce.campaign_id INTO v_campaign_id
  FROM content_entries ce
  WHERE ce.id = p_content_entry_id AND ce.profile_id = p_profile_id;

  IF v_campaign_id IS NULL THEN
    RAISE EXCEPTION 'Not the owner of this content entry';
  END IF;

  -- Check participant is active
  SELECT cp.status INTO v_participant_status
  FROM campaign_participants cp
  WHERE cp.campaign_id = v_campaign_id AND cp.profile_id = p_profile_id;

  IF v_participant_status IS NULL OR v_participant_status != 'active' THEN
    RAISE EXCEPTION 'Participant is suspended or not in campaign';
  END IF;

  -- Upsert snapshot
  INSERT INTO metrics_snapshots (content_entry_id, snapshot_date, metrics)
  VALUES (p_content_entry_id, p_snapshot_date, p_metrics)
  ON CONFLICT (content_entry_id, snapshot_date)
  DO UPDATE SET metrics = EXCLUDED.metrics, created_at = now();
END;
$$;

-- === 6. REMOVE SEED PROFILES ===
-- Delete only profiles with no content entries (safe: won't break existing data)
-- campaign_participants has ON DELETE CASCADE from profiles, so those clean up automatically

DELETE FROM campaign_participants
WHERE profile_id IN (
  SELECT p.id FROM profiles p
  WHERE NOT EXISTS (
    SELECT 1 FROM content_entries ce WHERE ce.profile_id = p.id
  )
);

DELETE FROM profiles
WHERE NOT EXISTS (
  SELECT 1 FROM content_entries ce WHERE ce.profile_id = profiles.id
);
