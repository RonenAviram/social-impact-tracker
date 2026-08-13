# Social Impact Tracker — קווים אדומים

## מה זה
מערכת מדידת אימפקט ברשתות חברתיות עבור "קווים אדומים" — שותפות ישראלית למניעת אלימות בזוגיות. משתמשים מזינים תכנים שפרסמו, המערכת מציגה דשבורד מצרפי.

## ארכיטקטורה
- **Frontend:** 5 קבצי HTML סטטיים על GitHub Pages
- **Backend:** Supabase (PostgreSQL + RPC functions + RLS)
- **Config:** `config.js` — single source of truth לכל הקבצים
- **Auth:** anon key + בחירת שם/ארגון (ללא הרשמה)

## קבצים
| קובץ | תפקיד |
|---|---|
| `config.js` | הגדרות (11 פלטפורמות, 8 ארגונים, Supabase client, session helpers) |
| `form.html` | אשף הזנת תוכן רב-שלבי עם campaign routing |
| `dashboard.html` | דשבורד אינטראקטיבי + מעבר בין קמפיינים + פאנל מנהל + עריכת יעדים |
| `admin-campaign.html` | אשף יצירת קמפיין עם ירושת סיסמת מנהל + ממשק יעדים מובנה |
| `admin-pool.html` | ניהול מאגר משתתפים + ייבוא/ייצוא CSV |
| `spec.html` | שאלון פגישת אפיון |

## Supabase
- **Project:** siufqucjxcuhdfexzfkq.supabase.co
- **Seed Campaign ID:** 87ffac94-18ab-43e3-bedb-f7cc877973f8
- **Admin password:** REDLINES2026 (SHA-256 hash, synced across all campaigns)
- **Tables:** organizations, profiles, campaigns, campaign_participants, campaign_goals, content_entries, metrics_snapshots
- **RPC Functions:** login_user, get_campaign_pool, get_all_profiles, verify_admin (3-tier fallback), add_content_entry, update_metrics (UPSERT), delete_content_entry, get_user_contents, get_dashboard_data, get_campaign, get_campaign_snapshots
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
- **עדכון מדדים:** UPSERT — עדכון שני באותו יום דורס את הקודם (unique constraint על content_entry_id + snapshot_date)
- **ארכיון קישורים:** עצמאי מפילטרי הגרפים
- **גרפים:** ציר Y מציג רק מספרים שלמים
- **עיתון מודפס:** מוחרג מכל הגרפים/מדדים אלא אם הוא הפלטפורמה היחידה שנבחרה בפילטר
- **יעדים:** דו-שכבתיים — ראשיים (כלליים: חשיפות, אינטראקציות, תכנים, יוצרי תוכן, פלטפורמות) + משניים (לפי פלטפורמה+מדד). ממשק מובנה (dropdowns), לא טקסט חופשי. חישוב בדשבורד לפי goal_type/platform_id/metric_id. מוצגים רק אם הוגדרו.
- **כפתור העתקת קישור טופס:** באזור ניהול, מעתיק URL עם campaign parameter
- **פילטר ארגונים:** דינמי — נבנה ממשתתפי הקמפיין (get_campaign_pool) + ארגונים מתכנים שהועלו
- **ניהול משתתפים מדשבורד:** כפתור סגול "משתתפים בקמפיין" במצב מנהל — מציג כל הפרופילים, מסמן בירוק מי בקמפיין, בחר/נקה הכל
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

## סטטוס (2026-08-13)
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
- 🔄 מארז הדרכה למיכל פרינס (דרוש שכתוב — ללא צילומי מסך, טקסט בלבד)
- ⏳ UAT עם מיכל פרינס
- ⏳ Handoff: fork + Supabase migration לארגון

## כללים
- "Demo = Product" — כל פיצ'ר חייב לעבוד בפרודקשן
- לא להשתמש במילה "בליץ" בממשק
- קופי: ללא ז'רגון טכני, סכמת ירוק כהה, שפה נגישה
