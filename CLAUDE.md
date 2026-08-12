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
| `dashboard.html` | דשבורד אינטראקטיבי + מעבר בין קמפיינים + פאנל מנהל |
| `admin-campaign.html` | אשף יצירת קמפיין עם ירושת סיסמת מנהל |
| `admin-pool.html` | ניהול מאגר משתתפים + ייבוא/ייצוא CSV |
| `spec.html` | שאלון פגישת אפיון |

## Supabase
- **Project:** siufqucjxcuhdfexzfkq.supabase.co
- **Seed Campaign ID:** 87ffac94-18ab-43e3-bedb-f7cc877973f8
- **Admin password:** REDLINES2026 (SHA-256 hash, synced across all campaigns)
- **Tables:** organizations, profiles, campaigns, campaign_participants, campaign_goals, content_entries, metrics_snapshots
- **RPC Functions:** login_user, get_campaign_pool, get_all_profiles, verify_admin, add_content_entry, update_metrics (UPSERT), delete_content_entry, get_user_contents, get_dashboard_data, get_campaign
- **RLS:** SELECT/INSERT/UPDATE/DELETE על כל הטבלאות (כולל campaigns_delete שנוסף 2026-08-12)

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
- **יעדים:** דו-שכבתיים — ראשיים (כלליים: חשיפות, אינטראקציות, תכנים, משתתפים, פלטפורמות) + משניים (לפי פלטפורמה+מדד). ממשק מובנה (dropdowns), לא טקסט חופשי. חישוב בדשבורד לפי goal_type/platform_id/metric_id. מוצגים רק אם הוגדרו.
- **כפתור העתקת קישור טופס:** באזור ניהול, מעתיק URL עם campaign parameter

## Hosting
- **Repo:** https://github.com/RonenAviram/social-impact-tracker
- **Live:** https://ronenaviram.github.io/social-impact-tracker/
- **Deploy:** GitHub Pages מ-main branch

## Git
- הודעות קומיט באנגלית, קצרות
- לא לבקש אישור לפני קומיט
- פוש דרך CLI (sandbox חוסם git push — המשתמש מריץ ידנית)

## SQL Migrations (כולם הורצו אלא אם צוין אחרת)
- `supabase_migration.sql` — סכמה מלאה + seed data
- `supabase_bugfix_migration.sql` — DELETE RLS policy על organizations
- `supabase_fix_password_hash.sql` — סנכרון hash סיסמה (0 rows affected)
- `supabase_uat_fixes.sql` — UPSERT למדדים + unique constraint + ניקוי כפילויות
- `campaigns_delete` policy — הורץ ידנית (לא בקובץ)
- `supabase_goals_migration.sql` — ⏳ **ממתין להרצה** — הרחבת campaign_goals עם goal_type, platform_id, metric_id

## סטטוס (2026-08-12)
- ✅ 24 באגים/שיפורים תוקנו (QA + UAT 4 סבבים + 5 נוספים)
- ✅ 14/14 בדיקות אוטומטיות עוברות
- ✅ Multi-campaign support
- ✅ סיסמת מנהל מסונכרנת
- ✅ מחיקת קמפיינים
- ✅ עיתון מודפס מוחרג מגרפים כלליים
- ✅ Timeline chart מבוסס snapshots עם carry-forward
- ✅ form.html try/catch למניעת תקיעה במובייל
- ✅ 3 קומיטים נדחפו בהצלחה ל-GitHub
- ✅ ממשק יעדים מובנה (ראשיים + משניים לפי פלטפורמה)
- ⚠️ supabase_goals_migration.sql + supabase_fix_password_hash.sql ממתינים להרצה
- 🔄 הכנת סביבת UAT למיכל פרינס
- ⏳ UAT עם מיכל פרינס
- ⏳ Handoff: fork + Supabase migration לארגון

## כללים
- "Demo = Product" — כל פיצ'ר חייב לעבוד בפרודקשן
- לא להשתמש במילה "בליץ" בממשק
- קופי: ללא ז'רגון טכני, סכמת ירוק כהה, שפה נגישה
