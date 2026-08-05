-- =====================================================
-- Social Impact Tracker — Supabase Migration
-- Run this in Supabase SQL Editor (one shot)
-- =====================================================

-- === TABLES ===

CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(name, org_id)
);

CREATE TABLE campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  start_date date,
  end_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'ended')),
  admin_password_hash text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE campaign_participants (
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (campaign_id, profile_id)
);

CREATE TABLE campaign_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  name text NOT NULL,
  target_value integer NOT NULL DEFAULT 0,
  sort_order integer NOT NULL DEFAULT 0
);

CREATE TABLE content_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  platform_id text NOT NULL,
  content_type text NOT NULL,
  link text,
  upload_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE metrics_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_entry_id uuid NOT NULL REFERENCES content_entries(id) ON DELETE CASCADE,
  snapshot_date date NOT NULL DEFAULT CURRENT_DATE,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- === AUTO-UPDATE updated_at ON campaigns ===

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER campaigns_updated_at
  BEFORE UPDATE ON campaigns
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- === INDEXES ===

CREATE INDEX idx_profiles_org ON profiles(org_id);
CREATE INDEX idx_profiles_active ON profiles(is_active) WHERE is_active = true;
CREATE INDEX idx_content_campaign ON content_entries(campaign_id);
CREATE INDEX idx_content_profile ON content_entries(profile_id);
CREATE INDEX idx_content_platform ON content_entries(platform_id);
CREATE INDEX idx_content_upload_date ON content_entries(upload_date);
CREATE INDEX idx_snapshots_entry ON metrics_snapshots(content_entry_id);
CREATE INDEX idx_snapshots_date ON metrics_snapshots(snapshot_date);
CREATE INDEX idx_participants_campaign ON campaign_participants(campaign_id);
CREATE INDEX idx_participants_profile ON campaign_participants(profile_id);
CREATE INDEX idx_goals_campaign ON campaign_goals(campaign_id);

-- === RLS ===

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "orgs_read" ON organizations FOR SELECT USING (true);
CREATE POLICY "orgs_write" ON organizations FOR INSERT WITH CHECK (true);
CREATE POLICY "orgs_update" ON organizations FOR UPDATE USING (true);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_read" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_write" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (true);

ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "campaigns_read" ON campaigns FOR SELECT USING (true);
CREATE POLICY "campaigns_write" ON campaigns FOR INSERT WITH CHECK (true);
CREATE POLICY "campaigns_update" ON campaigns FOR UPDATE USING (true);

ALTER TABLE campaign_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cp_read" ON campaign_participants FOR SELECT USING (true);
CREATE POLICY "cp_write" ON campaign_participants FOR INSERT WITH CHECK (true);
CREATE POLICY "cp_delete" ON campaign_participants FOR DELETE USING (true);

ALTER TABLE campaign_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "goals_read" ON campaign_goals FOR SELECT USING (true);
CREATE POLICY "goals_write" ON campaign_goals FOR INSERT WITH CHECK (true);
CREATE POLICY "goals_update" ON campaign_goals FOR UPDATE USING (true);
CREATE POLICY "goals_delete" ON campaign_goals FOR DELETE USING (true);

ALTER TABLE content_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "entries_read" ON content_entries FOR SELECT USING (true);
CREATE POLICY "entries_write" ON content_entries FOR INSERT WITH CHECK (true);
CREATE POLICY "entries_update" ON content_entries FOR UPDATE USING (true);
CREATE POLICY "entries_delete" ON content_entries FOR DELETE USING (true);

ALTER TABLE metrics_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "snapshots_read" ON metrics_snapshots FOR SELECT USING (true);
CREATE POLICY "snapshots_write" ON metrics_snapshots FOR INSERT WITH CHECK (true);

-- === RPC FUNCTIONS ===

-- Login: verify name + org, return profile info
CREATE OR REPLACE FUNCTION login_user(p_name text, p_org_name text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'profile_id', p.id,
    'name', p.name,
    'org_name', o.name,
    'org_id', o.id,
    'role', p.role
  ) INTO result
  FROM profiles p
  JOIN organizations o ON o.id = p.org_id
  WHERE p.name = p_name
    AND o.name = p_org_name
    AND p.is_active = true;

  RETURN result;
END;
$$;

-- Get pool for a campaign (login dropdown population)
CREATE OR REPLACE FUNCTION get_campaign_pool(p_campaign_id uuid)
RETURNS TABLE(profile_id uuid, name text, org_name text)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, o.name
  FROM campaign_participants cp
  JOIN profiles p ON p.id = cp.profile_id
  JOIN organizations o ON o.id = p.org_id
  WHERE cp.campaign_id = p_campaign_id
    AND p.is_active = true
  ORDER BY o.name, p.name;
END;
$$;

-- Get all profiles (for admin pool management)
CREATE OR REPLACE FUNCTION get_all_profiles()
RETURNS TABLE(profile_id uuid, name text, org_name text, org_id uuid, role text, is_active boolean)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, o.name, o.id, p.role, p.is_active
  FROM profiles p
  JOIN organizations o ON o.id = p.org_id
  ORDER BY o.name, p.name;
END;
$$;

-- Verify admin password for a campaign
CREATE OR REPLACE FUNCTION verify_admin(p_campaign_id uuid, p_password text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM campaigns
    WHERE id = p_campaign_id
      AND admin_password_hash = encode(sha256(convert_to(p_password, 'UTF8')), 'hex')
  );
END;
$$;

