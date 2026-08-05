// =================== CONFIG — מקור אמת אחד ===================
// קובץ זה נטען ע"י form.html, dashboard.html, admin-campaign.html, admin-pool.html
// שינוי כאן = שינוי בכל המערכת

const CONFIG = {

  // === פלטפורמות ===
  // כל פלטפורמה מגדירה: id, name, icon, color (לגרפים), types (סוגי תוכן), metrics (נתונים למדידה)
  // metrics.onlyTypes — אם מוגדר, הנתון רלוונטי רק לסוגי תוכן מסוימים
  // metrics.isReach — סימון שהנתון הזה נחשב "חשיפות" לצורך סיכום בדשבורד
  // metrics.isEngagement — סימון שהנתון הזה נחשב "אינטראקציה" לצורך סיכום בדשבורד
  PLATFORMS: [
    {
      id: 'facebook', name: 'פייסבוק', icon: '📘', color: '#378ADD',
      types: ['פוסט', 'סרטון', 'רילס', 'סטורי', 'לייב'],
      metrics: [
        { id: 'likes', label: 'לייקים', isEngagement: true },
        { id: 'comments', label: 'תגובות', isEngagement: true },
        { id: 'shares', label: 'שיתופים', isEngagement: true },
        { id: 'reach', label: 'חשיפות', isReach: true },
        { id: 'video_views', label: 'צפיות וידאו', onlyTypes: ['סרטון', 'רילס', 'לייב'] }
      ]
    },
    {
      id: 'instagram', name: 'אינסטגרם', icon: '📸', color: '#D4537E',
      types: ['פוסט', 'רילס', 'סטורי', 'קרוסלה'],
      metrics: [
        { id: 'likes', label: 'לייקים', isEngagement: true },
        { id: 'comments', label: 'תגובות', isEngagement: true },
        { id: 'saves', label: 'שמירות', isEngagement: true },
        { id: 'reach', label: 'חשיפות', isReach: true },
        { id: 'views', label: 'צפיות', onlyTypes: ['רילס', 'סטורי'] }
      ]
    },
    {
      id: 'tiktok', name: 'טיקטוק', icon: '🎵', color: '#212529',
      types: ['סרטון', 'לייב'],
      metrics: [
        { id: 'views', label: 'צפיות', isReach: true },
        { id: 'likes', label: 'לייקים', isEngagement: true },
        { id: 'comments', label: 'תגובות', isEngagement: true },
        { id: 'shares', label: 'שיתופים', isEngagement: true },
        { id: 'saves', label: 'שמירות', isEngagement: true }
      ]
    },
    {
      id: 'twitter', name: 'X (טוויטר)', icon: '𝕏', color: '#1D9E75',
      types: ['ציוץ', 'ציוץ מצוטט', 'תגובה', 'Thread'],
      metrics: [
        { id: 'likes', label: 'לייקים', isEngagement: true },
        { id: 'retweets', label: 'ריטוויטים', isEngagement: true },
        { id: 'replies', label: 'תגובות', isEngagement: true },
        { id: 'impressions', label: 'חשיפות', isReach: true }
      ]
    },
    {
      id: 'linkedin', name: 'לינקדאין', icon: '💼', color: '#185FA5',
      types: ['פוסט', 'מאמר', 'סרטון', 'מסמך'],
      metrics: [
        { id: 'likes', label: 'לייקים', isEngagement: true },
        { id: 'comments', label: 'תגובות', isEngagement: true },
        { id: 'shares', label: 'שיתופים', isEngagement: true },
        { id: 'impressions', label: 'חשיפות', isReach: true }
      ]
    },
    {
      id: 'spotify', name: 'ספוטיפיי', icon: '🎧', color: '#639922',
      types: ['פרק פודקאסט'],
      metrics: [
        { id: 'listens', label: 'האזנות', isReach: true },
        { id: 'comments', label: 'תגובות', isEngagement: true },
        { id: 'new_followers', label: 'עוקבים חדשים' },
        { id: 'avg_listen', label: 'דקות האזנה ממוצעות' }
      ]
    },
    {
      id: 'youtube', name: 'יוטיוב', icon: '▶️', color: '#FF0000',
      types: ['סרטון', 'שורטס', 'לייב'],
      metrics: [
        { id: 'views', label: 'צפיות', isReach: true },
        { id: 'likes', label: 'לייקים', isEngagement: true },
        { id: 'comments', label: 'תגובות', isEngagement: true },
        { id: 'shares', label: 'שיתופים', isEngagement: true },
        { id: 'new_subscribers', label: 'מנויים חדשים' }
      ]
    },
    {
      id: 'email', name: 'ניוזלטר', icon: '📧', color: '#EF9F27',
      types: ['ניוזלטר', 'עדכון'],
      metrics: [
        { id: 'recipients', label: 'נמענים', isReach: true },
        { id: 'opens', label: 'פתיחות', isEngagement: true },
        { id: 'clicks', label: 'הקלקות', isEngagement: true }
      ]
    },
    {
      id: 'newspaper', name: 'עיתון מודפס', icon: '📰', color: '#854F0B',
      types: ['כתבה', 'מודעה', 'טור דעה'],
      metrics: [
        { id: 'circulation', label: 'תפוצה (עותקים)', isReach: true },
        { id: 'page', label: 'מספר עמוד' }
      ]
    },
    {
      id: 'website', name: 'אתר אינטרנט', icon: '🌐', color: '#534AB7',
      types: ['כתבה', 'דף נחיתה', 'פוסט בבלוג'],
      metrics: [
        { id: 'pageviews', label: 'צפיות בדף', isReach: true },
        { id: 'unique_visitors', label: 'מבקרים ייחודיים' },
        { id: 'avg_time', label: 'זמן ממוצע בדף (שניות)' }
      ]
    },
    {
      id: 'whatsapp', name: 'וואטסאפ', icon: '💬', color: '#25D366',
      types: ['סטטוס', 'הודעה בקבוצה', 'העברה'],
      metrics: [
        { id: 'views', label: 'צפיות', isReach: true },
        { id: 'forwards', label: 'העברות', isEngagement: true },
        { id: 'groups_shared', label: 'קבוצות ששותפו' }
      ]
    }
  ],

  // === ארגונים ===
  ORGS: ['ויצו', 'נעמת', 'דלת פתוחה', 'לדעת לבחור נכון', 'איגוד העובדים הסוציאליים', 'לתת פה', 'לא לאלימות', 'קווים אדומים'],

  // === Helper functions ===

  // מחזיר פלטפורמה לפי ID
  getPlatform(id) {
    return this.PLATFORMS.find(p => p.id === id);
  },

  // מחזיר את ה-metrics הרלוונטיים לסוג תוכן מסוים
  getMetricsForType(platformId, contentType) {
    const plat = this.getPlatform(platformId);
    if (!plat) return [];
    return plat.metrics.filter(m => !m.onlyTypes || m.onlyTypes.includes(contentType));
  },

  // מחזיר engKeys ו-engLabels לפלטפורמה (תואם למה שדשבורד צריך)
  getEngKeysLabels(platformId) {
    const plat = this.getPlatform(platformId);
    if (!plat) return { keys: [], labels: [] };
    return {
      keys: plat.metrics.map(m => m.id),
      labels: plat.metrics.map(m => m.label)
    };
  },

  // מחזיר רק metrics שהם reach (לסיכום חשיפות)
  getReachMetricIds(platformId) {
    const plat = this.getPlatform(platformId);
    if (!plat) return [];
    return plat.metrics.filter(m => m.isReach).map(m => m.id);
  },

  // מחזיר רק metrics שהם engagement (לסיכום אינטראקציות)
  getEngagementMetricIds(platformId) {
    const plat = this.getPlatform(platformId);
    if (!plat) return [];
    return plat.metrics.filter(m => m.isEngagement).map(m => m.id);
  },

  // מייצר UUID פשוט (יוחלף ב-Supabase UUID בבקאנד)
  generateId() {
    return 'c_' + Date.now().toString(36) + '_' + Math.random().toString(36).substr(2, 6);
  }
};
