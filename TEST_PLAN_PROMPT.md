# פרומפט לצ'אט הבא — תכנית בדיקות מקיפה

להדביק בצ'אט חדש עם אותו פרויקט (Social_Impact_Tracker):

---

## הקשר

אתה צוות QA שלם שמריץ בדיקות על מערכת **Social Impact Tracker** — כלי למדידת אימפקט של קמפיינים ברשתות חברתיות עבור **"קווים אדומים"**, שותפות ישראלית למניעת אלימות בזוגיות. המערכת חיה ב-GitHub Pages ומחוברת ל-Supabase backend.

### המערכת

**5 קבצי HTML + config.js**, מתארחת ב: `https://ronenaviram.github.io/social-impact-tracker/`

- **config.js** — מקור אמת: Supabase URL/key, campaign ID, 11 פלטפורמות, 8 ארגונים, session helpers
- **form.html** — לוגין + הזנת תוכן (משתמש רגיל)
- **dashboard.html** — דשבורד אגרגטיבי עם גרפים, מטרות, פילטרים, ארכיון קישורים
- **admin-pool.html** — ניהול מאגר אנשים וארגונים (CRUD, CSV import/export)
- **admin-campaign.html** — יצירת קמפיין חדש (wizard: פרטים → משתתפים → יעדים → סיכום)

### טכנולוגיה

- **Supabase** (PostgreSQL): פרויקט `siufqucjxcuhdfexzfkq`
- **Auth**: לא Supabase Auth — בחירת שם+ארגון מ-dropdown, אימות דרך `login_user` RPC
- **Campaign ID**: `87ffac94-18ab-43e3-bedb-f7cc877973f8`
- **Admin password**: `nadav` (verified server-side via `verify_admin` RPC with SHA-256)
- **RLS**: פתוח לקריאה, כתיבה דרך RPC SECURITY DEFINER

### DB Schema

7 טבלאות: organizations, profiles, campaigns, campaign_participants, campaign_goals, content_entries, metrics_snapshots

10 RPC functions: login_user, get_campaign_pool, get_all_profiles, verify_admin, add_content_entry, update_metrics, delete_content_entry, get_user_contents, get_dashboard_data, get_campaign

### Seed Data

**8 ארגונים:** ויצו, נעמת, דלת פתוחה, לדעת לבחור נכון, איגוד העובדים הסוציאליים, לתת פה, לא לאלימות, קווים אדומים

**10 פרופילים:**
1. מיכל פרינס — קווים אדומים (admin)
2. דנה כהן — ויצו
3. יעל לוי — נעמת
4. רותם שמש — דלת פתוחה
5. אורלי דוד — לדעת לבחור נכון
6. נועה בן דוד — איגוד העובדים הסוציאליים
7. שירה גולן — לתת פה
8. מאיה ברק — לא לאלימות
9. תמר רוזן — קווים אדומים
10. ליאת כץ — ויצו

**קמפיין:** "מניעת אלימות בזוגיות צעירה" (active, 2026-06-22 → 2026-06-28)
**4 יעדים:** חשיפות כוללות (2M), תכנים שהועלו (150), חשיפות ממוצעות לפוסט FB (1000), משתתפים פעילים (50)

### 11 פלטפורמות ו-metrics

- **פייסבוק**: פוסט/סרטון/רילס/סטורי/לייב → likes, comments, shares (engagement), reach (reach), video_views (only סרטון/רילס/לייב)
- **אינסטגרם**: פוסט/רילס/סטורי/קרוסלה → likes, comments, saves (engagement), reach (reach), views (only רילס/סטורי)
- **טיקטוק**: סרטון/לייב → views (reach), likes, comments, shares, saves (engagement)
- **X**: ציוץ/ציוץ מצוטט/תגובה/Thread → likes, retweets, replies (engagement), impressions (reach)
- **לינקדאין**: פוסט/מאמר/סרטון/מסמך → likes, comments, shares (engagement), impressions (reach)
- **ספוטיפיי**: פרק פודקאסט → listens (reach), comments (engagement), new_followers, avg_listen
- **יוטיוב**: סרטון/שורטס/לייב → views (reach), likes, comments, shares (engagement), new_subscribers
- **ניוזלטר**: ניוזלטר/עדכון → recipients (reach), opens, clicks (engagement)
- **עיתון מודפס**: כתבה/מודעה/טור דעה → circulation (reach), page
- **אתר אינטרנט**: כתבה/דף נחיתה/פוסט בבלוג → pageviews (reach), unique_visitors, avg_time
- **וואטסאפ**: סטטוס/הודעה בקבוצה/העברה → views (reach), forwards (engagement), groups_shared

