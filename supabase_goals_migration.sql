-- Goals redesign migration
-- Adds structured goal types (primary = campaign-level, secondary = platform+metric level)
-- Replaces free-text 'name' with goal_type + platform_id + metric_id

-- Step 1: Add new columns
ALTER TABLE campaign_goals ADD COLUMN IF NOT EXISTS goal_type text;
ALTER TABLE campaign_goals ADD COLUMN IF NOT EXISTS platform_id text;
ALTER TABLE campaign_goals ADD COLUMN IF NOT EXISTS metric_id text;

-- Step 2: Migrate existing goals by mapping known names to goal_type
UPDATE campaign_goals SET goal_type = 'total_reach' WHERE name = 'חשיפות כוללות' AND goal_type IS NULL;
UPDATE campaign_goals SET goal_type = 'total_content' WHERE name = 'תכנים שהועלו' AND goal_type IS NULL;
UPDATE campaign_goals SET goal_type = 'active_participants' WHERE name = 'משתתפים פעילים' AND goal_type IS NULL;
UPDATE campaign_goals SET goal_type = 'total_engagement' WHERE name = 'אינטראקציות כוללות' AND goal_type IS NULL;
UPDATE campaign_goals SET goal_type = 'active_platforms' WHERE name = 'כמות פלטפורמות' AND goal_type IS NULL;

-- Map FB-specific goal to platform-level
UPDATE campaign_goals
SET goal_type = 'platform_metric', platform_id = 'facebook', metric_id = 'reach'
WHERE name = 'חשיפות ממוצעות לפוסט FB' AND goal_type IS NULL;

-- Any remaining unmapped goals get a generic type so they don't break
UPDATE campaign_goals SET goal_type = 'custom' WHERE goal_type IS NULL;

-- Step 3: Make goal_type NOT NULL now that all rows have a value
ALTER TABLE campaign_goals ALTER COLUMN goal_type SET NOT NULL;

-- Step 4: Add unique constraint to prevent duplicate goal definitions per campaign
-- A campaign can have at most one goal per (goal_type, platform_id, metric_id) combo
CREATE UNIQUE INDEX IF NOT EXISTS idx_goals_unique
ON campaign_goals (campaign_id, goal_type, COALESCE(platform_id, ''), COALESCE(metric_id, ''));
