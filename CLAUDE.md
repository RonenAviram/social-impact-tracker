# Social Impact Tracker — קווים אדומים

## מה זה
מערכת מדידת אימפקט ברשתות חברתיות עבור "קווים אדומים" — שותפות ישראלית למניעת אלימות בזוגיות. משתמשים מזינים תכנים שפרסמו, המערכת מציגה דשבורד מצרפי.

## ארכיטקטורה
- **Frontend:** 6 קבצי HTML סטטיים על GitHub Pages
- **Backend:** Supabase (PostgreSQL + RPC functions + RLS)
- **Config:** `config.js` — single source of truth לכל הקבצים
- **Auth:** anon key + הרשמה עצמית (שם + מייל + ארגון). ללא סיסמה למשתמשים. כניסה חוזרת לפי בחירת שם מדרופדאון

## קבצים
| קובץ | תפקיד |
|---|---|
| `config.js` | הגדרות (11 פלטפורמות, 9 ארגונים כולל "אחר", Supabase client, session helpers) |
| `form.html` | הרשמה עצמית + כניסה + אשף הזנת תוכן רב-שלבי עם campaign routing |
| `dashboard.html` | דשבורד אינטראקטיבי + מעבר בין קמפיינים + פאנל מנהל (כולל השהיית משתתפים) + עריכת יעדים |
| `admin-campaign.html` | אשף יצירת קמפיין עם ירושת סיסמת מנהל + ממשק יעדים מובנה + הוספת משתתפים (אופציונלי) |
| `admin-pool.html` | ניהול ארגונים בלבד (הוספה/עריכה/מחיקה) |
| `training-package.html` | מארז הדרכה למנהלת המערכת (טקסט בלבד, ירוק כהה) |
| `spec.html` | שאלון פגישת אפיון |

## Supabase
- **Project:** siufqucjxcuhdfexzfkq.supabase.co
- **Seed Campaign ID:** 87ffac94-18ab-43e3-bedb-f7cc877973f8
- **Admin password:** REDLINES2026 (SHA-256 hash, synced across all campaigns)
- **Tables:** organizations, profiles (עם email + custom_org_name), campaigns, campaign_participants (עם status: active/suspended), campaign_goals, content_entries, metrics_snapshots
- **RPC Functions:** login_user, get_campaign_pool (+ email/status), get_all_profiles (+ email), verify_admin (3-tier fallback), add_content_entry (+ status check), update_metrics (UPSERT + status check), delete_content_entry, get_user_contents, get_dashboard_data (+ custom_org_name), get_campaign, get_campaign_snapshots, register_profile (חדש), find_profiles_by_name (חדש), get_all_profiles_for_login (חדש), suspend_participant (חדש), reactivate_participant (חדש)
- **RLS:** SELECT/INSERT/UPDATE/DELETE על כל הטבלאות (כולל campaigns_delete, snapshots_delete)
- **DEFAULT_ADMIN_HASH:** SHA-256 של REDLINES2026 — fallback ב-config.js + verify_admin RPC כשאין קמפיינים

## Multi-Campaign Support
- URL parameter `?campaign=<UUID>` על form.html ו-dashboard.html
- Fallback ל-CONFIG.CAMPAIGN_ID
- Session כוללת campaignId — ניקוי אוטומטי בחוסר התאמה
- Dashboard: allCampaigns[] cache + renderCampaignDropdown()
- מנהל: אייקוני סטטוס (🟢🟡🔴) + chips פילטר צמודים לדרופדאון
- קמפיין חדש יורש hash סיסמה מהקמפיין העדכני ביותר
- מחיקת קמפיין: CASCADE על כל הנתונים (תכנים, מדדים, יעדים, משתתפים)

## התנהגויות מפתח
- **סיום קמפיין:** רק ידנית ע"י מנהל. end_date לא מסיים אוטומטית — מנהל מקבל התראה צהובה שהתאריך עבר
- **הזנת תוכן בקמפיין לא פעיל:** כפתור disabled (לא alert), באנר מוצג
- **משתתף מושהה:** כפתורים disabled + באנר "ההשתתפות הושהתה" (כמו קמפיין מושהה). תכנים קיימים נשארים בדשבורד
- **הרשמה עצמית:** משתמשים נרשמים דרך לינק קמפיין (שם + מייל + ארגון). מייל קיים = כניסה + הוספה לקמפיין. שם כפול = כרטיסיות בחירה עם מייל+ארגון
- **ארגון "אחר":** שדה טקסט חופשי לשם ארגון, נשמר ב-custom_org_name. מוצג כ"אחר — [שם]"
- **אחרי הזנת תוכן:** מעבר ישיר לאזור אישי (ללא מסך הצלחה ביניים). toast בלבד
- **עדכון מדדים:** UPSERT — עדכון שני באותו יום דורס את הקודם (unique constraint על content_entry_id + snapshot_date)
- **ארכיון קישורים:** עצמאי מפילטרי הגרפים
- **גרפים:** ציר Y מציג רק מספרים שלמים
- **עיתון מודפס:** מוחרג מכל הגרפים/מדדים אלא אם הוא הפלטפורמה היחידה שנבחרה בפילטר
- **יעדים:** דו-שכבתיים — ראשיים (כלליים: חשיפות, אינטראקציות, תכנים, יוצרי תוכן, פלטפורמות) + משניים (לפי פלטפורמה+מדד). ממשק מובנה (dropdowns), לא טקסט חופשי. חישוב בדשבורד לפי goal_type/platform_id/metric_id. מוצגים רק אם הוגדרו.
- **כפתור העתקת קישור טופס:** באזור ניהול, מעתיק URL עם campaign parameter
- **פילטר ארגונים:** דינמי — נבנה ממשתתפי הקמפיין (get_campaign_pool) + ארגונים מתכנים שהועלו
- **ניהול משתתפים מדשבורד:** כפתור סגול "משתתפים בקמפיין" במצב מנהל — מציג משתתפים עם מייל, באדג' סטטוס, כפתורי השהה/הפעל, הוספה ידנית, עריכת פרטים
- **activeCampaignId:** נבדק מול allCampaigns — אם לא קיים, נופל לקמפיין הראשון ברשימה
- **כרטיסיית דשבורד:** "יוצרי תוכן פעילים" (לא "משתתפים")