---

## תכנית הבדיקות

השתמש ב-Claude in Chrome כדי לנווט לאתר ולהריץ את כל הבדיקות. כל בדיקה שנכשלת — תקן את הקוד, push ל-GitHub, ותמשיך.

**חשוב:** אתה אחראי לנקות אחרי עצמך — בסוף הבדיקות, מחק את כל ה-test data מ-Supabase דרך SQL Editor כדי להשאיר את ה-DB נקי.

### חלק A — בדיקות לוגין ו-session (form.html)

**A1. טעינת מאגר משתתפים**
- נווט ל-form.html
- ודא ש-dropdown שמות מכיל בדיוק 10 שמות (מ-Supabase, לא hardcoded)
- ודא שארגון ריק עד שבוחרים שם

**A2. מיפוי שם→ארגון**
- בחר "דנה כהן" → ודא שארגון מראה רק "ויצו"
- בחר "מיכל פרינס" → ודא שארגון מראה רק "קווים אדומים"
- בחר "ליאת כץ" → ודא שארגון מראה רק "ויצו" (שני אנשים מאותו ארגון)

**A3. כניסה מוצלחת**
- בחר שם + ארגון → לחץ כניסה
- ודא מעבר למסך אישי עם שם+ארגון+אותיות ראשוניות נכונות
- ודא שהמסך מראה "עדיין לא העלית תכנים"

**A4. Session persistence**
- אחרי כניסה, רענן את הדף (F5)
- ודא שהמשתמש עדיין מחובר (לא חוזר ללוגין)

**A5. החלפת משתמש**
- לחץ "החלף משתמש"
- ודא חזרה למסך לוגין
- ודא ש-localStorage נוקה

### חלק B — הזנת תוכן (form.html) — סימולציית קמפיין

**זה הליבה של הבדיקות.** הזן תוכן עבור 4 משתתפים שונים מ-4 ארגונים שונים כדי לדמות קמפיין אמיתי:

**B1. משתתפת 1 — דנה כהן (ויצו) — פייסבוק**
- התחבר כדנה כהן
- לחץ "הוסף תוכן" → בחר פייסבוק
- סוג: "פוסט" → הזן:
  - קישור: `https://facebook.com/test-post-1`
  - תאריך: 2026-06-23
  - likes: 150, comments: 23, shares: 45, reach: 5200
- שמור → ודא שהתוכן מופיע ברשימה האישית עם הנתונים הנכונים
- הוסף תוכן שני: פייסבוק → "סרטון":
  - קישור: `https://facebook.com/test-video-1`
  - תאריך: 2026-06-24
  - likes: 89, comments: 12, shares: 30, reach: 8400, video_views: 3200
  - ודא ש-video_views מופיע (כי זה סרטון)
- התנתק

**B2. משתתפת 2 — יעל לוי (נעמת) — אינסטגרם + טיקטוק**
- התחבר כיעל לוי
- הוסף תוכן: אינסטגרם → "רילס":
  - קישור: `https://instagram.com/reel/test-1`
  - תאריך: 2026-06-23
  - likes: 340, comments: 56, saves: 120, reach: 12000, views: 8500
  - ודא ש-views מופיע (כי רילס)
- הוסף תוכן: טיקטוק → "סרטון":
  - קישור: `https://tiktok.com/@test/video/1`
  - תאריך: 2026-06-24
  - views: 45000, likes: 3200, comments: 180, shares: 890, saves: 450
- התנתק

**B3. משתתפת 3 — שירה גולן (לתת פה) — ניוזלטר + אתר**
- התחבר כשירה גולן
- הוסף תוכן: ניוזלטר → "ניוזלטר":
  - קישור: `https://mailchimp.com/test-newsletter`
  - תאריך: 2026-06-22
  - recipients: 2500, opens: 890, clicks: 234
