-- =====================================================
-- Bugfix migration — run in Supabase SQL Editor
-- Adds missing DELETE RLS policy for organizations
-- =====================================================

-- BUG-1: Organizations table was missing DELETE policy,
-- causing db.from('organizations').delete() to silently fail.
CREATE POLICY "orgs_delete" ON organizations FOR DELETE USING (true);
