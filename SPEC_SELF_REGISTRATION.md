# אפיון: הרשמה עצמית + ארגון "אחר" + תיקוני UX

**תאריך:** 2026-08-17
**סטטוס:** מאושר לפיתוח

---

## 1. הרשמה עצמית של משתתפים

### מצב קיים
מיכל יוצרת פרופילים ב-admin-pool.html ומוסיפה משתתפים לקמפיין ידנית. משתמשים בוחרים את עצמם מרשימה ב-form.html.

### מצב חדש
משתמשים נרשמים בעצמם דרך לינק הקמפיין. מיכל מנהלת ארגונים ויכולה להשהות/להוסיף משתתפים.

### flow משתמש — form.html

**מסך כניסה (חדש):**
- המשתמש מגיע דרך לינק קמפיין (`form.html?campaign=UUID`)
- שם הקמפיין מוצג ככותרת בולטת בכל מסך
- שתי אפשרויות: "הרשמה לקמפיין" / "כבר נרשמתי"

**הרשמה חדשה:**
- שדות: שם מלא, דוא"ל, ארגון (dropdown מ-DB + אופציית "אחר")
- ולידציית מייל: פורמט תקין (regex) + ייחודיות מול DB
- בחירת "אחר" פותחת שדה טקסט חופשי לשם הארגון
- אחרי הרשמה → נוצר profile (אם לא קיים) + מתווסף ל-campaign_participants → כניסה ישירה לאזור האישי
- אם המייל כבר קיים → מתנהג כמו "כבר נרשמתי" (מוסיף ל-campaign_participants ונכנס)

**כניסה חוזרת ("כבר נרשמתי"):**
- dropdown עם כל השמות הקיימים במערכת (מכל הקמפיינים)
- בחירת שם → מוצג אוטומטית: מייל + ארגון (מה-DB) לאישור
- שם כפול: מוצגות כרטיסיות עם מייל+ארגון לכל רשומה — המשתמש בוחר
- כפתור "כניסה" (לא "הרשמה וכניסה")
- אם הפרופיל לא משויך לקמפיין הנוכחי → מתווסף אוטומטית

### ניהול משתתפים — דשבורד (מצב מנהל)

**פאנל משתתפים (קיים, מורחב):**
- נשאר כמו שהוא + תוספות:
- עמודת מייל לכל משתתף
- כפתור "השהה" → `status = 'suspended'` ב-campaign_participants
- כפתור "הפעל מחדש" → `status = 'active'`
- כפתור "הוסף ידנית" (שם + מייל + ארגון) — למקרים שמישהו מסתבך
- כפתור "עריכת פרטים" — לתיקון טעויות בשם/מייל
- באדג' סטטוס: "פעיל" (ירוק) / "מושהה" (צהוב)
- ספירה: "7 פעילים · 1 מושהה"

**משתתף מושהה:**
- לא יכול להעלות תכנים או לעדכן נתונים
- רואה באנר: "ההשתתפות שלך בקמפיין הושהתה — לפרטים פנה/י למנהלת"
- כפתורי "הוסף תוכן" / "עדכן נתונים" / "מחק" — disabled
- התכנים הקיימים שלו נשארים בדשבורד
- מסך כניסה עובד — מזהה אותו, אבל מציג מצב מושהה (כמו קמפיין מושהה)

### admin-campaign.html

- אשף יצירת קמפיין **נשאר כמו שהוא** כולל שלב המשתתפים
- תוספת הודעה בשלב המשתתפים: "ניתן להשאיר ריק — משתתפים יוכלו להירשם בעצמם דרך הלינק"
- מיכל יכולה לצרף אנשים מראש אם רוצה (גמישות מקסימלית)

### admin-pool.html

- חלק ניהול האנשים **יורד**
- נשאר **רק ניהול ארגונים**: הוספה, עריכה, מחיקה
- כותרת הדף משתנה ל"ניהול ארגונים" (או שם מתאים)

---

## 2. ארגון "אחר"

### DB
- רשומה קבועה בטבלת organizations: `name = 'אחר'`
- עמודה חדשה `custom_org_name` (TEXT, nullable) בטבלת profiles

### UI
- בטופס הרשמה: כשנבחר "אחר" → נפתח שדה טקסט חופשי "שם הארגון שלך"
- בדשבורד, פאנל משתתפים, ובכל מקום: מוצג "אחר — [שם שהוזן]"
- בפילטר ארגונים בדשבורד: "אחר" כקטגוריה אחת שמאגדת את כולם