## Hosting
- **Repo:** https://github.com/RonenAviram/social-impact-tracker
- **Live:** https://ronenaviram.github.io/social-impact-tracker/
- **Deploy:** GitHub Pages מ-main branch

## Git
- הודעות קומיט באנגלית, קצרות
- לא לבקש אישור לפני קומיט
- פוש דרך CLI (sandbox חוסם git push — המשתמש מריץ ידנית)

## SQL Migrations (כולם הורצו)
- `supabase_migration.sql` — סכמה מלאה + seed data
- `supabase_bugfix_migration.sql` — DELETE RLS policy על organizations
- `supabase_fix_password_hash.sql` — סנכרון hash סיסמה
- `supabase_uat_fixes.sql` — UPSERT למדדים + unique constraint + ניקוי כפילויות
- `campaigns_delete` policy — הורץ ידנית (לא בקובץ)
- `supabase_goals_migration.sql` — הרחבת campaign_goals עם goal_type, platform_id, metric_id
- `supabase_verify_admin_fix.sql` — verify_admin 3-tier fallback + snapshots_delete policy
- `supabase_self_registration.sql` — ✅ הורץ: email + custom_org_name ב-profiles, status ב-campaign_participants, ארגון "אחר", RPCs חדשים, הסרת seed profiles

## סטטוס (2026-08-17)
- ✅ 24+ באגים/שיפורים תוקנו (QA + UAT 4 סבבים + 5 נוספים + סשן 13/8)
- ✅ 14/14 בדיקות אוטומטיות עוברות
- ✅ Multi-campaign support
- ✅ סיסמת מנהל מסונכרנת + 3-tier fallback (campaign → any campaign → default hash)
- ✅ מחיקת קמפיינים
- ✅ עיתון מודפס מוחרג מגרפים כלליים
- ✅ Timeline chart מבוסס snapshots עם carry-forward
- ✅ form.html try/catch למניעת תקיעה במובייל
- ✅ ממשק יעדים מובנה (ראשיים + משניים לפי פלטפורמה)
- ✅ עריכת יעדים ממצב מנהל בדשבורד (inline, בלי prompt)
- ✅ ולידציה: יעד בלי מספר חוסם המשך + highlight אדום
- ✅ כל ה-SQL migrations הורצו בהצלחה
- ✅ ניהול משתתפים מדשבורד (כפתור סגול, בחר/נקה הכל, צבעים)
- ✅ פילטר ארגונים דינמי מהקמפיין
- ✅ כרטיסייה "יוצרי תוכן פעילים" + מקרא חשיפות בגרף
- ✅ activeCampaignId fallback לקמפיין ראשון כשה-seed לא קיים
- ✅ cleanup.html — כלי ניקוי נתונים לפני UAT
- ✅ מארז הדרכה למיכל פרינס (training-package.html — טקסט בלבד, ירוק כהה, 11 סעיפים)
- ✅ מייל נשלח למיכל פרינס (2026-08-13) עם לינקים לדשבורד + מארז הדרכה
- 🔄 UAT עם מיכל פרינס — ממתינים להערות
- ✅ הרשמה עצמית + ארגון "אחר" + תיקוני UX — פותח (form.html, dashboard.html, admin-pool.html, admin-campaign.html, config.js, DB migration)
- ⏳ תכנית הגשה (submission plan) — לתכנן בצ'אט הבא
- ⏳ Handoff: fork + Supabase migration לארגון

## Training Package — עדכונים נדרשים
- כלל: כל שינוי ב-flow של משתמש/מנהל חייב להתעדכן גם ב-training-package.html
- שינויים ממתינים: הרשמה עצמית, מסך כניסה חדש, השהיית משתתפים, ארגון "אחר", הסרת מסך הצלחה
- לעדכן לפני deployment

## כללים
- "Demo = Product" — כל פיצ'ר חייב לעבוד בפרודקשן
- לא להשתמש במילה "בליץ" בממשק
- קופי: ללא ז'רגון טכני, סכמת ירוק כהה, שפה נגישה
