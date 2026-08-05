# Supabase Backend Architecture — Social Impact Tracker

## סיכום ביצועי

6 טבלאות, anon-based auth (שם+ארגון כמו היום), admin via hashed password, JSONB למטריקות, append-only snapshots להיסטוריה. Free tier, אפס עלויות שוטפות.

---

## 1. סכמת DB

### organizations
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | `gen_random_uuid()` |
| `name` | text UNIQUE NOT NULL | "ויצו", "נעמת", etc. |
| `created_at` | timestamptz | `now()` |

### profiles (= pool members)
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | `gen_random_uuid()` |
| `name` | text NOT NULL | |
| `org_id` | uuid FK → organizations | |
| `role` | text | `'member'` (default) / `'admin'` |
| `is_active` | bool | `true` default |
| `created_at` | timestamptz | `now()` |

**Constraint:** `UNIQUE(name, org_id)` — אותו שם באותו ארגון = אותו אדם.

### campaigns
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `name` | text NOT NULL | |
| `description` | text | |
| `start_date` | date | |
| `end_date` | date | |
| `status` | text | `'active'` / `'paused'` / `'ended'` |
| `admin_password_hash` | text | SHA-256 hash, replaces hardcoded "nadav" |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | auto-updated via trigger |

### campaign_participants (M:N)
| Column | Type | Notes |
|--------|------|-------|
| `campaign_id` | uuid FK → campaigns | PK part 1 |
| `profile_id` | uuid FK → profiles | PK part 2 |

### content_entries
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | replaces `CONFIG.generateId()` |
| `campaign_id` | uuid FK → campaigns | |
| `profile_id` | uuid FK → profiles | |
| `platform_id` | text NOT NULL | `'facebook'`, `'instagram'`, etc. — matches config.js |
| `content_type` | text NOT NULL | `'פוסט'`, `'רילס'`, etc. |
| `link` | text | URL |
| `upload_date` | date | |
| `created_at` | timestamptz | |

### metrics_snapshots (append-only)
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `content_entry_id` | uuid FK → content_entries | |
| `snapshot_date` | date NOT NULL | |
| `metrics` | jsonb NOT NULL | `{"likes": 356, "comments": 114, ...}` |
| `created_at` | timestamptz | |

### campaign_goals
| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `campaign_id` | uuid FK → campaigns | |
| `name` | text | "חשיפות כוללות", "תכנים שהועלו" |
| `target_value` | integer | |
| `sort_order` | integer | |

---

## 2. למה JSONB למטריקות?

כל פלטפורמה ב-config.js מגדירה metrics שונות: פייסבוק = likes/comments/shares/reach/video_views, ספוטיפיי = listens/comments/new_followers/avg_listen. הגדרת עמודה לכל מטריקה = 20+ עמודות sparse. JSONB פותר את זה:

```json
// Facebook post
{"likes": 356, "comments": 114, "shares": 42, "reach": 1555}

// Spotify podcast
{"listens": 230, "comments": 5, "new_followers": 12, "avg_listen": 18}
```

**config.js נשאר ה-source of truth** לאיזה metrics קיימים בכל פלטפורמה. ה-DB פשוט מאחסן את הערכים.

---

## 3. Indexes

```sql
-- Performance-critical queries
CREATE INDEX idx_content_campaign ON content_entries(campaign_id);
CREATE INDEX idx_content_profile ON content_entries(profile_id);
CREATE INDEX idx_content_platform ON content_entries(platform_id);
CREATE INDEX idx_content_upload_date ON content_entries(upload_date);
CREATE INDEX idx_snapshots_entry ON metrics_snapshots(content_entry_id);
CREATE INDEX idx_snapshots_date ON metrics_snapshots(snapshot_date);
CREATE INDEX idx_participants_campaign ON campaign_participants(campaign_id);
CREATE INDEX idx_participants_profile ON campaign_participants(profile_id);
CREATE INDEX idx_profiles_org ON profiles(org_id);
```

---

## 4. Auth Flow

### משתמש רגיל (member)
```
form.html → Login screen
  ↓ שם + ארגון (dropdowns from DB)
  ↓ Supabase query: profiles.name + organizations.name match?
  ↓ Yes → localStorage = { profileId, name, org }
  ↓       → Personal area (screenPersonal)
  ↓ No  → "לא נמצא במאגר, פנה למנהל"
```

**מנגנון טכני:**
- הקליינט משתמש ב-Supabase anon key
- Login = `supabase.rpc('login_user', {p_name, p_org_name})` → returns `{profile_id, name, org_name, role}` or null
- ה-RPC function בודקת name+org ומחזירה profile_id
- הקליינט שומר profile_id ב-localStorage
- כל query עוקב שולח profile_id כפרמטר

