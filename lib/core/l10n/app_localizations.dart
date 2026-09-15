import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Supported locales. French is the default/primary language.
abstract final class StegLocales {
  static const french = Locale('fr');
  static const english = Locale('en');
  static const arabic = Locale('ar');

  static const supported = [french, english, arabic];

  static bool isRtl(Locale locale) => locale.languageCode == 'ar';

  static Locale resolve(String? code) => switch (code) {
        'en' => english,
        'ar' => arabic,
        _ => french,
      };
}

/// Minimal hand-rolled localization (no codegen) covering the D0
/// foundation strings in fr/en/ar. Feature strings are added per phase
/// in the same tables — never hard-coded in widgets.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  static const _values = <String, Map<String, String>>{
    'appTitle': {
      'fr': 'STEG — Compagnon de stage',
      'en': 'STEG — Internship Companion',
      'ar': 'STEG — رفيق التربص',
    },
    'loginTitle': {
      'fr': 'Connexion',
      'en': 'Sign in',
      'ar': 'تسجيل الدخول',
    },
    'email': {'fr': 'E-mail', 'en': 'Email', 'ar': 'البريد الإلكتروني'},
    'password': {'fr': 'Mot de passe', 'en': 'Password', 'ar': 'كلمة المرور'},
    'loginAction': {
      'fr': 'Se connecter',
      'en': 'Sign in',
      'ar': 'دخول',
    },
    'logout': {'fr': 'Déconnexion', 'en': 'Sign out', 'ar': 'تسجيل الخروج'},
    'emailRequired': {
      'fr': 'Veuillez saisir une adresse e-mail valide.',
      'en': 'Please enter a valid email address.',
      'ar': 'يرجى إدخال عنوان بريد إلكتروني صالح.',
    },
    'passwordRequired': {
      'fr': 'Veuillez saisir votre mot de passe.',
      'en': 'Please enter your password.',
      'ar': 'يرجى إدخال كلمة المرور.',
    },
    'offline': {
      'fr': 'Hors ligne — les données affichées peuvent être obsolètes.',
      'en': 'Offline — displayed data may be stale.',
      'ar': 'غير متصل — قد تكون البيانات المعروضة قديمة.',
    },
    'online': {'fr': 'En ligne', 'en': 'Online', 'ar': 'متصل'},
    'retry': {'fr': 'Réessayer', 'en': 'Retry', 'ar': 'إعادة المحاولة'},
    'loading': {'fr': 'Chargement…', 'en': 'Loading…', 'ar': 'جارٍ التحميل…'},
    'emptyTitle': {'fr': 'Rien ici pour le moment', 'en': 'Nothing here yet', 'ar': 'لا يوجد شيء بعد'},
    'roleIntern': {'fr': 'Stagiaire', 'en': 'Intern', 'ar': 'متربص'},
    'roleSupervisor': {
      'fr': 'Encadrant',
      'en': 'Supervisor',
      'ar': 'المؤطر',
    },
    'navHome': {'fr': 'Accueil', 'en': 'Home', 'ar': 'الرئيسية'},
    'navTasks': {'fr': 'Tâches', 'en': 'Tasks', 'ar': 'المهام'},
    'navJournal': {'fr': 'Journal', 'en': 'Journal', 'ar': 'اليومية'},
    'navMessages': {'fr': 'Messages', 'en': 'Messages', 'ar': 'الرسائل'},
    'navMore': {'fr': 'Plus', 'en': 'More', 'ar': 'المزيد'},
    'navInterns': {'fr': 'Stagiaires', 'en': 'Interns', 'ar': 'المتربصون'},
    'navValidations': {
      'fr': 'Validations',
      'en': 'Validations',
      'ar': 'المصادقات',
    },
    'comingSoon': {
      'fr': 'Disponible dans la prochaine phase.',
      'en': 'Available in the next phase.',
      'ar': 'متاح في المرحلة القادمة.',
    },
    'unsupportedRole': {
      'fr': 'Ce rôle n’est pas pris en charge dans l’application mobile.',
      'en': 'This role is not supported in the mobile app.',
      'ar': 'هذا الدور غير مدعوم في تطبيق الهاتف.',
    },
    'language': {'fr': 'Langue', 'en': 'Language', 'ar': 'اللغة'},
    'theme': {'fr': 'Thème', 'en': 'Theme', 'ar': 'المظهر'},
    'themeSystem': {'fr': 'Système', 'en': 'System', 'ar': 'النظام'},
    'themeLight': {'fr': 'Clair', 'en': 'Light', 'ar': 'فاتح'},
    'themeDark': {'fr': 'Sombre', 'en': 'Dark', 'ar': 'داكن'},
    // --- D1: intern daily workspace ---
    'dashboard': {'fr': 'Tableau de bord', 'en': 'Dashboard', 'ar': 'لوحة المتابعة'},
    'todayTitle': {'fr': 'Aujourd’hui', 'en': 'Today', 'ar': 'اليوم'},
    'thisWeek': {'fr': 'Cette semaine', 'en': 'This week', 'ar': 'هذا الأسبوع'},
    'overdueTitle': {'fr': 'En retard', 'en': 'Overdue', 'ar': 'متأخرة'},
    'pendingJournalTitle': {'fr': 'Journal en attente', 'en': 'Pending journal', 'ar': 'اليومية المعلقة'},
    'deliverablesTitle': {'fr': 'Livrables', 'en': 'Deliverables', 'ar': 'المخرجات'},
    'evaluationsTitle': {'fr': 'Évaluations', 'en': 'Evaluations', 'ar': 'التقييمات'},
    'notificationsTitle': {'fr': 'Notifications', 'en': 'Notifications', 'ar': 'الإشعارات'},
    'markAllRead': {'fr': 'Tout marquer comme lu', 'en': 'Mark all as read', 'ar': 'تعليم الكل كمقروء'},
    'timelineTitle': {'fr': 'Chronologie du stage', 'en': 'Internship timeline', 'ar': 'الخط الزمني للتربص'},
    'myProgress': {'fr': 'Ma progression', 'en': 'My progress', 'ar': 'تقدمي'},
    'tasksProgress': {'fr': 'Tâches accomplies', 'en': 'Tasks completed', 'ar': 'المهام المنجزة'},
    'timelineProgress': {'fr': 'Temps écoulé', 'en': 'Time elapsed', 'ar': 'الوقت المنقضي'},
    'viewAll': {'fr': 'Tout voir', 'en': 'View all', 'ar': 'عرض الكل'},
    'viewTimeline': {'fr': 'Voir la chronologie', 'en': 'View timeline', 'ar': 'عرض الخط الزمني'},
    'noInternshipTitle': {'fr': 'Aucun stage lié pour le moment', 'en': 'No linked internship yet', 'ar': 'لا يوجد تربص مرتبط بعد'},
    'noInternshipHint': {'fr': 'Votre stage apparaîtra ici dès qu’il sera créé par l’administration.', 'en': 'Your internship will appear here once created by the administration.', 'ar': 'سيظهر تربصك هنا بمجرد إنشائه من قبل الإدارة.'},
    'staleData': {'fr': 'Données hors ligne — peuvent être obsolètes.', 'en': 'Offline data — may be stale.', 'ar': 'بيانات غير متصلة — قد تكون قديمة.'},
    'filterAll': {'fr': 'Toutes', 'en': 'All', 'ar': 'الكل'},
    'filterDone': {'fr': 'Terminées', 'en': 'Done', 'ar': 'المنجزة'},
    'taskMarkComplete': {'fr': 'Marquer comme terminée', 'en': 'Mark as done', 'ar': 'تعليم كمنجزة'},
    'taskReopen': {'fr': 'Rouvrir', 'en': 'Reopen', 'ar': 'إعادة فتح'},
    'taskSetInProgress': {'fr': 'Commencer', 'en': 'Start', 'ar': 'بدء التنفيذ'},
    'noDueDate': {'fr': 'Sans échéance', 'en': 'No due date', 'ar': 'بدون أجل'},
    'moreItems': {'fr': '+{n} autres', 'en': '+{n} more', 'ar': '+{n} أخرى'},
    'typeObservation': {'fr': 'Observation', 'en': 'Observation', 'ar': 'تربص ملاحظة'},
    'typePerfectionnement': {'fr': 'Perfectionnement', 'en': 'Perfectionnement', 'ar': 'تربص استكمال'},
    'typePFE': {'fr': 'PFE', 'en': 'PFE', 'ar': 'مشروع نهاية الدراسة'},
    'stPlanned': {'fr': 'Planifié', 'en': 'Planned', 'ar': 'مخطط'},
    'stActive': {'fr': 'En cours', 'en': 'Active', 'ar': 'جارٍ'},
    'stCompleted': {'fr': 'Terminé', 'en': 'Completed', 'ar': 'مكتمل'},
    'stCancelled': {'fr': 'Annulé', 'en': 'Cancelled', 'ar': 'ملغى'},
    'stArchived': {'fr': 'Archivé', 'en': 'Archived', 'ar': 'مؤرشف'},
    'tsTodo': {'fr': 'À faire', 'en': 'To do', 'ar': 'للإنجاز'},
    'tsInProgress': {'fr': 'En cours', 'en': 'In progress', 'ar': 'قيد الإنجاز'},
    'tsCompleted': {'fr': 'Terminée', 'en': 'Done', 'ar': 'منجزة'},
    'tsCancelled': {'fr': 'Annulée', 'en': 'Cancelled', 'ar': 'ملغاة'},
    'jsDraft': {'fr': 'Brouillon', 'en': 'Draft', 'ar': 'مسودة'},
    'jsSubmitted': {'fr': 'Soumise', 'en': 'Submitted', 'ar': 'مرسلة'},
    'jsValidated': {'fr': 'Validée', 'en': 'Validated', 'ar': 'مصادق عليها'},
    'jsRejected': {'fr': 'À corriger', 'en': 'Needs correction', 'ar': 'تتطلب تصحيحا'},
    'prLow': {'fr': 'Basse', 'en': 'Low', 'ar': 'منخفضة'},
    'prNormal': {'fr': 'Normale', 'en': 'Normal', 'ar': 'عادية'},
    'prHigh': {'fr': 'Haute', 'en': 'High', 'ar': 'عالية'},
    'prUrgent': {'fr': 'Urgente', 'en': 'Urgent', 'ar': 'عاجلة'},
    'supervisorLabel': {'fr': 'Encadrant', 'en': 'Supervisor', 'ar': 'المؤطر'},
    'departmentLabel': {'fr': 'Département', 'en': 'Department', 'ar': 'الإدارة'},
    'startLabel': {'fr': 'Début', 'en': 'Start', 'ar': 'البداية'},
    'endLabel': {'fr': 'Fin', 'en': 'End', 'ar': 'النهاية'},
    'todayMark': {'fr': 'Aujourd’hui', 'en': 'Today', 'ar': 'اليوم'},
    'msStart': {'fr': 'Début du stage', 'en': 'Internship start', 'ar': 'بداية التربص'},
    'msEnd': {'fr': 'Fin du stage', 'en': 'Internship end', 'ar': 'نهاية التربص'},
    'msEvaluation': {'fr': 'Évaluation reçue', 'en': 'Evaluation received', 'ar': 'تقييم مستلم'},
    'phaseNotStarted': {'fr': 'Pas encore commencé', 'en': 'Not started yet', 'ar': 'لم يبدأ بعد'},
    'phaseInProgress': {'fr': 'Stage en cours', 'en': 'Internship in progress', 'ar': 'التربص جارٍ'},
    'phaseFinished': {'fr': 'Stage terminé', 'en': 'Internship finished', 'ar': 'انتهى التربص'},
    'tasksEmpty': {'fr': 'Bravo, rien en attente ici.', 'en': 'Well done, nothing pending here.', 'ar': 'أحسنت، لا شيء معلق هنا.'},
    'journalEmpty': {'fr': 'Aucune entrée pour le moment.', 'en': 'No entries yet.', 'ar': 'لا إدخالات بعد.'},
    'notificationsEmpty': {'fr': 'Aucune notification.', 'en': 'No notifications.', 'ar': 'لا إشعارات.'},
    'versionLabel': {'fr': 'Version {n}', 'en': 'Version {n}', 'ar': 'النسخة {n}'},
    'scoreLabel': {'fr': 'Note : {n}', 'en': 'Score: {n}', 'ar': 'النقطة: {n}'},
    // --- D2: daily work loop ---
    'taskNew': {'fr': 'Nouvelle tâche', 'en': 'New task', 'ar': 'مهمة جديدة'},
    'taskEdit': {'fr': 'Modifier la tâche', 'en': 'Edit task', 'ar': 'تعديل المهمة'},
    'taskTitleLabel': {'fr': 'Titre', 'en': 'Title', 'ar': 'العنوان'},
    'taskTitleRequired': {'fr': 'Veuillez saisir un titre.', 'en': 'Please enter a title.', 'ar': 'يرجى إدخال عنوان.'},
    'taskDescLabel': {'fr': 'Description', 'en': 'Description', 'ar': 'الوصف'},
    'taskDueLabel': {'fr': 'Échéance', 'en': 'Due date', 'ar': 'تاريخ الاستحقاق'},
    'taskPickDate': {'fr': 'Choisir une date', 'en': 'Pick a date', 'ar': 'اختيار تاريخ'},
    'taskClearDate': {'fr': 'Effacer', 'en': 'Clear', 'ar': 'مسح'},
    'taskSave': {'fr': 'Enregistrer', 'en': 'Save', 'ar': 'حفظ'},
    'taskSaved': {'fr': 'Tâche enregistrée.', 'en': 'Task saved.', 'ar': 'تم حفظ المهمة.'},
    'journalNew': {'fr': 'Nouvelle entrée', 'en': 'New entry', 'ar': 'إدخال جديد'},
    'journalWhatDid': {'fr': 'Décrivez ce que vous avez réellement fait aujourd’hui — pas ce qui était prévu.', 'en': 'Describe what you actually did today — not what was planned.', 'ar': 'صِف ما فعلته فعلاً اليوم — وليس ما كان مخططا.'},
    'journalTitleLabel': {'fr': 'Titre du jour', 'en': 'Day title', 'ar': 'عنوان اليوم'},
    'journalTitleHint': {'fr': 'Ex. Mise en place de l’environnement', 'en': 'E.g. Environment setup', 'ar': 'مثال: إعداد بيئة العمل'},
    'journalDescLabel': {'fr': 'Travail effectué', 'en': 'Work performed', 'ar': 'العمل المنجز'},
    'journalDescHint': {'fr': 'Activités, difficultés, apprentissages…', 'en': 'Activities, difficulties, learnings…', 'ar': 'الأنشطة والصعوبات والدروس…'},
    'journalFieldRequired': {'fr': 'Ce champ est requis.', 'en': 'This field is required.', 'ar': 'هذا الحقل مطلوب.'},
    'journalSaveDraft': {'fr': 'Enregistrer le brouillon', 'en': 'Save draft', 'ar': 'حفظ المسودة'},
    'journalSubmitAction': {'fr': 'Soumettre pour validation', 'en': 'Submit for validation', 'ar': 'إرسال للمصادقة'},
    'journalDraftSavedAt': {'fr': 'Brouillon enregistré à {t}', 'en': 'Draft saved at {t}', 'ar': 'حُفظت المسودة في {t}'},
    'journalDraftKept': {'fr': 'Brouillon local conservé.', 'en': 'Local draft kept.', 'ar': 'تم الاحتفاظ بالمسودة المحلية.'},
    'journalCreated': {'fr': 'Entrée enregistrée comme brouillon.', 'en': 'Entry saved as draft.', 'ar': 'تم حفظ الإدخال كمسودة.'},
    'journalSubmittedOk': {'fr': 'Entrée soumise pour validation.', 'en': 'Entry submitted for validation.', 'ar': 'تم إرسال الإدخال للمصادقة.'},
    'journalSubmitFailKept': {'fr': 'Envoi impossible : l’entrée reste en brouillon sur le serveur.', 'en': 'Submit failed: the entry remains a server draft.', 'ar': 'تعذر الإرسال: بقي الإدخال مسودة على الخادم.'},
    'journalDetailTitle': {'fr': 'Détail de l’entrée', 'en': 'Entry details', 'ar': 'تفاصيل الإدخال'},
    'journalComments': {'fr': 'Commentaires', 'en': 'Comments', 'ar': 'التعليقات'},
    'journalNoComments': {'fr': 'Aucun commentaire pour le moment.', 'en': 'No comments yet.', 'ar': 'لا تعليقات بعد.'},
    'journalValidatedBy': {'fr': 'Validé par {n}', 'en': 'Validated by {n}', 'ar': 'صادق عليه {n}'},
    'backToToday': {'fr': 'Aujourd’hui', 'en': 'Today', 'ar': 'اليوم'},
    'validationsTitle': {'fr': 'Validations en attente', 'en': 'Pending validations', 'ar': 'المصادقات المعلقة'},
    'validationsEmpty': {'fr': 'Rien à valider pour le moment.', 'en': 'Nothing to validate right now.', 'ar': 'لا شيء للمصادقة حاليا.'},
    'validationsHint': {'fr': 'Entrées soumises par vos stagiaires.', 'en': 'Entries submitted by your interns.', 'ar': 'إدخالات أرسلها متربصوك.'},
    'validateAction': {'fr': 'Valider', 'en': 'Validate', 'ar': 'مصادقة'},
    'rejectAction': {'fr': 'Demander une correction', 'en': 'Request correction', 'ar': 'طلب تصحيح'},
    'reviewTitle': {'fr': 'Réviser l’entrée', 'en': 'Review entry', 'ar': 'مراجعة الإدخال'},
    'commentLabel': {'fr': 'Commentaire', 'en': 'Comment', 'ar': 'تعليق'},
    'commentHintValidate': {'fr': 'Note ou conseil (optionnel)', 'en': 'Note or advice (optional)', 'ar': 'ملاحظة أو نصيحة (اختياري)'},
    'commentHintReject': {'fr': 'Expliquez ce qu’il faut corriger (requis)', 'en': 'Explain what to correct (required)', 'ar': 'اشرح ما يجب تصحيحه (مطلوب)'},
    'commentRequired': {'fr': 'Veuillez expliquer la correction demandée.', 'en': 'Please explain the requested correction.', 'ar': 'يرجى شرح التصحيح المطلوب.'},
    'validationDone': {'fr': 'Entrée validée.', 'en': 'Entry validated.', 'ar': 'تمت المصادقة على الإدخال.'},
    'rejectionDone': {'fr': 'Correction demandée.', 'en': 'Correction requested.', 'ar': 'تم طلب التصحيح.'},
    'validationPending': {'fr': 'Décision non confirmée par le serveur.', 'en': 'Decision not confirmed by the server.', 'ar': 'لم يؤكد الخادم القرار.'},
    'unsavedTitle': {'fr': 'Abandonner les modifications ?', 'en': 'Discard changes?', 'ar': 'تجاهل التغييرات؟'},
    'unsavedMessage': {'fr': 'Vos modifications non enregistrées seront perdues.', 'en': 'Your unsaved changes will be lost.', 'ar': 'ستفقد تغييراتك غير المحفوظة.'},
    'discardAction': {'fr': 'Abandonner', 'en': 'Discard', 'ar': 'تجاهل'},
    'keepEditingAction': {'fr': 'Continuer', 'en': 'Keep editing', 'ar': 'مواصلة التحرير'},
  };

  String _get(String key) {
    final table = _values[key];
    if (table == null) return key;
    return table[locale.languageCode] ?? table['fr'] ?? key;
  }

  String get appTitle => _get('appTitle');
  String get loginTitle => _get('loginTitle');
  String get email => _get('email');
  String get password => _get('password');
  String get loginAction => _get('loginAction');
  String get logout => _get('logout');
  String get emailRequired => _get('emailRequired');
  String get passwordRequired => _get('passwordRequired');
  String get offline => _get('offline');
  String get online => _get('online');
  String get retry => _get('retry');
  String get loading => _get('loading');
  String get emptyTitle => _get('emptyTitle');
  String get roleIntern => _get('roleIntern');
  String get roleSupervisor => _get('roleSupervisor');
  String get navHome => _get('navHome');
  String get navTasks => _get('navTasks');
  String get navJournal => _get('navJournal');
  String get navMessages => _get('navMessages');
  String get navMore => _get('navMore');
  String get navInterns => _get('navInterns');
  String get navValidations => _get('navValidations');
  String get comingSoon => _get('comingSoon');
  String get unsupportedRole => _get('unsupportedRole');
  String get language => _get('language');
  String get theme => _get('theme');
  String get themeSystem => _get('themeSystem');
  String get themeLight => _get('themeLight');
  String get themeDark => _get('themeDark');

  // D1 workspace
  String get dashboard => _get('dashboard');
  String get todayTitle => _get('todayTitle');
  String get thisWeek => _get('thisWeek');
  String get overdueTitle => _get('overdueTitle');
  String get pendingJournalTitle => _get('pendingJournalTitle');
  String get deliverablesTitle => _get('deliverablesTitle');
  String get evaluationsTitle => _get('evaluationsTitle');
  String get notificationsTitle => _get('notificationsTitle');
  String get markAllRead => _get('markAllRead');
  String get timelineTitle => _get('timelineTitle');
  String get myProgress => _get('myProgress');
  String get tasksProgress => _get('tasksProgress');
  String get timelineProgress => _get('timelineProgress');
  String get viewAll => _get('viewAll');
  String get viewTimeline => _get('viewTimeline');
  String get noInternshipTitle => _get('noInternshipTitle');
  String get noInternshipHint => _get('noInternshipHint');
  String get staleData => _get('staleData');
  String get filterAll => _get('filterAll');
  String get filterDone => _get('filterDone');
  String get taskMarkComplete => _get('taskMarkComplete');
  String get taskReopen => _get('taskReopen');
  String get taskSetInProgress => _get('taskSetInProgress');
  String get noDueDate => _get('noDueDate');
  String moreItems(int n) => _get('moreItems').replaceAll('{n}', '$n');
  String get typeObservation => _get('typeObservation');
  String get typePerfectionnement => _get('typePerfectionnement');
  String get typePFE => _get('typePFE');
  String get stPlanned => _get('stPlanned');
  String get stActive => _get('stActive');
  String get stCompleted => _get('stCompleted');
  String get stCancelled => _get('stCancelled');
  String get stArchived => _get('stArchived');
  String get tsTodo => _get('tsTodo');
  String get tsInProgress => _get('tsInProgress');
  String get tsCompleted => _get('tsCompleted');
  String get tsCancelled => _get('tsCancelled');
  String get jsDraft => _get('jsDraft');
  String get jsSubmitted => _get('jsSubmitted');
  String get jsValidated => _get('jsValidated');
  String get jsRejected => _get('jsRejected');
  String get prLow => _get('prLow');
  String get prNormal => _get('prNormal');
  String get prHigh => _get('prHigh');
  String get prUrgent => _get('prUrgent');
  String get supervisorLabel => _get('supervisorLabel');
  String get departmentLabel => _get('departmentLabel');
  String get startLabel => _get('startLabel');
  String get endLabel => _get('endLabel');
  String get todayMark => _get('todayMark');
  String get msStart => _get('msStart');
  String get msEnd => _get('msEnd');
  String get msEvaluation => _get('msEvaluation');
  String get phaseNotStarted => _get('phaseNotStarted');
  String get phaseInProgress => _get('phaseInProgress');
  String get phaseFinished => _get('phaseFinished');
  String get tasksEmpty => _get('tasksEmpty');
  String get journalEmpty => _get('journalEmpty');
  String get notificationsEmpty => _get('notificationsEmpty');
  String versionLabel(int n) =>
      _get('versionLabel').replaceAll('{n}', '$n');
  String scoreLabel(String n) =>
      _get('scoreLabel').replaceAll('{n}', n);

  // D2 daily work loop
  String get taskNew => _get('taskNew');
  String get taskEdit => _get('taskEdit');
  String get taskTitleLabel => _get('taskTitleLabel');
  String get taskTitleRequired => _get('taskTitleRequired');
  String get taskDescLabel => _get('taskDescLabel');
  String get taskDueLabel => _get('taskDueLabel');
  String get taskPickDate => _get('taskPickDate');
  String get taskClearDate => _get('taskClearDate');
  String get taskSave => _get('taskSave');
  String get taskSaved => _get('taskSaved');
  String get journalNew => _get('journalNew');
  String get journalWhatDid => _get('journalWhatDid');
  String get journalTitleLabel => _get('journalTitleLabel');
  String get journalTitleHint => _get('journalTitleHint');
  String get journalDescLabel => _get('journalDescLabel');
  String get journalDescHint => _get('journalDescHint');
  String get journalFieldRequired => _get('journalFieldRequired');
  String get journalSaveDraft => _get('journalSaveDraft');
  String get journalSubmitAction => _get('journalSubmitAction');
  String journalDraftSavedAt(String t) =>
      _get('journalDraftSavedAt').replaceAll('{t}', t);
  String get journalDraftKept => _get('journalDraftKept');
  String get journalCreated => _get('journalCreated');
  String get journalSubmittedOk => _get('journalSubmittedOk');
  String get journalSubmitFailKept => _get('journalSubmitFailKept');
  String get journalDetailTitle => _get('journalDetailTitle');
  String get journalComments => _get('journalComments');
  String get journalNoComments => _get('journalNoComments');
  String journalValidatedBy(String n) =>
      _get('journalValidatedBy').replaceAll('{n}', n);
  String get backToToday => _get('backToToday');
  String get validationsTitle => _get('validationsTitle');
  String get validationsEmpty => _get('validationsEmpty');
  String get validationsHint => _get('validationsHint');
  String get validateAction => _get('validateAction');
  String get rejectAction => _get('rejectAction');
  String get reviewTitle => _get('reviewTitle');
  String get commentLabel => _get('commentLabel');
  String get commentHintValidate => _get('commentHintValidate');
  String get commentHintReject => _get('commentHintReject');
  String get commentRequired => _get('commentRequired');
  String get validationDone => _get('validationDone');
  String get rejectionDone => _get('rejectionDone');
  String get validationPending => _get('validationPending');
  String get unsavedTitle => _get('unsavedTitle');
  String get unsavedMessage => _get('unsavedMessage');
  String get discardAction => _get('discardAction');
  String get keepEditingAction => _get('keepEditingAction');

  /// All keys must exist in fr/en/ar — enforced by unit test.
  static Map<String, Map<String, String>> get allValues => _values;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(Locale(locale.languageCode)));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