- הוסף תוכן: אתר אינטרנט → "כתבה":
  - קישור: `https://example.com/article-1`
  - תאריך: 2026-06-25
  - pageviews: 1800, unique_visitors: 1200, avg_time: 180
- התנתק

**B4. משתתפת 4 — מיכל פרינס (קווים אדומים, admin) — לינקדאין + יוטיוב**
- התחבר כמיכל פרינס
- הוסף תוכן: לינקדאין → "מאמר":
  - קישור: `https://linkedin.com/pulse/test-article`
  - תאריך: 2026-06-23
  - likes: 78, comments: 15, shares: 22, impressions: 4500
- הוסף תוכן: יוטיוב → "סרטון":
  - קישור: `https://youtube.com/watch?v=test123`
  - תאריך: 2026-06-24
  - views: 6700, likes: 320, comments: 45, shares: 88, new_subscribers: 12
- **אל תתנתק** (תישאר מחובר לבדיקות עדכון)

### חלק C — עדכון ומחיקת תוכן (form.html)

**C1. עדכון מטריקות**
- בתור מיכל פרינס, מצא את פוסט הלינקדאין ברשימה
- לחץ "עדכון נתונים"
- שנה: likes: 156, comments: 34, shares: 41, impressions: 9200
- שמור → ודא שהערכים המעודכנים מופיעים

**C2. מחיקת תוכן**
- הוסף תוכן חדש לצורך מחיקה: פייסבוק → "סטורי":
  - קישור: `https://facebook.com/story/delete-me`
  - תאריך: 2026-06-25
  - likes: 10, comments: 2, shares: 1, reach: 500
- מצא אותו ברשימה → לחץ "מחק"
- ודא הודעת אישור → אשר מחיקה
- ודא שנעלם מהרשימה
- התנתק

### חלק D — דשבורד (dashboard.html)

**D1. טעינת נתונים**
- נווט ל-dashboard.html
- ודא שכרטיסי סטטיסטיקה מראים ערכים > 0:
  - חשיפות כוללות (reach+views+impressions+recipients+pageviews)
  - אינטראקציות (likes+comments+shares+saves+opens+clicks+forwards)
  - תכנים (מספר הפריטים שהוזנו, פחות המחוק)
  - משתתפים פעילים (4 — דנה, יעל, שירה, מיכל)

**D2. פילטר פלטפורמה**
- לחץ על chip "פייסבוק" → ודא שרק תכני פייסבוק מוצגים
- לחץ על chip "אינסטגרם" → ודא מעבר
- לחץ על "הכל" → ודא חזרה לתצוגה מלאה

**D3. פילטר ארגון**
- לחץ על ארגון ספציפי (ויצו) → ודא סינון לתכנים של דנה וליאת בלבד
- לחץ "הכל" → חזרה

**D4. יעדים (goals)**
- ודא שמוצגים 4 יעדים עם progress bars
- ודא שיש חישוב % ביחס ליעד

**D5. גרפים**
- ודא שגרף "העלאות תוכן לאורך זמן" מראה נתונים
- ודא שגרף "תכנים לפי פלטפורמה" מראה עמודות
- ודא שגרף "חשיפות לאורך זמן" מראה נתונים
- ודא שגרף "אינטראקציות לפי סוג" מראה פירוט

**D6. ארכיון קישורים**
- גלול לארכיון קישורים
- ודא שכל הקישורים שהוזנו מופיעים
- ודא פילטר לפי פלטפורמה עובד

**D7. נתונים גולמיים**
- ודא שטבלת נתונים גולמיים מראה את כל הרשומות

**D8. גישת אדמין בדשבורד**
- סמן checkbox "מנהל"
- הזן סיסמה "nadav"
- ודא שמופיעים כפתורי אדמין (שינוי סטטוס קמפיין, ייצוא CSV, החלפת נושא)

### חלק E — אדמין: ניהול מאגר (admin-pool.html)

**E1. כניסת אדמין**
- נווט ל-admin-pool.html
- הזן סיסמה "nadav" → ודא כניסה