### מנהל (admin)
```
dashboard.html → Admin checkbox
  ↓ prompt("סיסמת מנהל:")
  ↓ supabase.rpc('verify_admin', {campaign_id, password})
  ↓ Yes → admin mode (same as today but DB-backed)
  ↓ No  → "סיסמה שגויה"
```

**הסיסמה נבדקת server-side** — ה-RPC function משווה hash. לא חשופה בקוד.

---

## 5. RLS Policies

```sql
-- organizations: everyone reads, admin inserts
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "orgs_read" ON organizations FOR SELECT USING (true);
CREATE POLICY "orgs_insert" ON organizations FOR INSERT WITH CHECK (true);

-- profiles: everyone reads (needed for login dropdown), admin manages
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_read" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (true);

-- campaigns: everyone reads
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "campaigns_read" ON campaigns FOR SELECT USING (true);
CREATE POLICY "campaigns_manage" ON campaigns FOR ALL WITH CHECK (true);

-- campaign_participants: everyone reads
ALTER TABLE campaign_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cp_read" ON campaign_participants FOR SELECT USING (true);
CREATE POLICY "cp_manage" ON campaign_participants FOR ALL WITH CHECK (true);

-- content_entries: everyone reads, insert/update via RPC
ALTER TABLE content_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "entries_read" ON content_entries FOR SELECT USING (true);
CREATE POLICY "entries_insert" ON content_entries FOR INSERT WITH CHECK (true);
CREATE POLICY "entries_update" ON content_entries FOR UPDATE USING (true);
CREATE POLICY "entries_delete" ON content_entries FOR DELETE USING (true);

-- metrics_snapshots: everyone reads, insert via RPC
ALTER TABLE metrics_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "snapshots_read" ON metrics_snapshots FOR SELECT USING (true);
CREATE POLICY "snapshots_insert" ON metrics_snapshots FOR INSERT WITH CHECK (true);

-- campaign_goals: everyone reads, admin manages
ALTER TABLE campaign_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "goals_read" ON campaign_goals FOR SELECT USING (true);
CREATE POLICY "goals_manage" ON campaign_goals FOR ALL WITH CHECK (true);
```

> **הערה:** ה-RLS כאן "פתוח" כי אין Supabase Auth אמיתי — כל המשתמשים הם anon.
> ה-"הגנה" היא ברמת RPC functions שמאמתות את הלוגיקה (profile_id תקין, campaign active, etc.).
> זה מספיק לאפליקציה הזו — הנתונים לא רגישים והמשתמשים הם שותפים מהארגונים.

---

## 6. RPC Functions (API Layer)

