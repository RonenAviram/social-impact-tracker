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
- **RPC Functions:** login_user, get_campaign_pool, get_all_profiles, verify_admin, add_content_entry, update_metrics, delete_content_entry, get_user_contents, get_dashboard_data, get_campaign

## Multi-Campaign Support
- URL parameter `?campaign=<UUID>` על form.html ו-dashboard.html
- Fallback ל-CONFIG.CAMPAIGN_ID
- Session כוללת campaignId — ניקוי אוטומטי בחוסר התאמה
- Dashboard: allCampaigns[] cache + renderCampaignDropdown()
- מנהל: אייקוני סטטוס (🟢🟡🔴) + chips פילטר
- קמפיין חדש יורש hash סיסמה מהקמפיין העדכני ביותר

## Hosting
- **Repo:** https://github.com/RonenAviram/social-impact-tracker
- **Live:** https://ronenaviram.github.io/social-impact-tracker/
- **Deploy:** GitHub Pages מ-main branch

## Git
- הודעות קומיט באנגלית, קצרות
- לא לבקש אישור לפני קומיט
- פוש דרך CLI (sandbox חוסם git push — המשתמש מריץ ידנית)

## סטטוס (2026-08-12)
- ✅ כל הבאגים תוקנו (16 באגים ב-QA + UAT)
- ✅ 14/14 בדיקות אוטומטיות עוברות
- ✅ Multi-campaign support
- ✅ סיסמת מנהל מסונכרנת (8 קמפיינים)
- 🔄 UAT בתהליך
- ⏳ UAT עם מיכל פרינס
- ⏳ Handoff: fork + Supabase migration לארגון
- ⏳ ניקוי קמפייני בדיקה מה-DB

## כללים
- "Demo = Product" — כל פיצ'ר חייב לעבוד בפרודקשן
- לא להשתמש במילה "בליץ" בממשק
- קופי: ללא ז'רגון טכני, סכמת ירוק כהה, שפה נגישה