**E2. צפייה במאגר**
- ודא ש-10 אנשים מוצגים
- ודא ש-8 ארגונים מוצגים

**E3. הוספת ארגון חדש**
- הוסף ארגון: "ארגון בדיקה"
- ודא שמופיע ברשימת ארגונים

**E4. הוספת אדם חדש**
- הוסף: שם "בודק בדיקות", ארגון "ארגון בדיקה", תפקיד "member"
- ודא שמופיע ברשימה

**E5. מחיקת אדם (soft delete)**
- מחק את "בודק בדיקות"
- ודא שנעלם מהתצוגה
- (הוא עדיין ב-DB עם is_active=false)

**E6. ניסיון מחיקת ארגון עם אנשים**
- נסה למחוק ארגון שיש בו אנשים פעילים
- ודא שמופיעה הודעת שגיאה (לא ניתן למחוק)

**E7. מחיקת ארגון ריק**
- מחק את "ארגון בדיקה" (אין בו אנשים פעילים אחרי E5)
- ודא שנמחק בהצלחה

**E8. ייצוא CSV**
- לחץ ייצוא
- ודא שמוריד קובץ CSV תקין

### חלק F — אדמין: יצירת קמפיין (admin-campaign.html)

**F1. כניסת אדמין**
- נווט ל-admin-campaign.html
- הזן סיסמה "nadav"

**F2. Wizard שלב 1 — פרטי קמפיין**
- שם: "קמפיין בדיקות"
- תיאור: "קמפיין לבדיקת המערכת"
- תאריכים: 2026-08-01 → 2026-08-07
- המשך לשלב הבא

**F3. Wizard שלב 2 — משתתפים**
- לחץ "ייבוא מהמאגר" → ודא שכל האנשים הפעילים מיובאים
- ודא שמוצג מספר משתתפים נכון

**F4. Wizard שלב 3 — יעדים**
- הוסף יעד: "חשיפות כוללות", ערך: 1000000
- הוסף יעד: "תכנים שהועלו", ערך: 50
- המשך

**F5. Wizard שלב 4 — סיכום והשקה**
- ודא שהסיכום מציג את כל הפרטים נכון
- **אל תלחץ "השק קמפיין"** — רק ודא שהסיכום תקין
- (לא משיקים כדי לא לזהם את ה-DB)

### חלק G — בדיקות edge cases

**G1. קישור ריק**
- התחבר כמשתמש → נסה להוסיף תוכן בלי קישור
- ודא שעובד (קישור הוא אופציונלי)

**G2. XSS בקישור**
- נסה להזין קישור: `javascript:alert(1)`
- ודא שנחסם (sanitizeLink)

**G3. ערכי metrics אפסיים**
- הזן תוכן עם כל ה-metrics = 0
- ודא ששומר בהצלחה

**G4. Session בדפים שונים**
- התחבר ב-form.html
- עבור ל-dashboard.html
- ודא שה-session נשמר (localStorage)

### חלק H — ניקוי

**H1. מחיקת test data**
- פתח Supabase SQL Editor (`https://supabase.com/dashboard/project/siufqucjxcuhdfexzfkq/sql`)
- הרץ:
```sql
-- Delete test content entries (cascades to metrics_snapshots)
DELETE FROM content_entries WHERE campaign_id = '87ffac94-18ab-43e3-bedb-f7cc877973f8';

-- Delete test campaign if created in part F
DELETE FROM campaigns WHERE name = 'קמפיין בדיקות';

-- Delete test org/profile if still in DB
DELETE FROM profiles WHERE name = 'בודק בדיקות';
DELETE FROM organizations WHERE name = 'ארגון בדיקה';
```
- ודא שה-DB חזר למצב נקי (seed data בלבד, אפס content_entries)

---

## פורמט דיווח

בסוף הבדיקות, כתוב סיכום:
- **עבר ✅ / נכשל ❌** לכל בדיקה
- באגים שנמצאו + האם תוקנו
- המלצות לשיפור
- עדכן את כל קבצי הזיכרון (MEMORY.md וכו') עם תוצאות הבדיקות

---

**התחל מיד. אל תשאל שאלות — כל המידע שאתה צריך נמצא כאן.**
