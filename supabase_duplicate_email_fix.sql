-- Fix: prevent duplicate email registration per campaign
-- When email already exists AND is already a participant in the campaign,
-- return already_registered: true instead of silently logging in.

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
  v_already_in_campaign boolean := false;
BEGIN
  SELECT name INTO v_org_name FROM organizations WHERE id = p_org_id;
  IF v_org_name IS NULL THEN
    RAISE EXCEPTION 'Organization not found';
  END IF;

  SELECT id, name INTO v_profile_id, v_existing_name
  FROM profiles
  WHERE email = lower(trim(p_email));

  IF v_profile_id IS NOT NULL THEN
    IF p_campaign_id IS NOT NULL THEN
      SELECT EXISTS(
        SELECT 1 FROM campaign_participants
        WHERE campaign_id = p_campaign_id AND profile_id = v_profile_id
      ) INTO v_already_in_campaign;
    END IF;

    IF v_already_in_campaign THEN
      RETURN jsonb_build_object(
        'profile_id', v_profile_id,
        'name', v_existing_name,
        'org_name', v_org_name,
        'email', lower(trim(p_email)),
        'is_existing', true,
        'already_registered', true
      );
    END IF;
  ELSE
    INSERT INTO profiles (name, email, org_id, custom_org_name)
    VALUES (p_name, lower(trim(p_email)), p_org_id, p_custom_org_name)
    RETURNING id INTO v_profile_id;

    v_existing_name := p_name;
  END IF;

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
    'is_existing', (v_existing_name != p_name OR v_profile_id IS NOT NULL),
    'already_registered', false
  );
END;
$$;