-- Add content entry with initial metrics
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
BEGIN
  -- Check campaign is active
  SELECT status INTO v_status FROM campaigns WHERE id = p_campaign_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Campaign not found';
  END IF;
  IF v_status != 'active' THEN
    RAISE EXCEPTION 'Campaign is not active (status: %)', v_status;
  END IF;

  -- Check profile is participant
  IF NOT EXISTS (
    SELECT 1 FROM campaign_participants
    WHERE campaign_id = p_campaign_id AND profile_id = p_profile_id
  ) THEN
    RAISE EXCEPTION 'Profile is not a participant in this campaign';
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

-- Update metrics (append snapshot)
CREATE OR REPLACE FUNCTION update_metrics(
  p_content_entry_id uuid,
  p_profile_id uuid,
  p_snapshot_date date,
  p_metrics jsonb
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Verify ownership
  IF NOT EXISTS (
    SELECT 1 FROM content_entries
    WHERE id = p_content_entry_id AND profile_id = p_profile_id
  ) THEN
    RAISE EXCEPTION 'Not the owner of this content entry';
  END IF;

  -- Append new snapshot
  INSERT INTO metrics_snapshots (content_entry_id, snapshot_date, metrics)
  VALUES (p_content_entry_id, p_snapshot_date, p_metrics);
END;
$$;

-- Delete content entry (owner only)
CREATE OR REPLACE FUNCTION delete_content_entry(p_entry_id uuid, p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM content_entries
  WHERE id = p_entry_id AND profile_id = p_profile_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Entry not found or not owned by this profile';
  END IF;
END;
$$;

-- Get user's content entries with latest metrics
CREATE OR REPLACE FUNCTION get_user_contents(p_profile_id uuid, p_campaign_id uuid)
RETURNS TABLE(
  entry_id uuid,
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
    ce.platform_id,
    ce.content_type,
    ce.link,
    ce.upload_date,
    ms.metrics,
    ms.snapshot_date
  FROM content_entries ce
  JOIN LATERAL (
    SELECT s.metrics, s.snapshot_date
    FROM metrics_snapshots s
    WHERE s.content_entry_id = ce.id
    ORDER BY s.snapshot_date DESC, s.created_at DESC
    LIMIT 1
  ) ms ON true
  WHERE ce.profile_id = p_profile_id
    AND ce.campaign_id = p_campaign_id
  ORDER BY ce.upload_date DESC;
END;
$$;

-- Dashboard: all entries with latest metrics for a campaign
CREATE OR REPLACE FUNCTION get_dashboard_data(p_campaign_id uuid)
RETURNS TABLE(
  entry_id uuid,
  profile_id uuid,
  profile_name text,
  org_name text,
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

-- Get campaign info
CREATE OR REPLACE FUNCTION get_campaign(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'description', c.description,
    'start_date', c.start_date,
    'end_date', c.end_date,
    'status', c.status,
    'created_at', c.created_at
  ) INTO result
  FROM campaigns c
  WHERE c.id = p_campaign_id;

  RETURN result;
END;
$$;

-- === SEED DATA ===

-- Organizations
INSERT INTO organizations (name) VALUES
  ('ויצו'),
  ('נעמת'),
  ('דלת פתוחה'),
  ('לדעת לבחור נכון'),
  ('איגוד העובדים הסוציאליים'),
  ('לתת פה'),
  ('לא לאלימות'),
  ('קווים אדומים');

-- Profiles (from current POOL in form.html)
INSERT INTO profiles (name, org_id, role) VALUES
  ('מיכל פרינס', (SELECT id FROM organizations WHERE name = 'קווים אדומים'), 'admin'),
  ('דנה כהן', (SELECT id FROM organizations WHERE name = 'ויצו'), 'member'),
  ('יעל לוי', (SELECT id FROM organizations WHERE name = 'נעמת'), 'member'),
  ('רותם שמש', (SELECT id FROM organizations WHERE name = 'דלת פתוחה'), 'member'),
  ('אורלי דוד', (SELECT id FROM organizations WHERE name = 'לדעת לבחור נכון'), 'member'),
  ('נועה בן דוד', (SELECT id FROM organizations WHERE name = 'איגוד העובדים הסוציאליים'), 'member'),
  ('שירה גולן', (SELECT id FROM organizations WHERE name = 'לתת פה'), 'member'),
  ('מאיה ברק', (SELECT id FROM organizations WHERE name = 'לא לאלימות'), 'member'),
  ('תמר רוזן', (SELECT id FROM organizations WHERE name = 'קווים אדומים'), 'member'),
  ('ליאת כץ', (SELECT id FROM organizations WHERE name = 'ויצו'), 'member');

-- First campaign (admin password = 'nadav' for now, change before production)
INSERT INTO campaigns (name, description, start_date, end_date, status, admin_password_hash)
VALUES (
  'מניעת אלימות בזוגיות צעירה',
  'קמפיין מניעה ראשון — יוני 2026',
  '2026-06-22',
  '2026-06-28',
  'active',
  encode(sha256(convert_to('nadav', 'UTF8')), 'hex')
);

-- Add all profiles as participants in the first campaign
INSERT INTO campaign_participants (campaign_id, profile_id)
SELECT
  (SELECT id FROM campaigns LIMIT 1),
  p.id
FROM profiles p;

-- Default goals for first campaign
INSERT INTO campaign_goals (campaign_id, name, target_value, sort_order) VALUES
  ((SELECT id FROM campaigns LIMIT 1), 'חשיפות כוללות', 2000000, 1),
  ((SELECT id FROM campaigns LIMIT 1), 'תכנים שהועלו', 150, 2),
  ((SELECT id FROM campaigns LIMIT 1), 'חשיפות ממוצעות לפוסט FB', 1000, 3),
  ((SELECT id FROM campaigns LIMIT 1), 'משתתפים פעילים', 50, 4);
