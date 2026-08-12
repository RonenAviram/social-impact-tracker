-- =====================================================
-- Fix: sync admin_password_hash across ALL campaigns
-- Run in Supabase SQL Editor (one shot)
-- =====================================================
-- Some campaigns inherited the old 'nadav' hash instead of 'REDLINES2026'.
-- This updates ALL campaigns to use the current password.

UPDATE campaigns
SET admin_password_hash = encode(sha256(convert_to('REDLINES2026', 'UTF8')), 'hex')
WHERE admin_password_hash IS DISTINCT FROM encode(sha256(convert_to('REDLINES2026', 'UTF8')), 'hex');