### login_user
```sql
CREATE OR REPLACE FUNCTION login_user(p_name text, p_org_name text)
RETURNS jsonb AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'profile_id', p.id,
    'name', p.name,
    'org_name', o.name,
    'role', p.role
  ) INTO result
  FROM profiles p
  JOIN organizations o ON o.id = p.org_id
  WHERE p.name = p_name AND o.name = p_org_name AND p.is_active = true;

  RETURN result; -- null if not found
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### verify_admin
```sql
CREATE OR REPLACE FUNCTION verify_admin(p_campaign_id uuid, p_password text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM campaigns
    WHERE id = p_campaign_id
    AND admin_password_hash = encode(sha256(p_password::bytea), 'hex')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### get_campaign_pool (login dropdowns)
```sql
CREATE OR REPLACE FUNCTION get_campaign_pool(p_campaign_id uuid)
RETURNS TABLE(profile_id uuid, name text, org_name text) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.name, o.name
  FROM campaign_participants cp
  JOIN profiles p ON p.id = cp.profile_id
  JOIN organizations o ON o.id = p.org_id
  WHERE cp.campaign_id = p_campaign_id AND p.is_active = true
  ORDER BY o.name, p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### add_content_entry
```sql
CREATE OR REPLACE FUNCTION add_content_entry(
  p_profile_id uuid,
  p_campaign_id uuid,
  p_platform_id text,
  p_content_type text,
  p_link text,
  p_upload_date date,
  p_initial_metrics jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid AS $$
DECLARE
  v_entry_id uuid;
  v_campaign_status text;
BEGIN
  -- Verify campaign is active
  SELECT status INTO v_campaign_status FROM campaigns WHERE id = p_campaign_id;
  IF v_campaign_status != 'active' THEN
    RAISE EXCEPTION 'Campaign is not active';
  END IF;

  -- Verify profile is participant
  IF NOT EXISTS (
    SELECT 1 FROM campaign_participants
    WHERE campaign_id = p_campaign_id AND profile_id = p_profile_id
  ) THEN
    RAISE EXCEPTION 'Profile is not a participant';
  END IF;

  -- Insert content entry
  INSERT INTO content_entries (campaign_id, profile_id, platform_id, content_type, link, upload_date)
  VALUES (p_campaign_id, p_profile_id, p_platform_id, p_content_type, p_link, p_upload_date)
  RETURNING id INTO v_entry_id;

  -- Insert initial metrics snapshot (all zeros or provided)
  INSERT INTO metrics_snapshots (content_entry_id, snapshot_date, metrics)
  VALUES (v_entry_id, p_upload_date, p_initial_metrics);

  RETURN v_entry_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### update_metrics
```sql
CREATE OR REPLACE FUNCTION update_metrics(
  p_content_entry_id uuid,
  p_profile_id uuid,
  p_snapshot_date date,
  p_metrics jsonb
)
RETURNS void AS $$
BEGIN
  -- Verify ownership
  IF NOT EXISTS (
    SELECT 1 FROM content_entries
    WHERE id = p_content_entry_id AND profile_id = p_profile_id
  ) THEN
    RAISE EXCEPTION 'Not the owner of this content';
  END IF;

  -- Append snapshot (never overwrite)
  INSERT INTO metrics_snapshots (content_entry_id, snapshot_date, metrics)
  VALUES (p_content_entry_id, p_snapshot_date, p_metrics);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### get_dashboard_data (main dashboard query)
```sql
CREATE OR REPLACE FUNCTION get_dashboard_data(p_campaign_id uuid)
RETURNS TABLE(
  entry_id uuid,
  profile_name text,
  org_name text,
  platform_id text,
  content_type text,
  link text,
  upload_date date,
  latest_metrics jsonb,
  latest_snapshot_date date
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.id,
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### get_user_contents (personal area)
```sql
CREATE OR REPLACE FUNCTION get_user_contents(p_profile_id uuid, p_campaign_id uuid)
RETURNS TABLE(
  entry_id uuid,
  platform_id text,
  content_type text,
  link text,
  upload_date date,
  latest_metrics jsonb,
  latest_snapshot_date date
) AS $$
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
  WHERE ce.profile_id = p_profile_id AND ce.campaign_id = p_campaign_id
  ORDER BY ce.upload_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 7. Realtime

**לא נדרש.** הדשבורד מציג נתונים מצטברים — אין צורך ב-live updates. ה-live simulation הנוכחי (כל 15 שניות) הוא דמו בלבד. בפרודקשן, הדשבורד טוען data on page load וזהו. אם בעתיד צריך — Supabase realtime subscriptions זמינים ב-free tier.

---

## 8. Migration Plan — מדמו ל-DB

### שלב 0: Setup (10 דק')
1. צור Supabase project (free tier)
2. הרץ SQL migration — כל הטבלאות + indexes + RPC functions
3. הוסף `SUPABASE_URL` ו-`SUPABASE_ANON_KEY` ל-config.js

### שלב 1: Seed data (5 דק')
```sql
-- Insert orgs
INSERT INTO organizations (name) VALUES
  ('ויצו'), ('נעמת'), ('דלת פתוחה'), ('לדעת לבחור נכון'),
  ('איגוד העובדים הסוציאליים'), ('לתת פה'), ('לא לאלימות'), ('קווים אדומים');

-- Insert profiles (from current POOL)
INSERT INTO profiles (name, org_id, role) VALUES
  ('מיכל פרינס', (SELECT id FROM organizations WHERE name = 'קווים אדומים'), 'admin'),
  ('דנה כהן', (SELECT id FROM organizations WHERE name = 'ויצו'), 'member'),
  -- ... etc
;

-- Create first campaign
INSERT INTO campaigns (name, start_date, end_date, status, admin_password_hash)
VALUES ('מניעת אלימות בזוגיות צעירה', '2026-06-22', '2026-06-28', 'active',
        encode(sha256('NEW_PASSWORD'::bytea), 'hex'));
```

### שלב 2: config.js — הוספת Supabase client (5 דק')
```javascript
// Add to config.js
CONFIG.SUPABASE_URL = 'https://xxx.supabase.co';
CONFIG.SUPABASE_ANON_KEY = 'eyJ...';

// Initialize client (loaded via CDN <script> in each HTML)
CONFIG.supabase = null;
CONFIG.initSupabase = function() {
  if (!this.supabase && typeof supabase !== 'undefined') {
    this.supabase = supabase.createClient(this.SUPABASE_URL, this.SUPABASE_ANON_KEY);
  }
  return this.supabase;
};
```

כל HTML file מקבל:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="config.js"></script>
```

### שלב 3: form.html (2-3 שעות)
**Priority 1 — הכי קריטי.** זה מה שהמשתמשים רואים.

שינויים:
1. **Login:** POOL array → `supabase.rpc('get_campaign_pool', {p_campaign_id})` → populate dropdowns
2. **Login submit:** name+org → `supabase.rpc('login_user', {p_name, p_org_name})` → save profile_id
3. **Personal area:** `userContents[key]` → `supabase.rpc('get_user_contents', {p_profile_id, p_campaign_id})`
4. **Upload:** `userContents[key].push()` → `supabase.rpc('add_content_entry', {...})`
5. **Update metrics:** direct object mutation → `supabase.rpc('update_metrics', {...})`
6. **Delete:** `filter()` → `supabase.from('content_entries').delete().eq('id', contentId)`
7. **Campaign status:** CAMPAIGN object → `supabase.from('campaigns').select().eq('id', campaign_id).single()`

**מה לא משתנה:** כל ה-UI, config.js platforms/helpers, CSS, animations, XSS protection.

### שלב 4: dashboard.html (2-3 שעות)
1. **Data load:** `entries[]` generation → `supabase.rpc('get_dashboard_data', {p_campaign_id})`
2. **Transform:** map DB result to entries format that existing render functions expect
3. **Remove:** `generateDemoData`, `seedDemoData`, live simulation timer
4. **Admin panel:** hardcoded "nadav" → `supabase.rpc('verify_admin', {...})`
5. **Goals:** hardcoded → `supabase.from('campaign_goals').select().eq('campaign_id', id)`
6. **Campaign status update:** → `supabase.from('campaigns').update({status}).eq('id', id)`

**מה לא משתנה:** Charts, filters, breakdowns, link archive, CSV export — all keep working with the same data structure.

### שלב 5: admin-campaign.html (1-2 שעות)
1. **Participants:** hardcoded array → `supabase.rpc('get_campaign_pool')`
2. **Import from pool:** → `supabase.from('profiles').select('*, organizations(name)')`
3. **Save campaign:** → `supabase.from('campaigns').insert()` + `campaign_participants.insert()` + `campaign_goals.insert()`

### שלב 6: admin-pool.html (1-2 שעות)
1. **Pool list:** hardcoded array → `supabase.from('profiles').select('*, organizations(name)')`
2. **Add/remove person:** → `profiles.insert()` / `profiles.update({is_active: false})`
3. **Orgs management:** → `organizations.insert()` / soft delete
4. **CSV import/export:** keep client-side, but write to DB

### שלב 7: בדיקות + Polish (1-2 שעות)
- Full flow test: login → upload → update → dashboard sees it
- Admin flow: create campaign → add participants → set goals
- Edge cases: ended campaign blocking, empty states
- Loading states (spinner while waiting for Supabase)

---

## 9. סדר עבודה מוצע

| # | משימה | זמן | תלוי ב |
|---|--------|------|---------|
| 0 | Setup Supabase + SQL migration | 10 דק' | — |
| 1 | Seed initial data | 5 דק' | #0 |
| 2 | config.js + Supabase client | 5 דק' | #0 |
| 3 | form.html ← DB | 2-3 שעות | #1, #2 |
| 4 | dashboard.html ← DB | 2-3 שעות | #3 |
| 5 | admin-campaign.html ← DB | 1-2 שעות | #4 |
| 6 | admin-pool.html ← DB | 1-2 שעות | #4 |
| 7 | Testing + polish | 1-2 שעות | #5, #6 |
| **סה"כ** | | **~8-13 שעות** | |

מתוך 15 שעות בהצעת המחיר → נשאר 2-7 שעות buffer למובייל, accessibility, ובאגים.

---

## 10. Free Tier Limits

| Resource | Limit | Expected Usage |
|----------|-------|----------------|
| Database | 500MB | <10MB (text + JSONB) |
| API requests | Unlimited | ~100-500/day |
| Realtime | 200 concurrent | Not used |
| Storage | 1GB | Not used |
| Edge Functions | 500K/month | Not used |
| Bandwidth | 5GB/month | <100MB |

**Risk:** Free tier projects pause after 7 days of inactivity. Solution: the scheduled cron job (Supabase has built-in cron) or simply using the app keeps it alive. With active campaign = daily usage = no issue.

---

## 11. Handoff Plan (org gets their own infrastructure)

1. Fork GitHub repo → org's GitHub account
2. Create new Supabase project under org's email
3. Run same SQL migration
4. Export/import data (pg_dump/pg_restore or CSV)
5. Update config.js with new Supabase URL + key
6. Enable GitHub Pages on forked repo
7. ~20-30 minutes remote work