---

## 3. תיקון UX — מעבר ישיר אחרי הזנת תוכן

### מצב קיים
אחרי הזנת תוכן מוצלחת, מוצג screenSuccess עם שתי אפשרויות (אזור אישי / דשבורד).

### מצב חדש
- אחרי הזנת תוכן → toast הצלחה + מעבר ישיר לאזור האישי (screenPersonal)
- אחרי עדכון נתונים → toast הצלחה + מעבר ישיר לאזור האישי
- screenSuccess **נמחק לגמרי**
- קישור לדשבורד נשאר באזור האישי (כבר קיים)

---

## 4. שינויי DB (Supabase)

### שינויים בטבלאות

```sql
-- profiles: הוספת email + custom_org_name
ALTER TABLE profiles ADD COLUMN email TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN custom_org_name TEXT;

-- campaign_participants: הוספת status
ALTER TABLE campaign_participants ADD COLUMN status TEXT NOT NULL DEFAULT 'active'
  CHECK (status IN ('active', 'suspended'));

-- organizations: הוספת ארגון "אחר"
INSERT INTO organizations (name) VALUES ('אחר');
```

### הסרת seed profiles
פרופילים פיקטיביים (דנה כהן, יעל לוי וכו') יימחקו. נשארים רק ארגונים.

### RPCs חדשים

```
register_profile(p_name, p_email, p_org_id, p_custom_org_name, p_campaign_id)
  → יוצר profile (אם לא קיים לפי email) + מוסיף ל-campaign_participants
  → מחזיר profile_id
  → ON CONFLICT (email): מוסיף רק ל-campaign_participants

find_profiles_by_name(p_name)
  → מחזיר: profile_id, name, email, org_name, custom_org_name
  → לשימוש בדרופדאון "כבר נרשמתי"

get_all_profiles_for_login()
  → מחזיר את כל השמות הייחודיים + email + org לדרופדאון כניסה

suspend_participant(p_campaign_id, p_profile_id)
  → UPDATE campaign_participants SET status = 'suspended'

reactivate_participant(p_campaign_id, p_profile_id)
  → UPDATE campaign_participants SET status = 'active'
```

### עדכון RPCs קיימים

```
add_content_entry — הוספת בדיקת status = 'active' ב-campaign_participants
update_metrics — הוספת JOIN ל-campaign_participants עם בדיקת status = 'active'
get_campaign_pool — החזרת email, custom_org_name, status
get_dashboard_data — החזרת custom_org_name
get_all_profiles — החזרת email, custom_org_name
```

---

## 5. שינויים בקבצים

| קובץ | שינוי |
|---|---|
| `config.js` | הוספת email ל-setSession |
| `form.html` | מסך כניסה חדש (הרשמה/כבר נרשמתי), הסרת screenSuccess, שם קמפיין בולט, באנר מושהה |
| `dashboard.html` | פאנל משתתפים: מייל, השהיה/הפעלה, הוספה ידנית, עריכת פרטים, פילטר "אחר" |
| `admin-campaign.html` | הודעה בשלב משתתפים שניתן להשאיר ריק |
| `admin-pool.html` | הסרת ניהול אנשים, השארת ניהול ארגונים בלבד |
| `training-package.html` | עדכון לשקף flow חדש (לא בשלב זה, לפני deployment) |

---

## 6. edge cases מטופלים

- **שם כפול:** דרופדאון מראה שם פעם אחת → כרטיסיות עם מייל+ארגון לבחירה
- **מייל כפול בהרשמה:** מזוהה כפרופיל קיים → מתנהג כ"כבר נרשמתי"
- **UNIQUE(name, org_id):** שני אנשים עם אותו שם באותו ארגון → חסימה (נדיר, מיכל מוסיפה ידנית עם שם מעט שונה)
- **Upsert באותו יום:** add_content_entry יוצר snapshot עם 0 → update_metrics דורס באותו תאריך (ON CONFLICT). עובד תקין.
- **משתתף מושהה:** add_content_entry ו-update_metrics בודקים status. client-side: כפתורים disabled + באנר.
- **פרופילים ישנים בלי מייל:** email nullable. בדרופדאון מוצג "לא הוזן מייל".
- **admin-campaign + self-registration:** שניהם כותבים ל-campaign_participants. INSERT ON CONFLICT DO NOTHING מונע כפילויות.
