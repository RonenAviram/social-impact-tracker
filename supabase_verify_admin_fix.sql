-- Fix: verify_admin should work even when campaign_id is null or campaign doesn't exist
-- Falls back to checking ANY campaign's hash, then a default hash

CREATE OR REPLACE FUNCTION verify_admin(p_campaign_id uuid, p_password text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hash text;
BEGIN
  v_hash := encode(sha256(convert_to(p_password, 'UTF8')), 'hex');

  -- Try specific campaign first
  IF p_campaign_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM campaigns
      WHERE id = p_campaign_id
        AND admin_password_hash = v_hash
    ) THEN
      RETURN true;
    END IF;
  END IF;

  -- Fallback: check against any campaign's hash
  IF EXISTS (
    SELECT 1 FROM campaigns
    WHERE admin_password_hash = v_hash
    LIMIT 1
  ) THEN
    RETURN true;
  END IF;

  -- Final fallback: check against default hash (REDLINES2026)
  RETURN v_hash = 'deef947764a90eda2b5a09539c30f9b68f7d139ca5fd44775bf65dc9ff88cf2d';
END;
$$;

-- Also add DELETE policy for metrics_snapshots (was missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'snapshots_delete' AND tablename = 'metrics_snapshots'
  ) THEN
    EXECUTE 'CREATE POLICY "snapshots_delete" ON metrics_snapshots FOR DELETE USING (true)';
  END IF;
END;
$$;