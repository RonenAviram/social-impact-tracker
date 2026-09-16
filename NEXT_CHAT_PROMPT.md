קרא את SPEC_SELF_REGISTRATION.md ואת CLAUDE.md. אלה מעודכנים לגמרי.

צריך לפתח את שלושת השינויים שמתוארים באפיון:
1. הרשמה עצמית של משתתפים (form.html + DB)
2. ארגון "אחר" (DB + form.html + dashboard.html)
3. תיקון UX — מעבר ישיר לאזור אישי אחרי הזנת תוכן (form.html)

סדר עבודה מומלץ:
1. DB migration (supabase_self_registration.sql) — email + custom_org_name ב-profiles, status ב-campaign_participants, ארגון "אחר", RPCs חדשים, עדכון RPCs קיימים, הסרת seed profiles
2. form.html — מסך כניסה חדש, flow הרשמה, flow "כבר נרשמתי", הסרת screenSuccess, באנר מושהה, שם קמפיין בולט
3. dashboard.html — פאנל משתתפים: מייל, השהיה/הפעלה, הוספה ידנית, עריכת פרטים, פילטר "אחר"
4. admin-pool.html — הסרת ניהול אנשים, השארת ניהול ארגונים
5. admin-campaign.html — הודעה בשלב משתתפים שניתן להשאיר ריק
6. config.js — עדכון setSession עם email, הוספת "אחר" ל-ORGS

תתחיל ב-DB migration ותראה לי את ה-SQL לפני שנריץ.
