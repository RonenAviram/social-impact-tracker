-- UAT fixes (2026-08-12, round 2)
-- Run in Supabase SQL Editor

-- Fix #1: update_metrics — UPSERT instead of INSERT
-- Prevents duplicate snapshots for same entry+date, ensures second update is visible

-- Step 1: Add unique constraint (needed for ON CONFLICT)
ALTER TABLE metrics_snapshots
  ADD CONSTRAINT uq_snapshot_entry_date UNIQUE (content_entry_id, snapshot_date);

-- Step 2: Replace function with UPSERT version
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

  -- Upsert: insert or update if same date exists
  INSERT INTO metrics_snapshots (content_entry_id, snapshot_date, metrics)
  VALUES (p_content_entry_id, p_snapshot_date, p_metrics)
  ON CONFLICT (content_entry_id, snapshot_date)
  DO UPDATE SET metrics = EXCLUDED.metrics, created_at = now();
END;
$$;

-- Clean up any existing duplicate snapshots (keep latest by created_at)
DELETE FROM metrics_snapshots a
USING metrics_snapshots b
WHERE a.content_entry_id = b.content_entry_id
  AND a.snapshot_date = b.snapshot_date
  AND a.created_at < b.created_at;
