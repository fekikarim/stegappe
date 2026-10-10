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
    'logoutConfirmTitle': {'fr': 'Se déconnecter ?', 'en': 'Sign out?', 'ar': 'تسجيل الخروج؟'},
    'logoutConfirmMessage': {'fr': 'Vous devrez vous reconnecter pour continuer.', 'en': 'You will need to sign in again to continue.', 'ar': 'ستحتاج إلى تسجيل الدخول مجددا للمتابعة.'},
    'profileTitle': {'fr': 'Profil', 'en': 'Profile', 'ar': 'الملف الشخصي'},
    'profileName': {'fr': 'Nom', 'en': 'Name', 'ar': 'الاسم'},
    'profileEmail': {'fr': 'E-mail', 'en': 'Email', 'ar': 'البريد الإلكتروني'},
    'profileRole': {'fr': 'Rôle', 'en': 'Role', 'ar': 'الدور'},
    'profileInternship': {'fr': 'Stage', 'en': 'Internship', 'ar': 'التربص'},
    'profileReadOnly': {'fr': 'Champs en lecture seule — aucune modification n’est possible sur cet appareil.', 'en': 'Read-only fields — nothing can be edited on this device.', 'ar': 'حقول للقراءة فقط — لا يمكن تعديل أي شيء على هذا الجهاز.'},
    'profileChangePassword': {'fr': 'Changer le mot de passe', 'en': 'Change password', 'ar': 'تغيير كلمة المرور'},
    'accountTitle': {'fr': 'Compte', 'en': 'Account', 'ar': 'الحساب'},
    'appearanceTitle': {'fr': 'Apparence', 'en': 'Appearance', 'ar': 'المظهر'},
    'aboutTitle': {'fr': 'À propos', 'en': 'About', 'ar': 'حول التطبيق'},
    'aboutVersion': {'fr': 'Version {v}', 'en': 'Version {v}', 'ar': 'الإصدار {v}'},
    'aboutLicenses': {'fr': 'Licences', 'en': 'Licences', 'ar': 'التراخيص'},
    'aboutSupport': {'fr': 'Assistance', 'en': 'Support', 'ar': 'الدعم'},
    'aboutSupportBody': {'fr': 'Pour toute aide, contactez votre encadrant via la Messagerie.', 'en': 'For help, contact your supervisor through Messages.', 'ar': 'للمساعدة، اتصل بمؤطرك عبر الرسائل.'},
    'aboutPrivacy': {'fr': 'Confidentialité', 'en': 'Privacy', 'ar': 'الخصوصية'},
    'aboutPrivacyBody': {'fr': 'L’application n’affiche ni CIN, ni mot de passe, ni jeton. Vos données restent liées à votre stage.', 'en': 'The app never shows CIN, passwords or tokens. Your data stays scoped to your internship.', 'ar': 'لا يعرض التطبيق أبدا رقم التعريف أو كلمة المرور أو الرموز. تبقى بياناتك مرتبطة بتربصك.'},
    'notifyPrepareAsk': {'fr': 'Demander la préparation', 'en': 'Request preparation', 'ar': 'طلب التحضير'},
    'notifySelected': {'fr': '{n} sélectionné(s)', 'en': '{n} selected', 'ar': 'تم تحديد {n}'},
    'notifyEmptyHint': {'fr': 'Sélectionnez au moins un stagiaire.', 'en': 'Select at least one intern.', 'ar': 'اختر متربصا واحدا على الأقل.'},
    'notifySuccess': {'fr': '{n} stagiaire(s) notifié(s).', 'en': '{n} intern(s) notified.', 'ar': 'تم إشعار {n} من المتربصين.'},
    'notifyNeedsConnection': {'fr': 'Connexion requise pour notifier.', 'en': 'Connection required to notify.', 'ar': 'الاتصال مطلوب للإشعار.'},
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
    'homeGreetMorning': {'fr': 'Bonjour {name}', 'en': 'Good morning, {name}', 'ar': 'صباح الخير {name}'},
    'homeGreetAfternoon': {'fr': 'Bon après-midi {name}', 'en': 'Good afternoon, {name}', 'ar': 'مساء الخير {name}'},
    'homeGreetEvening': {'fr': 'Bonsoir {name}', 'en': 'Good evening, {name}', 'ar': 'مساء الخير {name}'},
    'homeGreetNight': {'fr': 'Bonne nuit {name}', 'en': 'Good night, {name}', 'ar': 'ليلة سعيدة {name}'},
    'homeQuickActions': {'fr': 'Actions rapides', 'en': 'Quick actions', 'ar': 'إجراءات سريعة'},
    'qaTasks': {'fr': 'Mes tâches', 'en': 'My tasks', 'ar': 'مهامي'},
    'qaJournal': {'fr': 'Journal', 'en': 'Journal', 'ar': 'اليومية'},
    'qaAssistant': {'fr': 'Assistant', 'en': 'Assistant', 'ar': 'المساعد'},
    'qaMessages': {'fr': 'Messages', 'en': 'Messages', 'ar': 'الرسائل'},
    'qaValidations': {'fr': 'Validations', 'en': 'Validations', 'ar': 'المصادقات'},
    'qaCalendar': {'fr': 'Calendrier', 'en': 'Calendar', 'ar': 'التقويم'},
    'tasksProgress': {'fr': 'Tâches accomplies', 'en': 'Tasks completed', 'ar': 'المهام المنجزة'},
    'timelineProgress': {'fr': 'Temps écoulé', 'en': 'Time elapsed', 'ar': 'الوقت المنقضي'},
    'viewAll': {'fr': 'Tout voir', 'en': 'View all', 'ar': 'عرض الكل'},
    'viewTimeline': {'fr': 'Voir la chronologie', 'en': 'View timeline', 'ar': 'عرض الخط الزمني'},
    'noInternshipTitle': {'fr': 'Aucun stage lié pour le moment', 'en': 'No linked internship yet', 'ar': 'لا يوجد تربص مرتبط بعد'},
    'noInternshipHint': {'fr': 'Votre stage apparaîtra ici dès qu’il sera créé par l’administration.', 'en': 'Your internship will appear here once created by the administration.', 'ar': 'سيظهر تربصك هنا بمجرد إنشائه من قبل الإدارة.'},
    'staleData': {'fr': 'Données hors ligne — peuvent être obsolètes.', 'en': 'Offline data — may be stale.', 'ar': 'بيانات غير متصلة — قد تكون قديمة.'},
    'filterAll': {'fr': 'Toutes', 'en': 'All', 'ar': 'الكل'},
    'filterDone': {'fr': 'Terminées', 'en': 'Done', 'ar': 'المنجزة'},
    // T02/BR-11: the student's completion is a REVIEW REQUEST, never a final
    // "done" — the wording must not promise a state the backend has not granted.
    'taskSubmitForReview': {
      'fr': 'Envoyer pour validation', 'en': 'Submit for review', 'ar': 'إرسال للتحقق'},
    'taskReopen': {'fr': 'Rouvrir', 'en': 'Reopen', 'ar': 'إعادة فتح'},
    'taskSetInProgress': {'fr': 'Commencer', 'en': 'Start', 'ar': 'بدء التنفيذ'},
    'noDueDate': {'fr': 'Sans échéance', 'en': 'No due date', 'ar': 'بدون أجل'},
    'moreItems': {'fr': '+{n} autres', 'en': '+{n} more', 'ar': '+{n} أخرى'},
    'typeObservation': {'fr': 'Observation', 'en': 'Observation', 'ar': 'تربص ملاحظة'},
    'typePerfectionnement': {'fr': 'Perfectionnement', 'en': 'Perfectionnement', 'ar': 'تربص استكمال'},
    'typePFE': {'fr': 'PFE', 'en': 'PFE', 'ar': 'مشروع نهاية الدراسة'},
    'stApproved': {'fr': 'Approuvé', 'en': 'Approved', 'ar': 'مصادق عليه'},
    'stInProgress': {'fr': 'En cours', 'en': 'In progress', 'ar': 'جارٍ'},
    'stReportSubmitted': {'fr': 'Rapport déposé', 'en': 'Report submitted', 'ar': 'تم تسليم التقرير'},
    'stUnderValidation': {'fr': 'En validation', 'en': 'Under validation', 'ar': 'قيد التحقق'},
    'stValidated': {'fr': 'Validé', 'en': 'Validated', 'ar': 'تم التحقق'},
    'stReceiptIssued': {'fr': 'Reçu émis', 'en': 'Receipt issued', 'ar': 'تم إصدار الوصل'},
    'stCancelled': {'fr': 'Annulé', 'en': 'Cancelled', 'ar': 'ملغى'},
    'stArchived': {'fr': 'Archivé', 'en': 'Archived', 'ar': 'مؤرشف'},
    'tsTodo': {'fr': 'À faire', 'en': 'To do', 'ar': 'للإنجاز'},
    'tsInProgress': {'fr': 'En cours', 'en': 'In progress', 'ar': 'قيد الإنجاز'},
    // T02/D6: `COMPLETED` is work finished by the student, NOT done — the
    // supervisor's review is pending. Only APPROVED is 'Validée' (BR-11).
    'tsAwaitingApproval': {
      'fr': 'En attente de validation', 'en': 'Awaiting approval', 'ar': 'في انتظار المصادقة'},
    'tsApproved': {'fr': 'Validée', 'en': 'Approved', 'ar': 'مصادق عليها'},
    'tsDenied': {'fr': 'Refusée', 'en': 'Denied', 'ar': 'مرفوضة'},
    'tsUnknown': {'fr': 'Statut inconnu', 'en': 'Unknown status', 'ar': 'حالة غير معروفة'},
    'tsCancelled': {'fr': 'Annulée', 'en': 'Cancelled', 'ar': 'ملغاة'},
    'taskGroupAttention': {
      'fr': 'À surveiller', 'en': 'Needs attention', 'ar': 'تتطلب انتباهك'},
    'taskGroupEmpty': {
      'fr': 'Aucune tâche ici', 'en': 'No tasks here', 'ar': 'لا توجد مهام هنا'},
    'tasksEmptyHint': {
      'fr': 'Elles apparaîtront ici dès que votre encadrant les ajoutera.',
      'en': 'They will appear here as soon as your supervisor adds them.',
      'ar': 'ستظهر هنا بمجرد أن يضيفها مشرفك.'},
    'taskNoMatch': {
      'fr': 'Aucune tâche ne correspond à votre recherche',
      'en': 'No task matches your search',
      'ar': 'لا توجد مهمة تطابق بحثك'},
    'taskBackToProgress': {'fr': 'Reprendre', 'en': 'Resume', 'ar': 'استئناف'},
    'taskDenialReason': {
      'fr': 'Motif du refus', 'en': 'Reason for denial', 'ar': 'سبب الرفض'},
    // BR-12: a denial always carries a reason server-side; the client stays
    // tolerant of a legacy row and says so instead of showing an empty box.
    'taskDeniedNoReason': {
      'fr': 'Aucun motif fourni', 'en': 'No reason provided', 'ar': 'لم يتم تقديم سبب'},
    'taskReviewedOn': {
      'fr': 'Décidée le {d}', 'en': 'Decided on {d}', 'ar': 'بتاريخ {d}'},
    'taskWaitingReview': {
      'fr': 'En attente de la validation du superviseur',
      'en': 'Waiting for the supervisor’s approval',
      'ar': 'في انتظار مصادقة المشرف'},
    'taskSearchHint': {
      'fr': 'Rechercher une tâche', 'en': 'Search a task', 'ar': 'ابحث عن مهمة'},
    'taskSearchClear': {
      'fr': 'Effacer la recherche', 'en': 'Clear search', 'ar': 'مسح البحث'},
    'taskViewBoard': {'fr': 'Tableau', 'en': 'Board', 'ar': 'لوحة'},
    'taskViewList': {'fr': 'Liste', 'en': 'List', 'ar': 'قائمة'},
    'taskNoEditSupervisorTask': {
      'fr': 'Tâche créée par votre encadrant — non modifiable',
      'en': 'Task created by your supervisor — read-only',
      'ar': 'مهمة أنشأها المشرف — غير قابلة للتعديل'},
    // --- T03 task classification (student-defined categories + AI) ---
    'catOrganize': {'fr': 'Organiser', 'en': 'Organize', 'ar': 'تنظيم'},
    'catTitle': {
      'fr': 'Mon organisation', 'en': 'My organization', 'ar': 'تنظيمي'},
    'catNew': {
      'fr': 'Nouvelle catégorie', 'en': 'New category', 'ar': 'فئة جديدة'},
    'catNameLabel': {'fr': 'Nom', 'en': 'Name', 'ar': 'الاسم'},
    'catNameHint': {
      'fr': 'Ex. Frontend, Révisions…',
      'en': 'E.g. Frontend, Reviews…',
      'ar': 'مثال: الواجهة، المراجعات…'},
    'catColorLabel': {'fr': 'Couleur', 'en': 'Color', 'ar': 'اللون'},
    'catNoColor': {'fr': 'Aucune', 'en': 'None', 'ar': 'بدون'},
    'catCreate': {'fr': 'Créer', 'en': 'Create', 'ar': 'إنشاء'},
    'catSave': {'fr': 'Enregistrer', 'en': 'Save', 'ar': 'حفظ'},
    'catRename': {'fr': 'Renommer', 'en': 'Rename', 'ar': 'إعادة تسمية'},
    'catMoveUp': {
      'fr': 'Monter', 'en': 'Move up', 'ar': 'تحريك لأعلى'},
    'catMoveDown': {
      'fr': 'Descendre', 'en': 'Move down', 'ar': 'تحريك لأسفل'},
    'catDelete': {'fr': 'Supprimer', 'en': 'Delete', 'ar': 'حذف'},
    'catDeleteTitle': {
      'fr': 'Supprimer la catégorie ?',
      'en': 'Delete the category?',
      'ar': 'حذف الفئة؟'},
    'catDeleteConfirm': {
      'fr': 'Supprimer « {name} » ?',
      'en': 'Delete "{name}"?',
      'ar': 'حذف "{name}"؟'},
    'catDeleteHint': {
      'fr': 'Ses tâches redeviendront « sans catégorie ». Rien ne sera perdu.',
      'en': 'Its tasks will become unclassified. Nothing will be lost.',
      'ar': 'ستصبح مهامها بدون فئة. لن يُفقد أي شيء.'},
    'catEmpty': {
      'fr': 'Aucune catégorie pour le moment',
      'en': 'No categories yet',
      'ar': 'لا توجد فئات بعد'},
    'catEmptyHint': {
      'fr': 'Créez-en une (par ex. Frontend) pour organiser vos tâches.',
      'en': 'Create one (e.g. Frontend) to organize your tasks.',
      'ar': 'أنشئ واحدة (مثال: الواجهة) لتنظيم مهامك.'},
    'catUnclassified': {
      'fr': 'Sans catégorie', 'en': 'Unclassified', 'ar': 'بدون فئة'},
    'catSuggest': {
      'fr': 'Suggérer avec l’IA',
      'en': 'Suggest with AI',
      'ar': 'اقتراح بالذكاء الاصطناعي'},
    'catSuggesting': {
      'fr': 'L’IA analyse vos tâches…',
      'en': 'AI is analyzing your tasks…',
      'ar': 'يحلل الذكاء الاصطناعي مهامك…'},
    'catSuggestEmpty': {
      'fr': 'Toutes vos tâches sont déjà classées.',
      'en': 'All your tasks are already classified.',
      'ar': 'جميع مهامك مصنفة.'},
    'catNoCategoriesHint': {
      'fr': 'Créez d’abord au moins une catégorie — l’IA ne propose que vos propres catégories.',
      'en': 'Create at least one category first — the AI only proposes your own categories.',
      'ar': 'أنشئ فئة واحدة على الأقل أولاً — لا يقترح الذكاء الاصطناعي إلا فئاتك.'},
    'catProposals': {
      'fr': 'Propositions de l’IA',
      'en': 'AI proposals',
      'ar': 'مقترحات الذكاء الاصطناعي'},
    'catProposalNote': {
      'fr': 'Vérifiez chaque proposition : rien n’est enregistré sans votre accord.',
      'en': 'Review each proposal: nothing is saved without your approval.',
      'ar': 'راجع كل مقترح: لا يُحفظ أي شيء دون موافقتك.'},
    'catAccept': {'fr': 'Accepter', 'en': 'Accept', 'ar': 'قبول'},
    'catAcceptAll': {
      'fr': 'Tout accepter', 'en': 'Accept all', 'ar': 'قبول الكل'},
    'catNewBadge': {'fr': 'Nouveau', 'en': 'New', 'ar': 'جديد'},
    'catUndo': {'fr': 'Annuler', 'en': 'Undo', 'ar': 'تراجع'},
    'catUndone': {
      'fr': 'Classifications annulées.',
      'en': 'Classifications undone.',
      'ar': 'تم التراجع عن التصنيفات.'},
    'catApplied': {
      'fr': '{n} tâche(s) classée(s).',
      'en': '{n} task(s) classified.',
      'ar': 'تم تصنيف {n} من المهام.'},
    'catApplySkipped': {
      'fr': '{n} ignorée(s) (déjà classées entre-temps).',
      'en': '{n} skipped (classified meanwhile).',
      'ar': 'تم تجاهل {n} (صُنفت في الأثناء).'},
    'catAssigned': {
      'fr': 'Tâche classée.', 'en': 'Task classified.', 'ar': 'تم تصنيف المهمة.'},
    'catNeedsConnection': {
      'fr': 'La suggestion IA nécessite une connexion.',
      'en': 'AI suggestions need a connection.',
      'ar': 'تحتاج الاقتراحات إلى اتصال.'},
    'errCategoryInvalid': {
      'fr': 'Cette catégorie est refusée : vérifiez le nom (1 à 40 caractères, sans doublon) et la couleur.',
      'en': 'This category was refused: check the name (1–40 characters, no duplicate) and the color.',
      'ar': 'تم رفض هذه الفئة: تحقق من الاسم (1 إلى 40 حرفاً، بدون تكرار) واللون.'},
    'errJournalNotEligible': {'fr': 'La fenêtre de génération du journal n’est pas encore ouverte.', 'en': 'The journal generation window is not open yet.', 'ar': 'نافذة إنشاء الدفتر غير مفتوحة بعد.'},
    // --- T10 B7/B8/SU-VAL-01: submission window + document kind ---
    'errSubmissionWindowClosed': {
      'fr': 'Soumission refusée : la fenêtre de la semaine finale est fermée. Contactez votre encadrant via la Messagerie — aucune dérogation n’est possible.',
      'en': 'Submission refused: the final-week window is closed. Contact your supervisor through Messages — no override is possible.',
      'ar': 'تم رفض التسليم: نافذة الأسبوع الأخير مغلقة. اتصل بمؤطرك عبر الرسائل — لا يمكن تجاوز ذلك.',
    },
    'submissionWindowOpens': {
      'fr': 'Soumission possible à partir du {date} (dernière semaine du stage).',
      'en': 'Submission opens on {date} (the internship’s final week).',
      'ar': 'يفتح التسليم في {date} (الأسبوع الأخير للتربص).',
    },
    'submissionWindowUntil': {
      'fr': 'Fenêtre de soumission ouverte jusqu’au {date}.',
      'en': 'Submission window open until {date}.',
      'ar': 'نافذة التسليم مفتوحة حتى {date}.',
    },
    'submissionWindowLate': {
      'fr': 'La fenêtre de soumission s’est terminée le {date} : les soumissions tardives ne sont pas acceptées. Contactez votre encadrant via la Messagerie.',
      'en': 'The submission window closed on {date}: late submissions are not accepted. Contact your supervisor through Messages.',
      'ar': 'انتهت نافذة التسليم في {date}: لا تُقبل التسليمات المتأخرة. اتصل بمؤطرك عبر الرسائل.',
    },
    'submissionWindowNoPeriod': {
      'fr': 'Période de stage incomplète : aucune fenêtre de soumission ne peut être déterminée. Contactez votre encadrant.',
      'en': 'Incomplete internship period: no submission window can be determined. Contact your supervisor.',
      'ar': 'فترة التربص غير مكتملة: لا يمكن تحديد نافذة التسليم. اتصل بمؤطرك.',
    },
    'submissionWindowCancelled': {
      'fr': 'Ce stage est annulé : aucune soumission n’est possible.',
      'en': 'This internship is cancelled: no submission is possible.',
      'ar': 'تم إلغاء هذا التربص: لا يمكن أي تسليم.',
    },
    'contactSupervisorAction': {
      'fr': 'Contacter l’encadrant',
      'en': 'Contact supervisor',
      'ar': 'الاتصال بالمؤطر',
    },
    'contactNoConversation': {
      'fr': 'Aucune conversation avec votre encadrant pour le moment.',
      'en': 'No conversation with your supervisor yet.',
      'ar': 'لا توجد محادثة مع مؤطرك حاليا.',
    },
    'deliverableKindLabel': {
      'fr': 'Type de document',
      'en': 'Document type',
      'ar': 'نوع الوثيقة',
    },
    'deliverableKindNone': {
      'fr': 'Document libre (aucun type)',
      'en': 'Free document (no type)',
      'ar': 'وثيقة حرة (بدون نوع)',
    },
    'deliverableKindJournal': {
      'fr': 'Journal de stage',
      'en': 'Internship journal',
      'ar': 'دفتر التربص',
    },
    'deliverableKindReport': {
      'fr': 'Rapport de stage',
      'en': 'Internship report',
      'ar': 'تقرير التربص',
    },
    'deliverableKindHint': {
      'fr': 'Identifiez le journal et le rapport pour la validation : un seul document par type.',
      'en': 'Identify the journal and the report for validation: one document per type.',
      'ar': 'حدّد الدفتر والتقرير للمصادقة: وثيقة واحدة لكل نوع.',
    },
    'errDeliverableKindLocked': {
      'fr': 'Le type de ce document est verrouillé : il est déjà attribué ou le document est validé.',
      'en': 'This document’s kind is locked: it is already assigned, or the document is validated.',
      'ar': 'نوع هذه الوثيقة مقفل: مُسنَد مسبقا أو وثيقة مصادق عليها.',
    },
    'errDocumentNotInConversation': {
      'fr': 'Ce document appartient à un autre stage.',
      'en': 'This document belongs to another internship.',
      'ar': 'هذه الوثيقة تخص تربصا آخر.',
    },
    'msgDocMenu': {
      'fr': 'Actions du document',
      'en': 'Document actions',
      'ar': 'إجراءات الوثيقة',
    },
    'msgSetAsJournal': {
      'fr': 'Définir comme journal',
      'en': 'Set as journal',
      'ar': 'تعيين كدفتر',
    },
    'msgSetAsReport': {
      'fr': 'Définir comme rapport',
      'en': 'Set as report',
      'ar': 'تعيين كتقرير',
    },
    'msgDocRegistered': {
      'fr': 'Enregistré comme {kind} — revue de premier niveau ; l’administration prendra la décision finale.',
      'en': 'Registered as {kind} — first-level review; the administration takes the final decision.',
      'ar': 'تم التسجيل كـ {kind} — مراجعة المستوى الأول؛ تتخذ الإدارة القرار النهائي.',
    },
    'msgDocNotLinked': {
      'fr': 'Ce fichier n’a pas été envoyé depuis les documents du stage : demandez au stagiaire de l’envoyer depuis ses documents pour pouvoir l’enregistrer.',
      'en': 'This file was not sent from the internship documents: ask the intern to send it from their documents so it can be registered.',
      'ar': 'لم يُرسل هذا الملف من وثائق التربص: اطلب من المتربص إرساله من وثائقه حتى يمكن تسجيله.',
    },
    'errJournalTextInvalid': {'fr': 'Texte trop court ou trop long (40 à 8000 caractères).', 'en': 'Text too short or too long (40 to 8000 characters).', 'ar': 'النص قصير جدا أو طويل جدا (من 40 إلى 8000 حرف).'},
    'errCategoryChanged': {
      'fr': 'Cette tâche a été classée entre-temps. Rechargez et réessayez.',
      'en': 'This task was classified meanwhile. Reload and try again.',
      'ar': 'تم تصنيف هذه المهمة في الأثناء. أعد التحميل وحاول مجدداً.'},
    'errCategoryNoCategories': {
      'fr': 'Créez d’abord une catégorie avant de demander une suggestion.',
      'en': 'Create a category first before asking for a suggestion.',
      'ar': 'أنشئ فئة أولاً قبل طلب الاقتراح.'},
    // --- T04 supervisor task management ---
    'supTasksTitle': {
      'fr': 'Tâches des stagiaires',
      'en': 'Interns’ tasks',
      'ar': 'مهام المتربصين'},
    'supNoStudents': {
      'fr': 'Aucun stagiaire suivi',
      'en': 'No supervised interns',
      'ar': 'لا يوجد متربصون تحت إشرافك'},
    'supNoStudentsHint': {
      'fr': 'Les stagiaires qui vous sont confiés apparaîtront ici.',
      'en': 'Interns assigned to you will appear here.',
      'ar': 'سيظهر هنا المتربصون المسندون إليك.'},
    'supTaskNew': {
      'fr': 'Nouvelle tâche', 'en': 'New task', 'ar': 'مهمة جديدة'},
    'supTaskEdit': {
      'fr': 'Modifier la tâche', 'en': 'Edit task', 'ar': 'تعديل المهمة'},
    'supTaskDelete': {
      'fr': 'Supprimer', 'en': 'Delete', 'ar': 'حذف'},
    'supTaskDeleteTitle': {
      'fr': 'Supprimer la tâche ?',
      'en': 'Delete the task?',
      'ar': 'حذف المهمة؟'},
    'supTaskDeleteConfirm': {
      'fr': 'Supprimer « {title} » pour {name} ? L’étudiant en sera notifié.',
      'en': 'Delete "{title}" for {name}? The student will be notified.',
      'ar': 'حذف "{title}" لـ {name}؟ سيتم إشعار الطالب.'},
    'supTaskCreated': {
      'fr': 'Tâche créée. L’étudiant en a été notifié.',
      'en': 'Task created. The student was notified.',
      'ar': 'تم إنشاء المهمة. تم إشعار الطالب.'},
    'supTaskUpdated': {
      'fr': 'Tâche mise à jour.', 'en': 'Task updated.', 'ar': 'تم تحديث المهمة.'},
    'supTaskDeleted': {
      'fr': 'Tâche supprimée.', 'en': 'Task deleted.', 'ar': 'تم حذف المهمة.'},
    'supReviewApprove': {
      'fr': 'Approuver', 'en': 'Approve', 'ar': 'مصادقة'},
    'supReviewDeny': {
      'fr': 'Refuser', 'en': 'Deny', 'ar': 'رفض'},
    'supReviewTitle': {
      'fr': 'Examiner le travail',
      'en': 'Review the work',
      'ar': 'مراجعة العمل'},
    'supReviewApproved': {
      'fr': 'Travail approuvé.', 'en': 'Work approved.', 'ar': 'تمت المصادقة على العمل.'},
    'supReviewDenied': {
      'fr': 'Travail refusé avec motif.',
      'en': 'Work denied with a reason.',
      'ar': 'تم رفض العمل مع ذكر السبب.'},
    'supDenyReasonLabel': {
      'fr': 'Motif du refus', 'en': 'Reason for denial', 'ar': 'سبب الرفض'},
    'supDenyReasonHint': {
      'fr': 'Expliquez ce qu’il faut reprendre…',
      'en': 'Explain what needs rework…',
      'ar': 'اشرح ما يجب إعادة العمل عليه…'},
    'supNeedsReview': {
      'fr': 'À examiner', 'en': 'Needs review', 'ar': 'يحتاج إلى مراجعة'},
    'supScheduled': {
      'fr': 'Planifiée', 'en': 'Scheduled', 'ar': 'مجدولة'},
    'supAppearsOn': {
      'fr': 'Visible le {d}', 'en': 'Appears {d}', 'ar': 'تظهر بتاريخ {d}'},
    'supScheduleLabel': {
      'fr': 'Apparaît le', 'en': 'Appears on', 'ar': 'تظهر بتاريخ'},
    'supScheduleNone': {
      'fr': 'Immédiatement', 'en': 'Immediately', 'ar': 'فوراً'},
    'supSchedulePickDate': {
      'fr': 'Choisir la date', 'en': 'Pick a date', 'ar': 'اختيار التاريخ'},
    'supSchedulePickTime': {
      'fr': 'Choisir l’heure', 'en': 'Pick a time', 'ar': 'اختيار الوقت'},
    'supScheduleClear': {
      'fr': 'Rendre visible immédiatement',
      'en': 'Make visible immediately',
      'ar': 'جعلها ظاهرة فوراً'},
    'supScheduleOutsideNote': {
      'fr': 'La date doit se situer pendant le stage (heure de Tunis).',
      'en': 'The date must fall within the internship (Tunis time).',
      'ar': 'يجب أن يكون التاريخ خلال فترة التربص (توقيت تونس).'},
    'supBulkTitle': {
      'fr': 'Ajouter à plusieurs stagiaires',
      'en': 'Add to several interns',
      'ar': 'إضافة لعدة متربصين'},
    'supBulkStudents': {
      'fr': '{n} stagiaire(s)', 'en': '{n} intern(s)', 'ar': '{n} من المتربصين'},
    'supBulkPlan': {
      'fr': '{t} tâche(s) × {s} stagiaire(s)',
      'en': '{t} task(s) × {s} intern(s)',
      'ar': '{t} من المهام × {s} من المتربصين'},
    'supBulkSubmit': {
      'fr': 'Ajouter les tâches', 'en': 'Add the tasks', 'ar': 'إضافة المهام'},
    'supBulkDone': {
      'fr': '{n} tâche(s) créée(s).',
      'en': '{n} task(s) created.',
      'ar': 'تم إنشاء {n} من المهام.'},
    'supBulkAddTask': {
      'fr': 'Ajouter une tâche au lot',
      'en': 'Add a task to the batch',
      'ar': 'إضافة مهمة إلى الدفعة'},
    'supBulkEmpty': {
      'fr': 'Composez au moins une tâche pour au moins un stagiaire.',
      'en': 'Compose at least one task for at least one intern.',
      'ar': 'أنشئ مهمة واحدة على الأقل لمتربص واحد على الأقل.'},
    'supNeedsConnection': {
      'fr': 'La connexion est nécessaire pour envoyer le lot.',
      'en': 'A connection is required to send the batch.',
      'ar': 'الاتصال ضروري لإرسال الدفعة.'},
    'supManageTasks': {
      'fr': 'Gérer les tâches', 'en': 'Manage tasks', 'ar': 'إدارة المهام'},
    'supAddTaskFor': {
      'fr': 'Ajouter une tâche', 'en': 'Add a task', 'ar': 'إضافة مهمة'},
    'errReviewReason': {
      'fr': 'Un motif est obligatoire pour refuser un travail.',
      'en': 'A reason is required to deny work.',
      'ar': 'السبب مطلوب لرفض العمل.'},
    'errTaskNotCompleted': {
      'fr': 'Seul un travail terminé peut être examiné.',
      'en': 'Only completed work can be reviewed.',
      'ar': 'لا يمكن مراجعة إلا العمل المنجز.'},
    'errScheduleOutsidePeriod': {
      'fr': 'La date planifiée doit se situer pendant le stage.',
      'en': 'The scheduled date must fall within the internship.',
      'ar': 'يجب أن يكون التاريخ المجدول خلال فترة التربص.'},
    'errBulkInvalid': {
      'fr': 'Le lot est refusé : rien n’a été appliqué. Corrigez et renvoyez.',
      'en': 'The batch was refused: nothing was applied. Fix and resend.',
      'ar': 'تم رفض الدفعة: لم يُطبق أي شيء. صحح وأعد الإرسال.'},
    // --- T05 supervisor AI task drafts (proposals, never real tasks) ---
    'aiDraftTitle': {
      'fr': 'Générer des tâches avec l’IA',
      'en': 'Generate tasks with AI',
      'ar': 'إنشاء مهام بالذكاء الاصطناعي'},
    'aiDraftProposalNote': {
      'fr': 'L’IA propose des brouillons : rien ne devient une tâche sans votre validation.',
      'en': 'AI proposes drafts: nothing becomes a task without your approval.',
      'ar': 'يقترح الذكاء الاصطناعي مسودات: لا شيء يصبح مهمة دون موافقتك.'},
    'aiDraftAiNote': {
      'fr': 'Le contenu sert uniquement à proposer des tâches.',
      'en': 'The content is only used to propose tasks.',
      'ar': 'يُستخدم المحتوى فقط لاقتراح المهام.'},
    'aiDraftPdfTab': {'fr': 'Document PDF', 'en': 'PDF document', 'ar': 'مستند PDF'},
    'aiDraftTextTab': {'fr': 'Décrire', 'en': 'Describe', 'ar': 'الوصف'},
    'aiDraftTextLabel': {
      'fr': 'Description du travail à découper en tâches',
      'en': 'Description of the work to split into tasks',
      'ar': 'وصف العمل المطلوب تقسيمه إلى مهام'},
    'aiDraftTextHint': {
      'fr': 'Ex. Préparer le banc d’essai, rédiger la procédure…',
      'en': 'E.g. Set up the test bench, write the procedure…',
      'ar': 'مثال: تجهيز منصة الاختبار، كتابة الإجراء…'},
    'aiDraftPickPdf': {
      'fr': 'Choisir un PDF', 'en': 'Pick a PDF', 'ar': 'اختيار ملف PDF'},
    'aiDraftChangePdf': {
      'fr': 'Changer de PDF', 'en': 'Change PDF', 'ar': 'تغيير ملف PDF'},
    'aiDraftGenerate': {
      'fr': 'Générer', 'en': 'Generate', 'ar': 'إنشاء'},
    'aiDraftGenerating': {
      'fr': 'L’IA analyse le contenu…',
      'en': 'AI is analyzing the content…',
      'ar': 'يحلل الذكاء الاصطناعي المحتوى…'},
    'aiDraftCancel': {
      'fr': 'Arrêter d’attendre', 'en': 'Stop waiting', 'ar': 'التوقف عن الانتظار'},
    'aiDraftEmpty': {
      'fr': 'Aucun brouillon pour le moment',
      'en': 'No drafts yet',
      'ar': 'لا توجد مسودات بعد'},
    'aiDraftEmptyHint': {
      'fr': 'Fournissez un PDF ou une description, puis lancez la génération.',
      'en': 'Provide a PDF or a description, then start generation.',
      'ar': 'قدم ملف PDF أو وصفاً، ثم ابدأ الإنشاء.'},
    'aiDraftManualAdd': {
      'fr': 'Ajouter un brouillon à la main',
      'en': 'Add a draft manually',
      'ar': 'إضافة مسودة يدوياً'},
    'aiDraftBadge': {
      'fr': 'Brouillon', 'en': 'Draft', 'ar': 'مسودة'},
    'aiDraftEdit': {
      'fr': 'Modifier', 'en': 'Edit', 'ar': 'تعديل'},
    'aiDraftRevise': {
      'fr': 'Réviser avec l’IA', 'en': 'Revise with AI', 'ar': 'مراجعة بالذكاء الاصطناعي'},
    'aiDraftReviseLabel': {
      'fr': 'Consigne de révision',
      'en': 'Revision instruction',
      'ar': 'تعليمة المراجعة'},
    'aiDraftReviseHint': {
      'fr': 'Ex. Rends le titre plus concret…',
      'en': 'E.g. Make the title more concrete…',
      'ar': 'مثال: اجعل العنوان أكثر تحديداً…'},
    'aiDraftDelete': {
      'fr': 'Supprimer le brouillon', 'en': 'Delete draft', 'ar': 'حذف المسودة'},
    'aiDraftDeleteTitle': {
      'fr': 'Supprimer ce brouillon ?',
      'en': 'Delete this draft?',
      'ar': 'حذف هذه المسودة؟'},
    'aiDraftTargets': {
      'fr': 'Stagiaires destinataires',
      'en': 'Target interns',
      'ar': 'المتربصون المستهدفون'},
    'aiDraftBulkAdd': {
      'fr': 'Créer les tâches',
      'en': 'Create the tasks',
      'ar': 'إنشاء المهام'},
    'aiDraftBulkDone': {
      'fr': '{n} tâche(s) créée(s).',
      'en': '{n} task(s) created.',
      'ar': 'تم إنشاء {n} من المهام.'},
    'aiDraftManualHint': {
      'fr': 'L’IA est indisponible : vous pouvez toujours créer des brouillons à la main.',
      'en': 'AI is unavailable: you can still create drafts manually.',
      'ar': 'الذكاء الاصطناعي غير متاح: لا يزال بإمكانك إنشاء مسودات يدوياً.'},
    'aiDraftNeedsConnection': {
      'fr': 'La génération IA nécessite une connexion.',
      'en': 'AI generation needs a connection.',
      'ar': 'يحتاج الإنشاء بالذكاء الاصطناعي إلى اتصال.'},
    'aiDraftNoTargets': {
      'fr': 'Choisissez au moins un stagiaire.',
      'en': 'Choose at least one intern.',
      'ar': 'اختر متربصاً واحداً على الأقل.'},
    'aiDraftNoDrafts': {
      'fr': 'Aucun brouillon à envoyer.',
      'en': 'No drafts to send.',
      'ar': 'لا توجد مسودات للإرسال.'},
    'errDraftInvalid': {
      'fr': 'Ce brouillon est refusé : vérifiez les titres (3 à 150 caractères), les dates dans la période du stage et la taille du texte.',
      'en': 'This draft was refused: check titles (3–150 characters), dates within the internship period, and text size.',
      'ar': 'تم رفض هذه المسودة: تحقق من العناوين (3 إلى 150 حرفاً)، والتواريخ ضمن فترة التربص، وحجم النص.'},
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
    'journalTitleTooLong': {'fr': 'Titre trop long ({max} caractères maximum).', 'en': 'Title too long ({max} characters maximum).', 'ar': 'العنوان طويل جدا ({max} حرفا كحد أقصى).'},
    'journalSaveDraft': {'fr': 'Enregistrer le brouillon', 'en': 'Save draft', 'ar': 'حفظ المسودة'},
    'journalSubmitAction': {'fr': 'Soumettre pour validation', 'en': 'Submit for validation', 'ar': 'إرسال للمصادقة'},
    'journalDraftSavedAt': {'fr': 'Brouillon enregistré à {t}', 'en': 'Draft saved at {t}', 'ar': 'حُفظت المسودة في {t}'},
    // --- STEG-JRN: month calendar + period highlight ---
    'journalCalendar': {
      'fr': 'Calendrier du journal',
      'en': 'Journal calendar',
      'ar': 'تقويم اليوميات',
    },
    'journalPrevMonth': {
      'fr': 'Mois précédent',
      'en': 'Previous month',
      'ar': 'الشهر السابق',
    },
    'journalNextMonth': {
      'fr': 'Mois suivant',
      'en': 'Next month',
      'ar': 'الشهر التالي',
    },
    'journalCalendarShow': {
      'fr': 'Afficher le calendrier',
      'en': 'Show calendar',
      'ar': 'إظهار التقويم',
    },
    'journalCalendarHide': {
      'fr': 'Masquer le calendrier',
      'en': 'Hide calendar',
      'ar': 'إخفاء التقويم',
    },
    'journalInPeriod': {
      'fr': 'Période de stage',
      'en': 'Internship period',
      'ar': 'فترة التربص',
    },
    'journalHasEntry': {
      'fr': 'Entrée enregistrée',
      'en': 'Entry recorded',
      'ar': 'مُدوَّن',
    },
    'journalAccent': {
      'fr': 'Couleur du stage',
      'en': 'Stage colour',
      'ar': 'لون التربص',
    },
    'journalAccentHint': {
      'fr': 'Personnalisez la couleur qui marque vos jours de stage.',
      'en': 'Personalise the colour that marks your stage days.',
      'ar': 'خصّص اللون الذي يميّز أيام التربص.',
    },
    'journalPeriodOverview': {
      'fr': 'Jour {d} sur {total}',
      'en': 'Day {d} of {total}',
      'ar': 'اليوم {d} من {total}',
    },
    'journalNoEntriesThisDay': {
      'fr': 'Rien d’enregistré ce jour-là',
      'en': 'Nothing recorded on this day',
      'ar': 'لا شيء مسجّل في هذا اليوم',
    },
    'journalAddForDay': {
      'fr': 'Ajouter une entrée',
      'en': 'Add an entry',
      'ar': 'إضافة مدخلة',
    },
    'journalWritePlaceholder': {
      'fr': 'Qu’avez-vous fait aujourd’hui ? Racontez votre journée : tâches réalisées, difficultés rencontrées, Apprentissages…',
      'en': 'What did you do today? Describe your day: work done, difficulties met, what you learned…',
      'ar': 'ماذا فعلت اليوم؟ احكِ عن يومك: الأعمال المنجزة، الصعوبات، ما تعلّمته…',
    },
    'journalTitlePlaceholder': {
      'fr': 'Titre court et factuel',
      'en': 'A short, factual title',
      'ar': 'عنوان قصير وم factual',
    },
    'journalDraftKept': {'fr': 'Brouillon local conservé.', 'en': 'Local draft kept.', 'ar': 'تم الاحتفاظ بالمسودة المحلية.'},
    'journalCreated': {'fr': 'Entrée enregistrée comme brouillon.', 'en': 'Entry saved as draft.', 'ar': 'تم حفظ الإدخال كمسودة.'},
    'journalSubmittedOk': {'fr': 'Entrée soumise pour validation.', 'en': 'Entry submitted for validation.', 'ar': 'تم إرسال الإدخال للمصادقة.'},
    'journalSubmitFailKept': {'fr': 'Envoi impossible : l’entrée reste en brouillon sur le serveur.', 'en': 'Submit failed: the entry remains a server draft.', 'ar': 'تعذر الإرسال: بقي الإدخال مسودة على الخادم.'},
    'journalDetailTitle': {'fr': 'Détail de l’entrée', 'en': 'Entry details', 'ar': 'تفاصيل الإدخال'},
    'journalComments': {'fr': 'Commentaires', 'en': 'Comments', 'ar': 'التعليقات'},
    'journalNoComments': {'fr': 'Aucun commentaire pour le moment.', 'en': 'No comments yet.', 'ar': 'لا تعليقات بعد.'},
    'journalValidatedBy': {'fr': 'Validé par {n}', 'en': 'Validated by {n}', 'ar': 'صادق عليه {n}'},
    // --- T09/B5+B6: journal document (server window + AI PDF generation) ---
    'journalGenTitle': {'fr': 'Journal de stage', 'en': 'Internship journal', 'ar': 'دفتر التربص'},
    'journalGenButton': {'fr': 'Générer le journal de stage', 'en': 'Generate the internship journal', 'ar': 'إنشاء دفتر التربص'},
    'journalGenOpensIn': {'fr': 'Disponible dans {days} jour(s)', 'en': 'Available in {days} day(s)', 'ar': 'متاح بعد {days} يوم'},
    'journalGenLate': {'fr': 'Période terminée : génération possible (en retard).', 'en': 'Period over: generation is still possible (late).', 'ar': 'انتهت الفترة: الإنشاء ما زال ممكنا (متأخر).'},
    'journalGenNoPeriod': {'fr': 'Aucune période de stage : génération impossible.', 'en': 'No internship period: generation is not possible.', 'ar': 'لا توجد فترة تربص: الإنشاء غير ممكن.'},
    'journalGenCancelled': {'fr': 'Stage annulé : génération impossible.', 'en': 'Cancelled internship: generation is not possible.', 'ar': 'تربص ملغى: الإنشاء غير ممكن.'},
    'journalGenOffline': {'fr': 'Connexion requise pour générer le journal.', 'en': 'Connection required to generate the journal.', 'ar': 'الاتصال مطلوب لإنشاء الدفتر.'},
    'journalGenChooserHint': {'fr': 'Le document est produit par le serveur en PDF : période du stage et tableau des tâches.', 'en': 'The server produces a PDF: internship period and task table.', 'ar': 'يُنشئ الخادم ملف PDF: فترة التربص وجدول المهام.'},
    'journalGenFromTasks': {'fr': 'À partir de mes tâches', 'en': 'From my tasks', 'ar': 'من مهامي'},
    'journalGenFromTasksHint': {'fr': 'Vos tâches et leurs statuts sont assemblés par le serveur.', 'en': 'Your tasks and their statuses are assembled by the server.', 'ar': 'يجمع الخادم مهامك وحالاتها.'},
    'journalGenFromText': {'fr': 'À partir de mon texte', 'en': 'From my text', 'ar': 'من نصّي'},
    'journalGenFromTextHint': {'fr': 'Décrivez votre stage ; le tableau des tâches reste ajouté par le serveur.', 'en': 'Describe your internship; the task table is still added by the server.', 'ar': 'صِف تربصك؛ يبقى جدول المهام مضافا من الخادم.'},
    'journalGenTextLabel': {'fr': 'Description du stage', 'en': 'Internship description', 'ar': 'وصف التربص'},
    'journalGenTextHint': {'fr': 'Activités, missions, résultats…', 'en': 'Activities, missions, results…', 'ar': 'الأنشطة والمهام والنتائج…'},
    'journalGenTextCounter': {'fr': '{used} / {max} caractères', 'en': '{used} / {max} characters', 'ar': '{used} / {max} حرفا'},
    'journalGenTextTooShort': {'fr': 'Au moins {min} caractères sont requis.', 'en': 'At least {min} characters are required.', 'ar': 'مطلوب {min} حرفا على الأقل.'},
    'journalGenProgress': {'fr': 'Génération en cours…', 'en': 'Generating…', 'ar': 'جارٍ الإنشاء…'},
    'journalGenStart': {'fr': 'Lancer la génération', 'en': 'Start generation', 'ar': 'بدء الإنشاء'},
    'journalGenBelowThreshold': {'fr': 'Seulement {done} sur {total} tâches approuvées : le journal peut échouer la vérification.', 'en': 'Only {done} of {total} tasks are approved: the journal may fail verification.', 'ar': 'تمت المصادقة على {done} من {total} مهمة فقط: قد يفشل التحقق من الدفتر.'},
    'journalGenNoTasks': {'fr': 'Aucune tâche enregistrée : le tableau du journal sera vide.', 'en': 'No task recorded: the journal table will be empty.', 'ar': 'لا توجد مهام مسجلة: سيكون جدول الدفتر فارغا.'},
    'journalGenDone': {'fr': 'Journal généré en brouillon (version {v}).', 'en': 'Journal generated as a draft (version {v}).', 'ar': 'أُنشئ الدفتر كمسودة (النسخة {v}).'},
    'journalGenReplaced': {'fr': 'Le brouillon précédent a été remplacé.', 'en': 'The previous draft was replaced.', 'ar': 'تم استبدال المسودة السابقة.'},
    'journalGenPreviousSubmitted': {'fr': 'Un journal déjà soumis reste inchangé : ceci est un nouveau brouillon.', 'en': 'An already submitted journal stays unchanged: this is a new draft.', 'ar': 'يبقى الدفتر المرسل دون تغيير: هذه مسودة جديدة.'},
    'journalGenOpen': {'fr': 'Ouvrir / partager le PDF', 'en': 'Open / share the PDF', 'ar': 'فتح / مشاركة ملف PDF'},
    'journalGenOpenFailed': {'fr': 'Ouverture du fichier impossible.', 'en': 'Could not open the file.', 'ar': 'تعذر فتح الملف.'},
    'journalGenRegenerate': {'fr': 'Régénérer', 'en': 'Regenerate', 'ar': 'إعادة الإنشاء'},
    'journalGenRegenerateConfirm': {'fr': 'Régénérer le journal ? Le brouillon précédent sera remplacé.', 'en': 'Regenerate the journal? The previous draft will be replaced.', 'ar': 'إعادة إنشاء الدفتر؟ ستُستبدل المسودة السابقة.'},
    'journalGenKeep': {'fr': 'Conserver', 'en': 'Keep', 'ar': 'الاحتفاظ'},
    'journalGenKeepNote': {'fr': 'Conserver n’envoie rien : personne n’est notifié tant que le livrable n’est pas soumis.', 'en': 'Keeping sends nothing: nobody is notified until the deliverable is submitted.', 'ar': 'الاحتفاظ لا يرسل شيئا: لا يُخطَر أحد حتى يتم إرسال المُخرَج.'},
    'journalGenManualPath': {'fr': 'Écrire une entrée de journal manuellement', 'en': 'Write a journal entry manually', 'ar': 'كتابة إدخال في اليومية يدويا'},
    'journalGenCancel': {'fr': 'Annuler', 'en': 'Cancel', 'ar': 'إلغاء'},
    'journalGenClose': {'fr': 'Fermer', 'en': 'Close', 'ar': 'إغلاق'},
    'journalGenSourceTasks': {'fr': 'Source : mes tâches', 'en': 'Source: my tasks', 'ar': 'المصدر: مهامي'},
    'journalGenSourceText': {'fr': 'Source : mon texte', 'en': 'Source: my text', 'ar': 'المصدر: نصّي'},
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
    'reviewFirstLevelNote': {'fr': 'L’approbation transmet le document à l’administration — la décision finale de validation lui appartient.', 'en': 'Approval forwards the document to the administration — the final validation decision is theirs.', 'ar': 'الموافقة تحيل الوثيقة إلى الإدارة — وقرار المصادقة النهائي لها.'},
    'rejectionDone': {'fr': 'Correction demandée.', 'en': 'Correction requested.', 'ar': 'تم طلب التصحيح.'},
    'validationPending': {'fr': 'Décision non confirmée par le serveur.', 'en': 'Decision not confirmed by the server.', 'ar': 'لم يؤكد الخادم القرار.'},
    'unsavedTitle': {'fr': 'Abandonner les modifications ?', 'en': 'Discard changes?', 'ar': 'تجاهل التغييرات؟'},
    'unsavedMessage': {'fr': 'Vos modifications non enregistrées seront perdues.', 'en': 'Your unsaved changes will be lost.', 'ar': 'ستفقد تغييراتك غير المحفوظة.'},
    'discardAction': {'fr': 'Abandonner', 'en': 'Discard', 'ar': 'تجاهل'},
    'keepEditingAction': {'fr': 'Continuer', 'en': 'Keep editing', 'ar': 'مواصلة التحرير'},
    'cancelAction': {'fr': 'Annuler', 'en': 'Cancel', 'ar': 'إلغاء'},
    'closeAction': {'fr': 'Fermer', 'en': 'Close', 'ar': 'إغلاق'},
    // --- D3: deliverables ---
    'deliverablesSubtitle': {'fr': 'PDF uniquement · 25 Mo max · versions conservées', 'en': 'PDF only · 25 MB max · versions kept', 'ar': 'PDF فقط · 25 م.ب كحد أقصى · تُحفظ النسخ'},
    'deliverableNew': {'fr': 'Nouveau livrable', 'en': 'New deliverable', 'ar': 'مُخرَج جديد'},
    'deliverableTitleLabel': {'fr': 'Titre du livrable', 'en': 'Deliverable title', 'ar': 'عنوان المُخرَج'},
    'deliverableDescLabel': {'fr': 'Description (optionnel)', 'en': 'Description (optional)', 'ar': 'الوصف (اختياري)'},
    'deliverablePickFile': {'fr': 'Choisir un PDF', 'en': 'Choose a PDF', 'ar': 'اختيار ملف PDF'},
    'deliverableChangeFile': {'fr': 'Changer de fichier', 'en': 'Change file', 'ar': 'تغيير الملف'},
    'deliverableNoFile': {'fr': 'Aucun fichier sélectionné.', 'en': 'No file selected.', 'ar': 'لم يُختر أي ملف.'},
    'deliverableWrongType': {'fr': 'Seuls les fichiers PDF sont acceptés.', 'en': 'Only PDF files are accepted.', 'ar': 'تُقبل ملفات PDF فقط.'},
    'deliverableTooLarge': {'fr': 'Fichier trop volumineux (25 Mo max).', 'en': 'File too large (25 MB max).', 'ar': 'الملف كبير جدا (25 م.ب كحد أقصى).'},
    'deliverableUpload': {'fr': 'Téléverser', 'en': 'Upload', 'ar': 'رفع'},
    'deliverableUploaded': {'fr': 'Livrable enregistré comme brouillon.', 'en': 'Deliverable saved as draft.', 'ar': 'تم حفظ المُخرَج كمسودة.'},
    'deliverableSubmitAction': {'fr': 'Soumettre pour validation', 'en': 'Submit for validation', 'ar': 'إرسال للمصادقة'},
    'deliverableSubmittedOk': {'fr': 'Livrable soumis.', 'en': 'Deliverable submitted.', 'ar': 'تم إرسال المُخرَج.'},
    'deliverableNewVersion': {'fr': 'Nouvelle version', 'en': 'New version', 'ar': 'نسخة جديدة'},
    'deliverableChangeNote': {'fr': 'Que change cette version ? (optionnel)', 'en': 'What changed? (optional)', 'ar': 'ما الذي تغير؟ (اختياري)'},
    'deliverableVersionUploaded': {'fr': 'Nouvelle version enregistrée.', 'en': 'New version saved.', 'ar': 'تم حفظ النسخة الجديدة.'},
    'deliverableValidatedLocked': {'fr': 'Validé : plus aucune nouvelle version possible.', 'en': 'Validated: no further versions allowed.', 'ar': 'تمت المصادقة: لا يمكن إضافة نسخ أخرى.'},
    'deliverableVersions': {'fr': 'Historique des versions', 'en': 'Version history', 'ar': 'سجل النسخ'},
    'deliverableDownload': {'fr': 'Télécharger', 'en': 'Download', 'ar': 'تنزيل'},
    'deliverableDownloading': {'fr': 'Téléchargement…', 'en': 'Downloading…', 'ar': 'جارٍ التنزيل…'},
    'deliverableChecklistTodo': {'fr': 'À finaliser', 'en': 'To finalize', 'ar': 'للإتمام'},
    'deliverableChecklistPending': {'fr': 'En attente de validation', 'en': 'Awaiting validation', 'ar': 'بانتظار المصادقة'},
    'deliverableChecklistDone': {'fr': 'Validés', 'en': 'Validated', 'ar': 'المصادق عليها'},
    'deliverableChecklistEmpty': {'fr': 'Aucun livrable pour le moment.', 'en': 'No deliverables yet.', 'ar': 'لا مُخرَجات بعد.'},
    'deliverableReviewTitle': {'fr': 'Réviser le livrable', 'en': 'Review deliverable', 'ar': 'مراجعة المُخرَج'},
    'deliverableReviewsEmpty': {'fr': 'Aucun livrable à réviser.', 'en': 'No deliverables to review.', 'ar': 'لا مُخرَجات للمراجعة.'},
    'uploadFailedRetry': {'fr': 'Échec de l’envoi. Réessayez.', 'en': 'Upload failed. Retry.', 'ar': 'فشل الرفع. أعد المحاولة.'},
    // --- D4: supervisor workspace & evaluations ---
    'myInterns': {'fr': 'Mes stagiaires', 'en': 'My interns', 'ar': 'متربصيّ'},
    'noSupervised': {'fr': 'Aucun stagiaire lié pour le moment.', 'en': 'No linked interns yet.', 'ar': 'لا متربصين مرتبطين بعد.'},
    'noSupervisedHint': {'fr': 'Les stagiaires apparaissent ici dès leur affectation.', 'en': 'Interns appear here once assigned to you.', 'ar': 'يظهر المتربصون هنا بمجرد تعيينهم لك.'},
    'supViewList': {'fr': 'Liste', 'en': 'List', 'ar': 'قائمة'},
    'supViewCalendar': {'fr': 'Calendrier', 'en': 'Calendar', 'ar': 'تقويم'},
    'supSearchHint': {'fr': 'Rechercher (nom, référence)…', 'en': 'Search (name, reference)…', 'ar': 'بحث (الاسم، المرجع)…'},
    'supSortName': {'fr': 'Nom', 'en': 'Name', 'ar': 'الاسم'},
    'supSortEndDate': {'fr': 'Fin de stage', 'en': 'Internship end', 'ar': 'نهاية التربص'},
    'supSortStatus': {'fr': 'Statut', 'en': 'Status', 'ar': 'الحالة'},
    'supPrevMonth': {'fr': 'Mois précédent', 'en': 'Previous month', 'ar': 'الشهر السابق'},
    'supNextMonth': {'fr': 'Mois suivant', 'en': 'Next month', 'ar': 'الشهر التالي'},
    'supEmptyMonth': {'fr': 'Aucun stage sur ce mois.', 'en': 'No internships this month.', 'ar': 'لا تربصات في هذا الشهر.'},
    'needsAttention': {'fr': 'Nécessite votre attention', 'en': 'Needs your attention', 'ar': 'يحتاج إلى انتباهك'},
    'allCaughtUp': {'fr': 'Tout est à jour.', 'en': 'All caught up.', 'ar': 'كل شيء محدث.'},
    'internDetailTitle': {'fr': 'Dossier stagiaire', 'en': 'Intern file', 'ar': 'ملف المتربص'},
    'evalPendingJournal': {'fr': 'Journal à valider', 'en': 'Journal awaiting validation', 'ar': 'يومية بانتظار المصادقة'},
    'evalTasksSection': {'fr': 'Tâches prévues', 'en': 'Planned tasks', 'ar': 'المهام المخططة'},
    'evalDeliverablesSection': {'fr': 'Livrables', 'en': 'Deliverables', 'ar': 'المُخرَجات'},
    'evalHistorySection': {'fr': 'Évaluations', 'en': 'Evaluations', 'ar': 'التقييمات'},
    'evalNew': {'fr': 'Nouvelle évaluation', 'en': 'New evaluation', 'ar': 'تقييم جديد'},
    'evalTemplate': {'fr': 'Grille d’évaluation', 'en': 'Evaluation template', 'ar': 'شبكة التقييم'},
    'evalTemplateHint': {'fr': 'Critères officiels fournis par le backend.', 'en': 'Official criteria provided by the backend.', 'ar': 'المعايير الرسمية المقدمة من الخادم.'},
    'evalNoTemplate': {'fr': 'Aucune grille active disponible.', 'en': 'No active template available.', 'ar': 'لا توجد شبكة نشطة متاحة.'},
    'evalType': {'fr': 'Type', 'en': 'Type', 'ar': 'النوع'},
    'evalDate': {'fr': 'Date', 'en': 'Date', 'ar': 'التاريخ'},
    'evalTypeDaily': {'fr': 'Quotidienne', 'en': 'Daily', 'ar': 'يومية'},
    'evalTypeWeekly': {'fr': 'Hebdomadaire', 'en': 'Weekly', 'ar': 'أسبوعية'},
    'evalTypeMid': {'fr': 'Mi-parcours', 'en': 'Mid-term', 'ar': 'منتصف المدة'},
    'evalTypeFinal': {'fr': 'Finale', 'en': 'Final', 'ar': 'نهائية'},
    'evalTypeCustom': {'fr': 'Personnalisée', 'en': 'Custom', 'ar': 'مخصصة'},
    'evalScoreOf': {'fr': 'Note / {m}', 'en': 'Score / {m}', 'ar': 'النقطة / {m}'},
    'evalScoreInvalid': {'fr': 'Note entre 0 et {m}.', 'en': 'Score between 0 and {m}.', 'ar': 'النقطة بين 0 و {m}.'},
    'evalCriterionComment': {'fr': 'Commentaire (optionnel)', 'en': 'Comment (optional)', 'ar': 'تعليق (اختياري)'},
    'evalTaskReviews': {'fr': 'Revue des tâches réelles', 'en': 'Actual task reviews', 'ar': 'مراجعة المهام الفعلية'},
    'evalTaskReviewsHint': {'fr': 'Reliez l’évaluation aux tâches vraiment effectuées.', 'en': 'Link the evaluation to actually performed tasks.', 'ar': 'اربط التقييم بالمهام المنجزة فعلا.'},
    'evalIncludeTask': {'fr': 'Inclure', 'en': 'Include', 'ar': 'إدراج'},
    'evalTaskDone': {'fr': 'Terminée', 'en': 'Completed', 'ar': 'منجزة'},
    'evalTaskNotDone': {'fr': 'Non terminée', 'en': 'Not completed', 'ar': 'غير منجزة'},
    'evalFeedback': {'fr': 'Appréciation et conseils', 'en': 'Assessment and advice', 'ar': 'التقييم والنصائح'},
    'evalFeedbackHint': {'fr': 'Conseils au stagiaire — distinct du journal.', 'en': 'Advice to the intern — separate from the journal.', 'ar': 'نصائح للمتربص — منفصلة عن اليومية.'},
    'evalEstimate': {'fr': 'Estimation indicative : {n} / 20', 'en': 'Indicative estimate: {n} / 20', 'ar': 'تقدير تقريبي: {n} / 20'},
    'evalEstimateNote': {'fr': 'Le total officiel est calculé par le serveur après envoi.', 'en': 'The official total is computed by the server after submit.', 'ar': 'يُحتسب المجموع الرسمي على الخادم بعد الإرسال.'},
    'evalSubmit': {'fr': 'Soumettre l’évaluation', 'en': 'Submit evaluation', 'ar': 'إرسال التقييم'},
    'evalConfirmTitle': {'fr': 'Soumettre cette évaluation ?', 'en': 'Submit this evaluation?', 'ar': 'إرسال هذا التقييم؟'},
    'evalConfirmMessage': {'fr': 'Elle deviendra un document officiel visible par le stagiaire.', 'en': 'It will become an official record visible to the intern.', 'ar': 'سيصبح وثيقة رسمية مرئية للمتربص.'},
    'evalSubmitted': {'fr': 'Évaluation enregistrée.', 'en': 'Evaluation saved.', 'ar': 'تم حفظ التقييم.'},
    'evalOfficialTotal': {'fr': 'Total officiel : {n} / 20', 'en': 'Official total: {n} / 20', 'ar': 'المجموع الرسمي: {n} / 20'},
    'evalScoresSection': {'fr': 'Notes par critère', 'en': 'Scores per criterion', 'ar': 'النقاط حسب المعيار'},
    'evalReviewsSection': {'fr': 'Revue des tâches', 'en': 'Task reviews', 'ar': 'مراجعة المهام'},
    'evalNoScores': {'fr': 'Au moins une note est requise.', 'en': 'At least one score is required.', 'ar': 'يلزم إدخال نقطة واحدة على الأقل.'},
    'evalAdviceSection': {'fr': 'Appréciation', 'en': 'Assessment', 'ar': 'التقييم'},
    'myEvaluations': {'fr': 'Mes évaluations', 'en': 'My evaluations', 'ar': 'تقييماتي'},
    'myEvaluationsEmpty': {'fr': 'Aucune évaluation reçue pour le moment.', 'en': 'No evaluations received yet.', 'ar': 'لم تُستلم أي تقييمات بعد.'},
    'evalOptionalScore': {'fr': 'Note (optionnel)', 'en': 'Score (optional)', 'ar': 'النقطة (اختياري)'},
    // --- D5: messaging & notifications ---
    'convTitle': {'fr': 'Messages', 'en': 'Messages', 'ar': 'الرسائل'},
    'convEmpty': {'fr': 'Aucune conversation.', 'en': 'No conversations.', 'ar': 'لا محادثات.'},
    'convEmptyHint': {'fr': 'Vos échanges avec votre encadrant et les stagiaires apparaîtront ici.', 'en': 'Your exchanges with your supervisor and fellow interns will appear here.', 'ar': 'ستظهر هنا محادثاتك مع مؤطرك وزملائك المتربصين.'},
    'convPrivate': {'fr': 'Échange privé', 'en': 'Private chat', 'ar': 'محادثة خاصة'},
    'convGroup': {'fr': 'Groupe des stagiaires', 'en': 'Interns group', 'ar': 'مجموعة المتربصين'},
    'msgHint': {'fr': 'Écrivez votre message…', 'en': 'Write your message…', 'ar': 'اكتب رسالتك…'},
    'msgSend': {'fr': 'Envoyer', 'en': 'Send', 'ar': 'إرسال'},
    'msgFailed': {'fr': 'Non envoyé. Touchez pour réessayer.', 'en': 'Not sent. Tap to retry.', 'ar': 'لم تُرسل. انقر لإعادة المحاولة.'},
    'msgRetry': {'fr': 'Réessayer', 'en': 'Retry', 'ar': 'إعادة المحاولة'},
    'msgDiscard': {'fr': 'Supprimer', 'en': 'Delete', 'ar': 'حذف'},
    'offlineQueued': {
      'fr': 'Enregistré — sera envoyé à la reconnexion.',
      'en': 'Saved — will send on reconnect.',
      'ar': 'تم الحفظ — سيُرسل عند إعادة الاتصال.'},
    'pendingLabel': {'fr': 'En attente', 'en': 'Pending', 'ar': 'قيد الانتظار'},
    'queueFull': {
      'fr': 'File pleine — réessayez une fois en ligne.',
      'en': 'Queue is full — retry once online.',
      'ar': 'القائمة ممتلئة — أعد المحاولة عند الاتصال.'},
    'queueAuthDiscarded': {
      'fr': 'Session expirée : les éléments non envoyés ont été supprimés.',
      'en': 'Session expired: unsent items were discarded.',
      'ar': 'انتهت الجلسة: تم تجاهل العناصر غير المرسلة.'},
    'msgDeleted': {'fr': 'Message supprimé', 'en': 'Message deleted', 'ar': 'رسالة محذوفة'},
    'msgEdited': {'fr': 'modifié', 'en': 'edited', 'ar': 'معدلة'},
    'msgDelivered': {'fr': 'Reçu', 'en': 'Delivered', 'ar': 'تم الاستلام'},
    'msgRead': {'fr': 'Lu', 'en': 'Read', 'ar': 'مقروءة'},
    'msgSent': {'fr': 'Envoyé', 'en': 'Sent', 'ar': 'مُرسلة'},
    'msgAttach': {'fr': 'Joindre un fichier', 'en': 'Attach a file', 'ar': 'إرفاق ملف'},
    'msgAttachCaption': {'fr': 'Légende (requise)', 'en': 'Caption (required)', 'ar': 'التسمية (مطلوبة)'},
    'msgAttachTypes': {'fr': 'PDF, JPEG ou PNG · 10 Mo max', 'en': 'PDF, JPEG or PNG · 10 MB max', 'ar': 'PDF أو JPEG أو PNG · 10 م.ب كحد أقصى'},
    'msgAttachTooLarge': {'fr': 'Fichier trop volumineux (10 Mo max).', 'en': 'File too large (10 MB max).', 'ar': 'الملف كبير جدا (10 م.ب كحد أقصى).'},
    'msgAttachWrongType': {'fr': 'Seuls PDF, JPEG et PNG sont acceptés.', 'en': 'Only PDF, JPEG and PNG are accepted.', 'ar': 'تُقبل ملفات PDF و JPEG و PNG فقط.'},
    'msgDownload': {'fr': 'Télécharger', 'en': 'Download', 'ar': 'تنزيل'},
    'msgNoHistory': {'fr': 'Aucun message. Dites bonjour !', 'en': 'No messages yet. Say hello!', 'ar': 'لا رسائل بعد. قل مرحبا!'},
    'msgSayHi': {'fr': 'Commencez la conversation.', 'en': 'Start the conversation.', 'ar': 'ابدأ المحادثة.'},
    // --- T07: send journal/report from the chat (ST-MSG-02, ST-VAL-02) ---
    'msgFromDocs': {'fr': 'Envoyer un document du stage', 'en': 'Send an internship document', 'ar': 'إرسال وثيقة من التربص'},
    'msgPickDoc': {'fr': 'Choisir un document à envoyer', 'en': 'Choose a document to send', 'ar': 'اختر وثيقة لإرسالها'},
    'msgNoDocs': {'fr': 'Aucun document disponible. Déposez d’abord votre journal ou votre rapport depuis l’écran Documents.', 'en': 'No documents available yet. Upload your journal or report from the Documents screen first.', 'ar': 'لا توجد وثائق متاحة بعد. أودع يومياتك أو تقريرك من شاشة الوثائق أولا.'},
    'msgDocTooLarge': {'fr': 'Ce document dépasse 10 Mo : la messagerie ne peut pas le transporter. Envoyez-le depuis l’écran de validation/Documents.', 'en': 'This document exceeds 10 MB: chat cannot carry it. Send it from the validation/Documents screen instead.', 'ar': 'تتجاوز هذه الوثيقة 10 م.ب: لا يمكن للمحادثة نقلها. أرسلها من شاشة المصادقة/الوثائق.'},
    'msgDocLoadFailed': {'fr': 'Document introuvable. Actualisez puis réessayez.', 'en': 'Document unavailable. Refresh and try again.', 'ar': 'الوثيقة غير متاحة. حدّث البيانات ثم أعد المحاولة.'},
    // --- T07: day separators (relative when recent) ---
    'msgToday': {'fr': 'Aujourd’hui', 'en': 'Today', 'ar': 'اليوم'},
    'msgYesterday': {'fr': 'Hier', 'en': 'Yesterday', 'ar': 'أمس'},
    // --- 1-to-1 message actions (edit / delete / seen) ---
    'msgEdit': {'fr': 'Modifier', 'en': 'Edit', 'ar': 'تعديل'},
    'msgEditTitle': {'fr': 'Modifier le message', 'en': 'Edit message', 'ar': 'تعديل الرسالة'},
    'msgDeleteTitle': {'fr': 'Supprimer le message ?', 'en': 'Delete message?', 'ar': 'حذف الرسالة؟'},
    'msgDeleteConfirm': {'fr': 'Le contenu sera masqué pour les deux participants, mais l’historique est conservé.', 'en': 'The content will be hidden for both participants, but history is kept.', 'ar': 'سيُخفى المحتوى عن الطرفين، مع الاحتفاظ بالسجل.'},
    'msgSave': {'fr': 'Enregistrer', 'en': 'Save', 'ar': 'حفظ'},
    'msgSeen': {'fr': 'Vu', 'en': 'Seen', 'ar': 'تمت المشاهدة'},
    'msgMarkRead': {'fr': 'Marquer comme lu', 'en': 'Mark as read', 'ar': 'تعليم كمقروء'},
    'msgPickFailed': {'fr': 'Sélection du fichier impossible. Réessayez.', 'en': 'Could not pick the file. Try again.', 'ar': 'تعذّر اختيار الملف. أعد المحاولة.'},
    'msgActionFailed': {'fr': 'Action impossible. Réessayez.', 'en': 'Action failed. Try again.', 'ar': 'تعذّر تنفيذ الإجراء. أعد المحاولة.'},
    'msgOnline': {'fr': 'En ligne', 'en': 'Online', 'ar': 'متصل'},
    'msgOfflineShort': {'fr': 'Hors ligne', 'en': 'Offline', 'ar': 'غير متصل'},
    // --- T08 student community (ST-COM-01/02, D7) ---
    'communityTitle': {'fr': 'Communauté', 'en': 'Community', 'ar': 'المجتمع'},
    'communityEmpty': {'fr': 'Aucune publication pour le moment.', 'en': 'No posts yet.', 'ar': 'لا منشورات بعد.'},
    'communityEmptyHint': {'fr': 'Posez votre première question — vos collègues stagiaires sont là pour aider.', 'en': 'Ask your first question — your fellow interns are here to help.', 'ar': 'اطرح سؤالك الأول — زملاؤك المتربصون هنا للمساعدة.'},
    'communityComposerHint': {'fr': 'Partagez une question ou un conseil…', 'en': 'Share a question or a tip…', 'ar': 'شارك سؤالا أو نصيحة…'},
    'communityPublish': {'fr': 'Publier', 'en': 'Post', 'ar': 'نشر'},
    'communityAttach': {'fr': 'Joindre image/PDF (optionnel)', 'en': 'Attach image/PDF (optional)', 'ar': 'إرفاق صورة/PDF (اختياري)'},
    'communityComments': {'fr': 'Commentaires', 'en': 'Comments', 'ar': 'التعليقات'},
    'communityNoComments': {'fr': 'Aucun commentaire. Soyez le premier à répondre !', 'en': 'No comments yet. Be the first to reply!', 'ar': 'لا تعليقات بعد. كن أول من يرد!'},
    'communityAddComment': {'fr': 'Écrivez une réponse…', 'en': 'Write a reply…', 'ar': 'اكتب ردا…'},
    'communityReport': {'fr': 'Signaler', 'en': 'Report', 'ar': 'إبلاغ'},
    'communityReportHint': {'fr': 'Décrivez le problème (visible par les modérateurs uniquement).', 'en': 'Describe the issue (visible to moderators only).', 'ar': 'صف المشكلة (مرئي للمشرفين فقط).'},
    'communityReportSent': {'fr': 'Signalement envoyé. Merci !', 'en': 'Report sent. Thank you!', 'ar': 'تم إرسال البلاغ. شكرا!'},
    'communityDelete': {'fr': 'Supprimer', 'en': 'Delete', 'ar': 'حذف'},
    'communityDeleteConfirm': {'fr': 'Supprimer définitivement ce contenu ?', 'en': 'Permanently delete this content?', 'ar': 'حذف هذا المحتوى نهائيا؟'},
    'communityRemove': {'fr': 'Retirer (modération)', 'en': 'Remove (moderation)', 'ar': 'إزالة (إشراف)'},
    'communityRemoveReason': {'fr': 'Motif du retrait (requis)', 'en': 'Removal reason (required)', 'ar': 'سبب الإزالة (مطلوب)'},
    'communityMute': {'fr': 'Couper l’accès', 'en': 'Mute', 'ar': 'كتم'},
    'communityMuteReason': {'fr': 'Motif (requis, montré à l’étudiant)', 'en': 'Reason (required, shown to the student)', 'ar': 'السبب (مطلوب، يظهر للطالب)'},
    'communityMuteDuration': {'fr': 'Durée', 'en': 'Duration', 'ar': 'المدة'},
    'communityMuteHour': {'fr': '1 heure', 'en': '1 hour', 'ar': 'ساعة واحدة'},
    'communityMuteDay': {'fr': '1 jour', 'en': '1 day', 'ar': 'يوم واحد'},
    'communityMuteWeek': {'fr': '7 jours', 'en': '7 days', 'ar': '7 أيام'},
    'communityMuteMonth': {'fr': '30 jours', 'en': '30 days', 'ar': '30 يوما'},
    'communityUnmute': {'fr': 'Lever la sanction', 'en': 'Unmute', 'ar': 'رفع الكتم'},
    'communityResolve': {'fr': 'Clore le signalement', 'en': 'Resolve report', 'ar': 'غلق البلاغ'},
    'communityResolution': {'fr': 'Conclusion (optionnelle)', 'en': 'Resolution (optional)', 'ar': 'الخلاصة (اختيارية)'},
    'communityReports': {'fr': 'Signalements', 'en': 'Reports', 'ar': 'البلاغات'},
    'communityOpenReports': {'fr': 'En attente', 'en': 'Open', 'ar': 'مفتوحة'},
    'communityAllReports': {'fr': 'Tous', 'en': 'All', 'ar': 'الكل'},
    'communityNoReports': {'fr': 'Aucun signalement. Belle communauté !', 'en': 'No reports. Healthy community!', 'ar': 'لا بلاغات. مجتمع سليم!'},
    'communityRemovedGone': {'fr': 'Ce contenu n’est plus disponible.', 'en': 'This content is no longer available.', 'ar': 'هذا المحتوى لم يعد متاحا.'},
    'communityNeedsConnection': {'fr': 'Connexion requise pour publier.', 'en': 'Connection required to post.', 'ar': 'الاتصال مطلوب للنشر.'},
    'submitNeedsConnection': {'fr': 'Connexion requise pour enregistrer.', 'en': 'Connection required to save.', 'ar': 'الاتصال مطلوب للحفظ.'},
    'uploadNeedsConnection': {'fr': 'Connexion requise pour téléverser.', 'en': 'Connection required to upload.', 'ar': 'الاتصال مطلوب للرفع.'},
    'communityNewAvailable': {'fr': 'Nouveautés — tirer pour actualiser', 'en': 'New activity — pull to refresh', 'ar': 'نشاط جديد — اسحب للتحديث'},
    'sockConnecting': {'fr': 'Connexion en cours…', 'en': 'Connecting…', 'ar': 'جارٍ الاتصال…'},
    'sockOffline': {'fr': 'Temps réel indisponible — les messages s’envoient par relais.', 'en': 'Real-time unavailable — messages use fallback.', 'ar': 'الوقت الحقيقي غير متاح — تُرسل الرسائل بالطريقة البديلة.'},
    'sockLive': {'fr': 'Temps réel actif', 'en': 'Real-time live', 'ar': 'الوقت الحقيقي نشط'},
    'notifTitle': {'fr': 'Notifications', 'en': 'Notifications', 'ar': 'الإشعارات'},
    'notifEmpty': {'fr': 'Aucune notification.', 'en': 'No notifications.', 'ar': 'لا إشعارات.'},
    'notifUnreadOnly': {'fr': 'Non lues', 'en': 'Unread', 'ar': 'غير المقروءة'},
    'notifMarkRead': {'fr': 'Marquer comme lue', 'en': 'Mark as read', 'ar': 'تعليم كمقروءة'},
    'notifMarkAllRead': {'fr': 'Tout marquer comme lu', 'en': 'Mark all as read', 'ar': 'تعليم الكل كمقروء'},
    'notifOpen': {'fr': 'Ouvrir', 'en': 'Open', 'ar': 'فتح'},
    // --- T01 notification catalogue (D11) + grouped-list labels ---
    'notifTypeTaskAssigned': {
      'fr': 'Nouvelle tâche', 'en': 'New task', 'ar': 'مهمة جديدة'},
    'notifTypeTaskUpdated': {
      'fr': 'Tâche modifiée', 'en': 'Task edited', 'ar': 'تم تعديل المهمة'},
    'notifTypeTaskDeleted': {
      'fr': 'Tâche supprimée', 'en': 'Task deleted', 'ar': 'تم حذف المهمة'},
    'notifTypeTaskStatusChanged': {
      'fr': 'Tâche mise à jour', 'en': 'Task status changed', 'ar': 'تغيرت حالة المهمة'},
    'notifTypeScheduledTaskVisible': {
      'fr': 'Nouvelle tâche disponible', 'en': 'New task available', 'ar': 'مهمة جديدة متاحة'},
    'notifTypeDocumentRejected': {
      'fr': 'Document refusé', 'en': 'Document rejected', 'ar': 'تم رفض المستند'},
    'notifTypeDocumentVerified': {
      'fr': 'Document vérifié', 'en': 'Document verified', 'ar': 'تم التحقق من المستند'},
    'notifTypeApplicationSubmitted': {
      'fr': 'Candidature envoyée', 'en': 'Application submitted', 'ar': 'تم إرسال الترشح'},
    'notifTypeApplicationResubmitted': {
      'fr': 'Candidature renvoyée', 'en': 'Application resubmitted', 'ar': 'تمت إعادة إرسال الترشح'},
    'notifTypeApplicationAccepted': {
      'fr': 'Candidature acceptée', 'en': 'Application accepted', 'ar': 'تم قبول الترشح'},
    'notifTypeApplicationRejected': {
      'fr': 'Candidature refusée', 'en': 'Application rejected', 'ar': 'تم رفض الترشح'},
    'notifTypeApplicationModification': {
      'fr': 'Modification demandée', 'en': 'Changes requested', 'ar': 'طلب تعديل'},
    'notifTypeCandidateValidated': {
      'fr': 'Profil validé', 'en': 'Profile validated', 'ar': 'تمت المصادقة على الملف'},
    'notifTypeInternshipAssigned': {
      'fr': 'Stage attribué', 'en': 'Internship assigned', 'ar': 'تم إسناد التربص'},
    'notifTypeInternshipStatusChanged': {
      'fr': 'Stage mis à jour', 'en': 'Internship updated', 'ar': 'تم تحديث التربص'},
    'notifTypeInternshipReportSubmitted': {
      'fr': 'Rapport soumis', 'en': 'Report submitted', 'ar': 'تم إرسال التقرير'},
    'notifTypeFinalEvaluationRequired': {
      'fr': 'Évaluation finale requise', 'en': 'Final evaluation required', 'ar': 'التقييم النهائي مطلوب'},
    'notifTypeJournalValidated': {
      'fr': 'Journal validé', 'en': 'Journal validated', 'ar': 'تم مصادقة الدفتر'},
    'notifTypePaymentApproved': {
      'fr': 'Paiement approuvé', 'en': 'Payment approved', 'ar': 'تمت المصادقة على الأداء'},
    'notifTypeCertificateAvailable': {
      'fr': 'Certificat disponible', 'en': 'Certificate available', 'ar': 'الشهادة متاحة'},
    'notifTypeMessageReceived': {
      'fr': 'Nouveau message', 'en': 'New message', 'ar': 'رسالة جديدة'},
    'notifTypeWelcome': {
      'fr': 'Bienvenue', 'en': 'Welcome', 'ar': 'مرحبا'},
    // --- T08 community catalogue keys (producer-backed, D7) ---
    'notifTypeCommunityComment': {
      'fr': 'Réponse communauté', 'en': 'Community reply', 'ar': 'رد في المجتمع'},
    'notifTypeCommunityPostRemoved': {
      'fr': 'Publication retirée', 'en': 'Post removed', 'ar': 'تمت إزالة المنشور'},
    'notifTypeCommunityCommentRemoved': {
      'fr': 'Commentaire retiré', 'en': 'Comment removed', 'ar': 'تمت إزالة التعليق'},
    'notifTypeDocumentsPreparation': {
      'fr': 'Préparer les documents', 'en': 'Prepare documents', 'ar': 'جهّز الوثائق'},
    'notifTypeGeneric': {
      'fr': 'Notification', 'en': 'Notification', 'ar': 'إشعار'},
    'notifToday': {
      'fr': 'Aujourd’hui', 'en': 'Today', 'ar': 'اليوم'},
    'notifWelcomeEmpty': {
      'fr': 'Rien pour le moment — vos tâches et documents apparaîtront ici.',
      'en': 'Nothing yet — your tasks and documents will appear here.',
      'ar': 'لا شيء بعد — ستظهر مهامك ومستنداتك هنا.'},
    'notifOfflineCached': {
      'fr': 'Hors ligne — affichage du dernier état connu',
      'en': 'Offline — showing the last known state',
      'ar': 'غير متصل — عرض الحالة الأخيرة المعروفة'},
    'notifUnavailable': {
      'fr': 'Notification introuvable ou expirée.',
      'en': 'Notification unavailable or expired.',
      'ar': 'الإشعار غير متاح أو منتهي.'},
    // --- D6: progress overview + advisory logbook ---
    'progressTitle': {'fr': 'Progression globale', 'en': 'Overall progress', 'ar': 'التقدم العام'},
    'progressTasks': {'fr': 'Tâches accomplies', 'en': 'Tasks completed', 'ar': 'المهام المنجزة'},
    'progressJournal': {'fr': 'Journal validé', 'en': 'Journal validated', 'ar': 'اليومية المصادق عليها'},
    'progressJournalPending': {'fr': 'dont {n} en attente', 'en': '{n} pending', 'ar': 'منها {n} معلقة'},
    'progressDeliverables': {'fr': 'Livrables validés', 'en': 'Deliverables validated', 'ar': 'المُخرَجات المصادق عليها'},
    'progressEvaluations': {'fr': 'Évaluations reçues', 'en': 'Evaluations received', 'ar': 'التقييمات المستلمة'},
    'progressEvaluationsCount': {'fr': '{n} évaluation(s)', 'en': '{n} evaluation(s)', 'ar': '{n} تقييم'},
    'progressOfTotal': {'fr': '{a} / {b}', 'en': '{a} / {b}', 'ar': '{a} / {b}'},
    'aiBadge': {'fr': 'Assistance IA', 'en': 'AI assistance', 'ar': 'مساعدة ذكية'},
    'aiAdvisoryNote': {'fr': 'Contenu généré par IA à titre indicatif : vérification humaine requise.', 'en': 'AI-generated content for guidance only: human review required.', 'ar': 'محتوى مولّد بالذكاء الاصطناعي للاسترشاد فقط: المراجعة البشرية مطلوبة.'},
    'aiCinExcluded': {'fr': 'Données sensibles (CIN) exclues', 'en': 'Sensitive data (CIN) excluded', 'ar': 'البيانات الحساسة (CIN) مستبعدة'},
    'logbookTitle': {'fr': 'Carnet de stage (brouillon IA)', 'en': 'Logbook (AI draft)', 'ar': 'دفتر التربص (مسودة ذكية)'},
    'logbookExplain': {'fr': 'Brouillon généré à partir de vos tâches, journal et livrables réels. Relisez et modifiez avant toute utilisation.', 'en': 'Draft generated from your actual tasks, journal and deliverables. Review and edit before any use.', 'ar': 'مسودة مولّدة من مهامك ويوميتك ومُخرَجاتك الفعلية. راجع وعدّل قبل أي استخدام.'},
    'logbookGenerate': {'fr': 'Générer le brouillon', 'en': 'Generate draft', 'ar': 'توليد المسودة'},
    'logbookRegenerate': {'fr': 'Régénérer', 'en': 'Regenerate', 'ar': 'إعادة التوليد'},
    'logbookEditHint': {'fr': 'Modifiez le brouillon ici avant utilisation.', 'en': 'Edit the draft here before use.', 'ar': 'عدّل المسودة هنا قبل الاستخدام.'},
    'logbookUnavailable': {'fr': 'Service IA indisponible pour le moment. Vos données et actions restent intactes.', 'en': 'AI service unavailable right now. Your data and actions are unaffected.', 'ar': 'خدمة الذكاء الاصطناعي غير متاحة حاليا. بياناتك وإجراءاتك سليمة.'},
    'logbookSuggestions': {'fr': 'Suggestions (indicatives)', 'en': 'Suggestions (advisory)', 'ar': 'اقتراحات (استرشادية)'},
    'logbookModel': {'fr': 'Modèle : {n}', 'en': 'Model: {n}', 'ar': 'النموذج: {n}'},
    'logbookSubmit': {'fr': 'Soumettre pour validation', 'en': 'Submit for validation', 'ar': 'إرسال للمصادقة'},
    'logbookSubmitSending': {'fr': 'Envoi en cours…', 'en': 'Submitting…', 'ar': 'جارٍ الإرسال…'},
    'logbookSubmittedOk': {'fr': 'Carnet soumis pour validation.', 'en': 'Logbook submitted for validation.', 'ar': 'تم إرسال الدفتر للمصادقة.'},
    'logbookSubmitEmpty': {'fr': 'Le carnet est vide : rien à soumettre.', 'en': 'The logbook is empty: nothing to submit.', 'ar': 'الدفتر فارغ: لا شيء لإرساله.'},
    'logbookSubmitFailed': {'fr': 'Échec de l’envoi : {e}', 'en': 'Failed to submit: {e}', 'ar': 'فشل الإرسال: {e}'},
    'logbookStatusSubmitted': {'fr': 'Soumis pour validation', 'en': 'Submitted for validation', 'ar': 'مُرسل للمصادقة'},
    'logbookStatusValidated': {'fr': 'Validé', 'en': 'Validated', 'ar': 'مُصادق عليه'},
    'logbookStatusRejected': {'fr': 'Renvoyé pour correction', 'en': 'Returned for correction', 'ar': 'أُعيد للتصحيح'},
    'logbookStatusOfficial': {'fr': 'Officiel', 'en': 'Official', 'ar': 'رسمي'},
    'logbookQueueTitle': {'fr': 'Carnets en attente', 'en': 'Logbooks awaiting review', 'ar': 'دفاتر في انتظار المراجعة'},
    'logbookNotSubmitted': {'fr': 'Aucun carnet soumis pour cet internat.', 'en': 'No logbook submitted for this internship.', 'ar': 'لم يُرسل أي دفتر لهذا التربص.'},
    'logbookReviewTitle': {'fr': 'Carnet de stage', 'en': 'Internship logbook', 'ar': 'دفتر التربص'},
    'logbookContentLabel': {'fr': 'Contenu soumis', 'en': 'Submitted content', 'ar': 'المحتوى المُرسل'},
    'logbookRejectReasonLabel': {'fr': 'Motif du renvoi', 'en': 'Reason for rejection', 'ar': 'سبب الإعادة'},
    'logbookRejectReasonHint': {'fr': 'Expliquez ce qu’il faut corriger (requis)', 'en': 'Explain what to correct (required)', 'ar': 'اشرح ما يجب تصحيحه (مطلوب)'},
    'logbookRejectReasonRequired': {'fr': 'Veuillez indiquer un motif.', 'en': 'Please provide a reason.', 'ar': 'يرجى تقديم سبب.'},
    'logbookValidatedOk': {'fr': 'Carnet validé.', 'en': 'Logbook validated.', 'ar': 'تمت المصادقة على الدفتر.'},
    'logbookRejectedOk': {'fr': 'Carnet renvoyé pour correction.', 'en': 'Logbook returned for correction.', 'ar': 'أُعيد الدفتر للتصحيح.'},
    'logbookSubmittedBanner': {'fr': 'Votre carnet a été soumis pour validation et est désormais en lecture seule.', 'en': 'Your logbook has been submitted for validation and is now read-only.', 'ar': 'أُرسل دفترك للمصادقة وأصبح للقراءة فقط.'},
    'logbookValidatedBanner': {'fr': 'Votre carnet a été validé par votre encadrant.', 'en': 'Your logbook has been validated by your supervisor.', 'ar': 'تمت المصادقة على دفترك من طرف مشرفك.'},
    'logbookOfficialBanner': {'fr': 'Votre carnet a été finalisé comme officiel.', 'en': 'Your logbook has been finalized as official.', 'ar': 'صُودق على دفترك نهائيا.'},
    'logbookRejectedBanner': {'fr': 'Votre carnet a été renvoyé : {r}', 'en': 'Your logbook was returned: {r}', 'ar': 'أُعيد دفترك: {r}'},
    'logbookResubmit': {'fr': 'Resoumettre pour validation', 'en': 'Resubmit for validation', 'ar': 'إعادة الإرسال للمصادقة'},
    'assistantTitle': {'fr': 'Assistant stagiaire', 'en': 'Intern assistant', 'ar': 'مساعد المتربص'},
    'assistantExplain': {'fr': 'Posez vos questions sur les procédures, l’organisation de vos tâches et la documentation. Réponses indicatives à partir de la base officielle.', 'en': 'Ask about procedures, task organisation and documentation. Advisory answers from the official base.', 'ar': 'اطرح أسئلتك حول الإجراءات وتنظيم مهامك والتوثيق. إجابات استرشادية من القاعدة الرسمية.'},
    'assistantPlaceholder': {'fr': 'Ex. Comment organiser mes tâches cette semaine ?', 'en': 'E.g. How should I organise my tasks this week?', 'ar': 'مثال: كيف أنظم مهامي هذا الأسبوع؟'},
    'assistantSend': {'fr': 'Envoyer', 'en': 'Send', 'ar': 'إرسال'},
    'assistantEmpty': {'fr': 'Aucun message pour le moment.', 'en': 'No messages yet.', 'ar': 'لا رسائل بعد.'},
    'assistantThinking': {'fr': 'Réflexion…', 'en': 'Thinking…', 'ar': 'جارٍ التفكير…'},
    'assistantUnavailable': {'fr': 'Assistant indisponible pour le moment. Réessayez plus tard.', 'en': 'Assistant unavailable right now. Try again later.', 'ar': 'المساعد غير متاح حاليا. حاول لاحقا.'},
    'assistantOffline': {'fr': 'L’assistant nécessite une connexion : votre texte est conservé.', 'en': 'The assistant needs connectivity — your text is kept.', 'ar': 'المساعد يحتاج إلى اتصال — تم الاحتفاظ بنصك.'},
    'assistantNoInternship': {'fr': 'Aucun stage actif trouvé pour l’assistant. Revenez quand votre stage aura commencé.', 'en': 'No active internship found for the assistant. Come back once your internship has started.', 'ar': 'لم يتم العثور على تربص نشط للمساعد. عُد عندما يبدأ تربصك.'},
    'assistantClearTitle': {'fr': 'Effacer la conversation ?', 'en': 'Clear the conversation?', 'ar': 'مسح المحادثة؟'},
    'assistantClearMessage': {'fr': 'L’historique local sera supprimé de cet appareil.', 'en': 'The local history will be removed from this device.', 'ar': 'سيُحذف السجل المحلي من هذا الجهاز.'},
    'assistantClearConfirm': {'fr': 'Effacer', 'en': 'Clear', 'ar': 'مسح'},
    'roleAdminSupervisor': {
      'fr': 'Encadrant (administrateur)',
      'en': 'Supervisor (administrator)',
      'ar': 'مؤطر (مسؤول)',
    },
    // --- Centralized user-facing error messages (T00 error model) ---
    'errGeneric': {
      'fr': 'Une erreur est survenue. Réessayez.',
      'en': 'Something went wrong. Please try again.',
      'ar': 'حدث خطأ. حاول مرة أخرى.',
    },
    'errNetwork': {
      'fr': 'Connexion requise. Vérifiez votre réseau puis réessayez.',
      'en': 'Connection required. Check your network and try again.',
      'ar': 'الاتصال مطلوب. تحقق من الشبكة ثم أعد المحاولة.',
    },
    'errSessionExpired': {
      'fr': 'Votre session a expiré. Reconnectez-vous.',
      'en': 'Your session has expired. Please sign in again.',
      'ar': 'انتهت جلستك. يرجى تسجيل الدخول من جديد.',
    },
    'errForbidden': {
      'fr': 'Vous n’avez pas la permission d’effectuer cette action.',
      'en': 'You do not have permission to perform this action.',
      'ar': 'ليس لديك إذن لتنفيذ هذا الإجراء.',
    },
    'errNotFound': {
      'fr': 'L’élément demandé est introuvable.',
      'en': 'The requested item was not found.',
      'ar': 'العنصر المطلوب غير موجود.',
    },
    'errConflict': {
      'fr': 'Cette action entre en conflit avec l’état actuel. Actualisez puis réessayez.',
      'en': 'This action conflicts with the current state. Refresh and try again.',
      'ar': 'يتعارض هذا الإجراء مع الحالة الحالية. حدّث البيانات ثم أعد المحاولة.',
    },
    'errValidation': {
      'fr': 'Certaines informations sont invalides. Vérifiez le formulaire.',
      'en': 'Some information is invalid. Please check the form.',
      'ar': 'بعض المعلومات غير صالحة. تحقق من النموذج.',
    },
    'errBadRequest': {
      'fr': 'La demande n’a pas pu être traitée. Réessayez.',
      'en': 'The request could not be processed. Please try again.',
      'ar': 'تعذرت معالجة الطلب. حاول مرة أخرى.',
    },
    // --- T07: message length contract (server `@Size(max=4000)`) ---
    'errMessageTooLong': {
      'fr': 'Message trop long (4000 caractères maximum). Raccourcissez-le puis réessayez.',
      'en': 'Message too long (4000 characters maximum). Shorten it and try again.',
      'ar': 'الرسالة طويلة جدا (4000 حرف كحد أقصى). اختصرها ثم أعد المحاولة.',
    },
    // --- T08 community guardrails (server codes, one sentence each) ---
    'errCommunityContactData': {
      'fr': 'Les adresses e-mail et numéros de téléphone sont interdits dans la communauté.',
      'en': 'Email addresses and phone numbers are not allowed in the community.',
      'ar': 'عناوين البريد الإلكتروني وأرقام الهواتف ممنوعة في المجتمع.',
    },
    'errCommunityDuplicate': {
      'fr': 'Vous avez déjà publié ce contenu récemment.',
      'en': 'You already posted this content recently.',
      'ar': 'لقد نشرت هذا المحتوى مؤخرا.',
    },
    'errCommunityMuted': {
      'fr': 'Votre accès à la communauté est temporairement coupé.',
      'en': 'Your community access is temporarily muted.',
      'ar': 'تم كتم وصولك إلى المجتمع مؤقتا.',
    },
    'errCommunityReportOpen': {
      'fr': 'Vous avez déjà signalé ce contenu.',
      'en': 'You already reported this content.',
      'ar': 'لقد أبلغت عن هذا المحتوى من قبل.',
    },
    'errCommunityTooLong': {
      'fr': 'Contenu trop long (2000 caractères maximum). Raccourcissez-le puis réessayez.',
      'en': 'Content too long (2000 characters maximum). Shorten it and try again.',
      'ar': 'المحتوى طويل جدا (2000 حرف كحد أقصى). اختصره ثم أعد المحاولة.',
    },
    'errServer': {
      'fr': 'Le service est temporairement indisponible. Réessayez dans un instant.',
      'en': 'The service is temporarily unavailable. Please try again shortly.',
      'ar': 'الخدمة غير متاحة مؤقتا. أعد المحاولة بعد قليل.',
    },
    'errRateLimited': {
      'fr': 'Trop de tentatives. Patientez un instant puis réessayez.',
      'en': 'Too many attempts. Please wait a moment and try again.',
      'ar': 'محاولات كثيرة. انتظر لحظة ثم أعد المحاولة.',
    },
    'errInvalidTransition': {
      'fr': 'Cette transition n’est pas autorisée dans l’état actuel.',
      'en': 'This transition is not allowed in the current state.',
      'ar': 'هذا الانتقال غير مسموح في الحالة الحالية.',
    },
    'errUploadRejected': {
      'fr': 'Le fichier a été refusé par la vérification de sécurité.',
      'en': 'The file was rejected by the security scan.',
      'ar': 'تم رفض الملف أثناء الفحص الأمني.',
    },
    'errAiUnavailable': {
      'fr': 'Le service IA est indisponible. Vous pouvez continuer manuellement.',
      'en': 'The AI service is unavailable. You can continue manually.',
      'ar': 'خدمة الذكاء الاصطناعي غير متاحة. يمكنك المتابعة يدويا.',
    },
    'errPasswordChangeRequired': {
      'fr': 'Vous devez changer votre mot de passe avant de continuer.',
      'en': 'You must change your password before continuing.',
      'ar': 'يجب تغيير كلمة المرور قبل المتابعة.',
    },
    'showPassword': {'fr': 'Afficher', 'en': 'Show', 'ar': 'إظهار'},
    'hidePassword': {'fr': 'Masquer', 'en': 'Hide', 'ar': 'إخفاء'},
    'prevWeek': {'fr': 'Semaine précédente', 'en': 'Previous week', 'ar': 'الأسبوع السابق'},
    'nextWeek': {'fr': 'Semaine suivante', 'en': 'Next week', 'ar': 'الأسبوع التالي'},
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
  String get logoutConfirmTitle => _get('logoutConfirmTitle');
  String get logoutConfirmMessage => _get('logoutConfirmMessage');
  String get profileTitle => _get('profileTitle');
  String get profileName => _get('profileName');
  String get profileEmail => _get('profileEmail');
  String get profileRole => _get('profileRole');
  String get profileInternship => _get('profileInternship');
  String get profileReadOnly => _get('profileReadOnly');
  String get profileChangePassword => _get('profileChangePassword');
  String get accountTitle => _get('accountTitle');
  String get appearanceTitle => _get('appearanceTitle');
  String get aboutTitle => _get('aboutTitle');
  String aboutVersion(String v) =>
      _get('aboutVersion').replaceAll('{v}', v);
  String get aboutLicenses => _get('aboutLicenses');
  String get aboutSupport => _get('aboutSupport');
  String get aboutSupportBody => _get('aboutSupportBody');
  String get aboutPrivacy => _get('aboutPrivacy');
  String get aboutPrivacyBody => _get('aboutPrivacyBody');
  String get notifyPrepareAsk => _get('notifyPrepareAsk');
  String notifySelected(int n) =>
      _get('notifySelected').replaceAll('{n}', '$n');
  String get notifyEmptyHint => _get('notifyEmptyHint');
  String notifySuccess(int n) =>
      _get('notifySuccess').replaceAll('{n}', '$n');
  String get notifyNeedsConnection => _get('notifyNeedsConnection');
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
  String homeGreetMorning(String name) =>
      _get('homeGreetMorning').replaceAll('{name}', name);
  String homeGreetAfternoon(String name) =>
      _get('homeGreetAfternoon').replaceAll('{name}', name);
  String homeGreetEvening(String name) =>
      _get('homeGreetEvening').replaceAll('{name}', name);
  String homeGreetNight(String name) =>
      _get('homeGreetNight').replaceAll('{name}', name);
  String get homeQuickActions => _get('homeQuickActions');
  String get qaTasks => _get('qaTasks');
  String get qaJournal => _get('qaJournal');
  String get qaAssistant => _get('qaAssistant');
  String get qaMessages => _get('qaMessages');
  String get qaValidations => _get('qaValidations');
  String get qaCalendar => _get('qaCalendar');
  String get tasksProgress => _get('tasksProgress');
  String get timelineProgress => _get('timelineProgress');
  String get viewAll => _get('viewAll');
  String get viewTimeline => _get('viewTimeline');
  String get noInternshipTitle => _get('noInternshipTitle');
  String get noInternshipHint => _get('noInternshipHint');
  String get staleData => _get('staleData');
  String get filterAll => _get('filterAll');
  String get filterDone => _get('filterDone');
  String get taskSubmitForReview => _get('taskSubmitForReview');
  String get taskReopen => _get('taskReopen');
  String get taskSetInProgress => _get('taskSetInProgress');
  String get noDueDate => _get('noDueDate');
  String moreItems(int n) => _get('moreItems').replaceAll('{n}', '$n');
  String get typeObservation => _get('typeObservation');
  String get typePerfectionnement => _get('typePerfectionnement');
  String get typePFE => _get('typePFE');
  String get stApproved => _get('stApproved');
  String get stInProgress => _get('stInProgress');
  String get stReportSubmitted => _get('stReportSubmitted');
  String get stUnderValidation => _get('stUnderValidation');
  String get stValidated => _get('stValidated');
  String get stReceiptIssued => _get('stReceiptIssued');
  String get stCancelled => _get('stCancelled');
  String get stArchived => _get('stArchived');
  String get tsTodo => _get('tsTodo');
  String get tsInProgress => _get('tsInProgress');
  String get tsAwaitingApproval => _get('tsAwaitingApproval');
  String get tsApproved => _get('tsApproved');
  String get tsDenied => _get('tsDenied');
  String get tsUnknown => _get('tsUnknown');
  String get tsCancelled => _get('tsCancelled');
  String get taskGroupAttention => _get('taskGroupAttention');
  String get taskGroupEmpty => _get('taskGroupEmpty');
  String get tasksEmptyHint => _get('tasksEmptyHint');
  String get taskNoMatch => _get('taskNoMatch');
  String get taskBackToProgress => _get('taskBackToProgress');
  String get taskDenialReason => _get('taskDenialReason');
  String get taskDeniedNoReason => _get('taskDeniedNoReason');
  String taskReviewedOn(String d) =>
      _get('taskReviewedOn').replaceAll('{d}', d);
  String get taskWaitingReview => _get('taskWaitingReview');
  String get taskSearchHint => _get('taskSearchHint');
  String get taskSearchClear => _get('taskSearchClear');
  String get taskViewBoard => _get('taskViewBoard');
  String get taskViewList => _get('taskViewList');
  String get taskNoEditSupervisorTask => _get('taskNoEditSupervisorTask');
  String get catOrganize => _get('catOrganize');
  String get catTitle => _get('catTitle');
  String get catNew => _get('catNew');
  String get catNameLabel => _get('catNameLabel');
  String get catNameHint => _get('catNameHint');
  String get catColorLabel => _get('catColorLabel');
  String get catNoColor => _get('catNoColor');
  String get catCreate => _get('catCreate');
  String get catSave => _get('catSave');
  String get catRename => _get('catRename');
  String get catMoveUp => _get('catMoveUp');
  String get catMoveDown => _get('catMoveDown');
  String get catDelete => _get('catDelete');
  String get catDeleteTitle => _get('catDeleteTitle');
  String catDeleteConfirm(String name) =>
      _get('catDeleteConfirm').replaceAll('{name}', name);
  String get catDeleteHint => _get('catDeleteHint');
  String get catEmpty => _get('catEmpty');
  String get catEmptyHint => _get('catEmptyHint');
  String get catUnclassified => _get('catUnclassified');
  String get catSuggest => _get('catSuggest');
  String get catSuggesting => _get('catSuggesting');
  String get catSuggestEmpty => _get('catSuggestEmpty');
  String get catNoCategoriesHint => _get('catNoCategoriesHint');
  String get catProposals => _get('catProposals');
  String get catProposalNote => _get('catProposalNote');
  String get catAccept => _get('catAccept');
  String get catAcceptAll => _get('catAcceptAll');
  String get catNewBadge => _get('catNewBadge');
  String get catUndo => _get('catUndo');
  String get catUndone => _get('catUndone');
  String catApplied(int n) =>
      _get('catApplied').replaceAll('{n}', '$n');
  String catApplySkipped(int n) =>
      _get('catApplySkipped').replaceAll('{n}', '$n');
  String get catAssigned => _get('catAssigned');
  String get catNeedsConnection => _get('catNeedsConnection');
  String get errCategoryInvalid => _get('errCategoryInvalid');
  String get errCategoryChanged => _get('errCategoryChanged');
  String get errCategoryNoCategories => _get('errCategoryNoCategories');
  String get supTasksTitle => _get('supTasksTitle');
  String get supNoStudents => _get('supNoStudents');
  String get supNoStudentsHint => _get('supNoStudentsHint');
  String get supTaskNew => _get('supTaskNew');
  String get supTaskEdit => _get('supTaskEdit');
  String get supTaskDelete => _get('supTaskDelete');
  String get supTaskDeleteTitle => _get('supTaskDeleteTitle');
  String supTaskDeleteConfirm(String title, String name) => _get('supTaskDeleteConfirm')
      .replaceAll('{title}', title)
      .replaceAll('{name}', name);
  String get supTaskCreated => _get('supTaskCreated');
  String get supTaskUpdated => _get('supTaskUpdated');
  String get supTaskDeleted => _get('supTaskDeleted');
  String get supReviewApprove => _get('supReviewApprove');
  String get supReviewDeny => _get('supReviewDeny');
  String get supReviewTitle => _get('supReviewTitle');
  String get supReviewApproved => _get('supReviewApproved');
  String get supReviewDenied => _get('supReviewDenied');
  String get supDenyReasonLabel => _get('supDenyReasonLabel');
  String get supDenyReasonHint => _get('supDenyReasonHint');
  String get supNeedsReview => _get('supNeedsReview');
  String get supScheduled => _get('supScheduled');
  String supAppearsOn(String d) =>
      _get('supAppearsOn').replaceAll('{d}', d);
  String get supScheduleLabel => _get('supScheduleLabel');
  String get supScheduleNone => _get('supScheduleNone');
  String get supSchedulePickDate => _get('supSchedulePickDate');
  String get supSchedulePickTime => _get('supSchedulePickTime');
  String get supScheduleClear => _get('supScheduleClear');
  String get supScheduleOutsideNote => _get('supScheduleOutsideNote');
  String get supBulkTitle => _get('supBulkTitle');
  String supBulkStudents(int n) =>
      _get('supBulkStudents').replaceAll('{n}', '$n');
  String supBulkPlan(int t, int s) => _get('supBulkPlan')
      .replaceAll('{t}', '$t')
      .replaceAll('{s}', '$s');
  String get supBulkSubmit => _get('supBulkSubmit');
  String supBulkDone(int n) =>
      _get('supBulkDone').replaceAll('{n}', '$n');
  String get supBulkAddTask => _get('supBulkAddTask');
  String get supBulkEmpty => _get('supBulkEmpty');
  String get supNeedsConnection => _get('supNeedsConnection');
  String get supManageTasks => _get('supManageTasks');
  String get supAddTaskFor => _get('supAddTaskFor');
  String get errReviewReason => _get('errReviewReason');
  String get errTaskNotCompleted => _get('errTaskNotCompleted');
  String get errScheduleOutsidePeriod => _get('errScheduleOutsidePeriod');
  String get errBulkInvalid => _get('errBulkInvalid');
  String get aiDraftTitle => _get('aiDraftTitle');
  String get aiDraftProposalNote => _get('aiDraftProposalNote');
  String get aiDraftAiNote => _get('aiDraftAiNote');
  String get aiDraftPdfTab => _get('aiDraftPdfTab');
  String get aiDraftTextTab => _get('aiDraftTextTab');
  String get aiDraftTextLabel => _get('aiDraftTextLabel');
  String get aiDraftTextHint => _get('aiDraftTextHint');
  String get aiDraftPickPdf => _get('aiDraftPickPdf');
  String get aiDraftChangePdf => _get('aiDraftChangePdf');
  String get aiDraftGenerate => _get('aiDraftGenerate');
  String get aiDraftGenerating => _get('aiDraftGenerating');
  String get aiDraftCancel => _get('aiDraftCancel');
  String get aiDraftEmpty => _get('aiDraftEmpty');
  String get aiDraftEmptyHint => _get('aiDraftEmptyHint');
  String get aiDraftManualAdd => _get('aiDraftManualAdd');
  String get aiDraftBadge => _get('aiDraftBadge');
  String get aiDraftEdit => _get('aiDraftEdit');
  String get aiDraftRevise => _get('aiDraftRevise');
  String get aiDraftReviseLabel => _get('aiDraftReviseLabel');
  String get aiDraftReviseHint => _get('aiDraftReviseHint');
  String get aiDraftDelete => _get('aiDraftDelete');
  String get aiDraftDeleteTitle => _get('aiDraftDeleteTitle');
  String get aiDraftTargets => _get('aiDraftTargets');
  String get aiDraftBulkAdd => _get('aiDraftBulkAdd');
  String aiDraftBulkDone(int n) =>
      _get('aiDraftBulkDone').replaceAll('{n}', '$n');
  String get aiDraftManualHint => _get('aiDraftManualHint');
  String get aiDraftNeedsConnection => _get('aiDraftNeedsConnection');
  String get aiDraftNoTargets => _get('aiDraftNoTargets');
  String get aiDraftNoDrafts => _get('aiDraftNoDrafts');
  String get errDraftInvalid => _get('errDraftInvalid');
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
  String journalTitleTooLong(int max) =>
      _get('journalTitleTooLong').replaceAll('{max}', '$max');
  String get journalSaveDraft => _get('journalSaveDraft');
  String get journalSubmitAction => _get('journalSubmitAction');
  String journalDraftSavedAt(String t) =>
      _get('journalDraftSavedAt').replaceAll('{t}', t);
  String get journalCalendar => _get('journalCalendar');
  String get journalPrevMonth => _get('journalPrevMonth');
  String get journalNextMonth => _get('journalNextMonth');
  String get journalCalendarShow => _get('journalCalendarShow');
  String get journalCalendarHide => _get('journalCalendarHide');
  String get journalInPeriod => _get('journalInPeriod');
  String get journalHasEntry => _get('journalHasEntry');
  String get journalAccent => _get('journalAccent');
  String get journalAccentHint => _get('journalAccentHint');
  String get journalNoEntriesThisDay => _get('journalNoEntriesThisDay');
  String get journalAddForDay => _get('journalAddForDay');
  String get journalWritePlaceholder => _get('journalWritePlaceholder');
  String get journalTitlePlaceholder => _get('journalTitlePlaceholder');
  String journalPeriodOverview(String d, String total) => _get('journalPeriodOverview')
      .replaceAll('{d}', d)
      .replaceAll('{total}', total);
  String get journalDraftKept => _get('journalDraftKept');
  String get journalCreated => _get('journalCreated');
  String get journalSubmittedOk => _get('journalSubmittedOk');
  String get journalSubmitFailKept => _get('journalSubmitFailKept');
  String get journalDetailTitle => _get('journalDetailTitle');
  String get journalComments => _get('journalComments');
  String get journalNoComments => _get('journalNoComments');
  String journalValidatedBy(String n) =>
      _get('journalValidatedBy').replaceAll('{n}', n);
  // --- T09/B5+B6: journal document (server window + AI PDF generation) ---
  String get journalGenTitle => _get('journalGenTitle');
  String get journalGenButton => _get('journalGenButton');
  String journalGenOpensIn(int days) =>
      _get('journalGenOpensIn').replaceAll('{days}', '$days');
  String get journalGenLate => _get('journalGenLate');
  String get journalGenNoPeriod => _get('journalGenNoPeriod');
  String get journalGenCancelled => _get('journalGenCancelled');
  String get journalGenOffline => _get('journalGenOffline');
  String get journalGenChooserHint => _get('journalGenChooserHint');
  String get journalGenFromTasks => _get('journalGenFromTasks');
  String get journalGenFromTasksHint => _get('journalGenFromTasksHint');
  String get journalGenFromText => _get('journalGenFromText');
  String get journalGenFromTextHint => _get('journalGenFromTextHint');
  String get journalGenTextLabel => _get('journalGenTextLabel');
  String get journalGenTextHint => _get('journalGenTextHint');
  String journalGenTextCounter(int used, int max) =>
      _get('journalGenTextCounter')
          .replaceAll('{used}', '$used')
          .replaceAll('{max}', '$max');
  String journalGenTextTooShort(int min) =>
      _get('journalGenTextTooShort').replaceAll('{min}', '$min');
  String get journalGenProgress => _get('journalGenProgress');
  String get journalGenStart => _get('journalGenStart');
  String journalGenBelowThreshold(int done, int total) =>
      _get('journalGenBelowThreshold')
          .replaceAll('{done}', '$done')
          .replaceAll('{total}', '$total');
  String get journalGenNoTasks => _get('journalGenNoTasks');
  String journalGenDone(int v) =>
      _get('journalGenDone').replaceAll('{v}', '$v');
  String get journalGenReplaced => _get('journalGenReplaced');
  String get journalGenPreviousSubmitted => _get('journalGenPreviousSubmitted');
  String get journalGenOpen => _get('journalGenOpen');
  String get journalGenOpenFailed => _get('journalGenOpenFailed');
  String get journalGenRegenerate => _get('journalGenRegenerate');
  String get journalGenRegenerateConfirm => _get('journalGenRegenerateConfirm');
  String get journalGenKeep => _get('journalGenKeep');
  String get journalGenKeepNote => _get('journalGenKeepNote');
  String get journalGenManualPath => _get('journalGenManualPath');
  String get journalGenCancel => _get('journalGenCancel');
  String get journalGenClose => _get('journalGenClose');
  String get journalGenSourceTasks => _get('journalGenSourceTasks');
  String get journalGenSourceText => _get('journalGenSourceText');
  String get errJournalNotEligible => _get('errJournalNotEligible');
  // --- T10 B7/B8/SU-VAL-01: submission window + document kind ---
  String get errSubmissionWindowClosed =>
      _get('errSubmissionWindowClosed');
  String submissionWindowOpens(String date) =>
      _get('submissionWindowOpens').replaceAll('{date}', date);
  String submissionWindowUntil(String date) =>
      _get('submissionWindowUntil').replaceAll('{date}', date);
  String submissionWindowLate(String date) =>
      _get('submissionWindowLate').replaceAll('{date}', date);
  String get submissionWindowNoPeriod => _get('submissionWindowNoPeriod');
  String get submissionWindowCancelled =>
      _get('submissionWindowCancelled');
  String get contactSupervisorAction => _get('contactSupervisorAction');
  String get contactNoConversation => _get('contactNoConversation');
  String get deliverableKindLabel => _get('deliverableKindLabel');
  String get deliverableKindNone => _get('deliverableKindNone');
  String get deliverableKindJournal => _get('deliverableKindJournal');
  String get deliverableKindReport => _get('deliverableKindReport');
  String get deliverableKindHint => _get('deliverableKindHint');
  String get errDeliverableKindLocked =>
      _get('errDeliverableKindLocked');
  String get errDocumentNotInConversation =>
      _get('errDocumentNotInConversation');
  String get msgDocMenu => _get('msgDocMenu');
  String get msgSetAsJournal => _get('msgSetAsJournal');
  String get msgSetAsReport => _get('msgSetAsReport');
  String msgDocRegistered(String kind) =>
      _get('msgDocRegistered').replaceAll('{kind}', kind);
  String get msgDocNotLinked => _get('msgDocNotLinked');
  String get errJournalTextInvalid => _get('errJournalTextInvalid');
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
  String get reviewFirstLevelNote => _get('reviewFirstLevelNote');
  String get rejectionDone => _get('rejectionDone');
  String get validationPending => _get('validationPending');
  String get unsavedTitle => _get('unsavedTitle');
  String get unsavedMessage => _get('unsavedMessage');
  String get discardAction => _get('discardAction');
  String get keepEditingAction => _get('keepEditingAction');
  String get cancelAction => _get('cancelAction');
  String get closeAction => _get('closeAction');

  // D3 deliverables
  String get deliverablesSubtitle => _get('deliverablesSubtitle');
  String get deliverableNew => _get('deliverableNew');
  String get deliverableTitleLabel => _get('deliverableTitleLabel');
  String get deliverableDescLabel => _get('deliverableDescLabel');
  String get deliverablePickFile => _get('deliverablePickFile');
  String get deliverableChangeFile => _get('deliverableChangeFile');
  String get deliverableNoFile => _get('deliverableNoFile');
  String get deliverableWrongType => _get('deliverableWrongType');
  String get deliverableTooLarge => _get('deliverableTooLarge');
  String get deliverableUpload => _get('deliverableUpload');
  String get deliverableUploaded => _get('deliverableUploaded');
  String get deliverableSubmitAction => _get('deliverableSubmitAction');
  String get deliverableSubmittedOk => _get('deliverableSubmittedOk');
  String get deliverableNewVersion => _get('deliverableNewVersion');
  String get deliverableChangeNote => _get('deliverableChangeNote');
  String get deliverableVersionUploaded =>
      _get('deliverableVersionUploaded');
  String get deliverableValidatedLocked =>
      _get('deliverableValidatedLocked');
  String get deliverableVersions => _get('deliverableVersions');
  String get deliverableDownload => _get('deliverableDownload');
  String get deliverableDownloading => _get('deliverableDownloading');
  String get deliverableChecklistTodo => _get('deliverableChecklistTodo');
  String get deliverableChecklistPending =>
      _get('deliverableChecklistPending');
  String get deliverableChecklistDone => _get('deliverableChecklistDone');
  String get deliverableChecklistEmpty =>
      _get('deliverableChecklistEmpty');
  String get deliverableReviewTitle => _get('deliverableReviewTitle');
  String get deliverableReviewsEmpty => _get('deliverableReviewsEmpty');
  String get uploadFailedRetry => _get('uploadFailedRetry');

  // D4 supervisor workspace & evaluations
  String get myInterns => _get('myInterns');
  String get noSupervised => _get('noSupervised');
  String get noSupervisedHint => _get('noSupervisedHint');
  String get supViewList => _get('supViewList');
  String get supViewCalendar => _get('supViewCalendar');
  String get supSearchHint => _get('supSearchHint');
  String get supSortName => _get('supSortName');
  String get supSortEndDate => _get('supSortEndDate');
  String get supSortStatus => _get('supSortStatus');
  String get supPrevMonth => _get('supPrevMonth');
  String get supNextMonth => _get('supNextMonth');
  String get supEmptyMonth => _get('supEmptyMonth');
  String get needsAttention => _get('needsAttention');
  String get allCaughtUp => _get('allCaughtUp');
  String get internDetailTitle => _get('internDetailTitle');
  String get evalPendingJournal => _get('evalPendingJournal');
  String get evalTasksSection => _get('evalTasksSection');
  String get evalDeliverablesSection => _get('evalDeliverablesSection');
  String get evalHistorySection => _get('evalHistorySection');
  String get evalNew => _get('evalNew');
  String get evalTemplate => _get('evalTemplate');
  String get evalTemplateHint => _get('evalTemplateHint');
  String get evalNoTemplate => _get('evalNoTemplate');
  String get evalType => _get('evalType');
  String get evalDate => _get('evalDate');
  String get evalTypeDaily => _get('evalTypeDaily');
  String get evalTypeWeekly => _get('evalTypeWeekly');
  String get evalTypeMid => _get('evalTypeMid');
  String get evalTypeFinal => _get('evalTypeFinal');
  String get evalTypeCustom => _get('evalTypeCustom');
  String evalScoreOf(String m) =>
      _get('evalScoreOf').replaceAll('{m}', m);
  String evalScoreInvalid(String m) =>
      _get('evalScoreInvalid').replaceAll('{m}', m);
  String get evalCriterionComment => _get('evalCriterionComment');
  String get evalTaskReviews => _get('evalTaskReviews');
  String get evalTaskReviewsHint => _get('evalTaskReviewsHint');
  String get evalIncludeTask => _get('evalIncludeTask');
  String get evalTaskDone => _get('evalTaskDone');
  String get evalTaskNotDone => _get('evalTaskNotDone');
  String get evalFeedback => _get('evalFeedback');
  String get evalFeedbackHint => _get('evalFeedbackHint');
  String evalEstimate(String n) =>
      _get('evalEstimate').replaceAll('{n}', n);
  String get evalEstimateNote => _get('evalEstimateNote');
  String get evalSubmit => _get('evalSubmit');
  String get evalConfirmTitle => _get('evalConfirmTitle');
  String get evalConfirmMessage => _get('evalConfirmMessage');
  String get evalSubmitted => _get('evalSubmitted');
  String evalOfficialTotal(String n) =>
      _get('evalOfficialTotal').replaceAll('{n}', n);
  String get evalScoresSection => _get('evalScoresSection');
  String get evalReviewsSection => _get('evalReviewsSection');
  String get evalNoScores => _get('evalNoScores');
  String get evalAdviceSection => _get('evalAdviceSection');
  String get myEvaluations => _get('myEvaluations');
  String get myEvaluationsEmpty => _get('myEvaluationsEmpty');
  String get evalOptionalScore => _get('evalOptionalScore');

  // D5 messaging & notifications
  String get convTitle => _get('convTitle');
  String get convEmpty => _get('convEmpty');
  String get convEmptyHint => _get('convEmptyHint');
  String get convPrivate => _get('convPrivate');
  String get convGroup => _get('convGroup');
  String get msgHint => _get('msgHint');
  String get msgSend => _get('msgSend');
  String get msgFailed => _get('msgFailed');
  String get msgRetry => _get('msgRetry');
  String get msgDiscard => _get('msgDiscard');
  String get offlineQueued => _get('offlineQueued');
  String get pendingLabel => _get('pendingLabel');
  String get queueFull => _get('queueFull');
  String get queueAuthDiscarded => _get('queueAuthDiscarded');
  String get msgDeleted => _get('msgDeleted');
  String get msgEdited => _get('msgEdited');
  String get msgDelivered => _get('msgDelivered');
  String get msgRead => _get('msgRead');
  String get msgSent => _get('msgSent');
  String get msgAttach => _get('msgAttach');
  String get msgAttachCaption => _get('msgAttachCaption');
  String get msgAttachTypes => _get('msgAttachTypes');
  String get msgAttachTooLarge => _get('msgAttachTooLarge');
  String get msgAttachWrongType => _get('msgAttachWrongType');
  String get msgDownload => _get('msgDownload');
  String get msgNoHistory => _get('msgNoHistory');
  String get msgSayHi => _get('msgSayHi');
  String get msgFromDocs => _get('msgFromDocs');
  String get msgPickDoc => _get('msgPickDoc');
  String get msgNoDocs => _get('msgNoDocs');
  String get msgDocTooLarge => _get('msgDocTooLarge');
  String get msgDocLoadFailed => _get('msgDocLoadFailed');
  String get msgToday => _get('msgToday');
  String get msgYesterday => _get('msgYesterday');
  String get msgEdit => _get('msgEdit');
  String get msgEditTitle => _get('msgEditTitle');
  String get msgDeleteTitle => _get('msgDeleteTitle');
  String get msgDeleteConfirm => _get('msgDeleteConfirm');
  String get msgSave => _get('msgSave');
  String get msgSeen => _get('msgSeen');
  String get msgMarkRead => _get('msgMarkRead');
  String get msgPickFailed => _get('msgPickFailed');
  String get msgActionFailed => _get('msgActionFailed');
  String get msgOnline => _get('msgOnline');
  String get msgOfflineShort => _get('msgOfflineShort');
  // --- T08 student community getters ---
  String get communityTitle => _get('communityTitle');
  String get communityEmpty => _get('communityEmpty');
  String get communityEmptyHint => _get('communityEmptyHint');
  String get communityComposerHint => _get('communityComposerHint');
  String get communityPublish => _get('communityPublish');
  String get communityAttach => _get('communityAttach');
  String get communityComments => _get('communityComments');
  String get communityNoComments => _get('communityNoComments');
  String get communityAddComment => _get('communityAddComment');
  String get communityReport => _get('communityReport');
  String get communityReportHint => _get('communityReportHint');
  String get communityReportSent => _get('communityReportSent');
  String get communityDelete => _get('communityDelete');
  String get communityDeleteConfirm => _get('communityDeleteConfirm');
  String get communityRemove => _get('communityRemove');
  String get communityRemoveReason => _get('communityRemoveReason');
  String get communityMute => _get('communityMute');
  String get communityMuteReason => _get('communityMuteReason');
  String get communityMuteDuration => _get('communityMuteDuration');
  String get communityMuteHour => _get('communityMuteHour');
  String get communityMuteDay => _get('communityMuteDay');
  String get communityMuteWeek => _get('communityMuteWeek');
  String get communityMuteMonth => _get('communityMuteMonth');
  String get communityUnmute => _get('communityUnmute');
  String get communityResolve => _get('communityResolve');
  String get communityResolution => _get('communityResolution');
  String get communityReports => _get('communityReports');
  String get communityOpenReports => _get('communityOpenReports');
  String get communityAllReports => _get('communityAllReports');
  String get communityNoReports => _get('communityNoReports');
  String get communityRemovedGone => _get('communityRemovedGone');
  String get communityNeedsConnection => _get('communityNeedsConnection');
  String get submitNeedsConnection => _get('submitNeedsConnection');
  String get uploadNeedsConnection => _get('uploadNeedsConnection');
  String get communityNewAvailable => _get('communityNewAvailable');
  String get sockConnecting => _get('sockConnecting');
  String get sockOffline => _get('sockOffline');
  String get sockLive => _get('sockLive');
  String get notifTitle => _get('notifTitle');
  // --- T01 notification catalogue (D11) ---
  String get notifTypeTaskAssigned => _get('notifTypeTaskAssigned');
  String get notifTypeTaskUpdated => _get('notifTypeTaskUpdated');
  String get notifTypeTaskDeleted => _get('notifTypeTaskDeleted');
  String get notifTypeTaskStatusChanged => _get('notifTypeTaskStatusChanged');
  String get notifTypeScheduledTaskVisible =>
      _get('notifTypeScheduledTaskVisible');
  String get notifTypeDocumentRejected => _get('notifTypeDocumentRejected');
  String get notifTypeDocumentVerified => _get('notifTypeDocumentVerified');
  String get notifTypeApplicationSubmitted =>
      _get('notifTypeApplicationSubmitted');
  String get notifTypeApplicationResubmitted =>
      _get('notifTypeApplicationResubmitted');
  String get notifTypeApplicationAccepted =>
      _get('notifTypeApplicationAccepted');
  String get notifTypeApplicationRejected =>
      _get('notifTypeApplicationRejected');
  String get notifTypeApplicationModification =>
      _get('notifTypeApplicationModification');
  String get notifTypeCandidateValidated =>
      _get('notifTypeCandidateValidated');
  String get notifTypeInternshipAssigned =>
      _get('notifTypeInternshipAssigned');
  String get notifTypeInternshipStatusChanged =>
      _get('notifTypeInternshipStatusChanged');
  String get notifTypeInternshipReportSubmitted =>
      _get('notifTypeInternshipReportSubmitted');
  String get notifTypeFinalEvaluationRequired =>
      _get('notifTypeFinalEvaluationRequired');
  String get notifTypeJournalValidated => _get('notifTypeJournalValidated');
  String get notifTypePaymentApproved => _get('notifTypePaymentApproved');
  String get notifTypeCertificateAvailable => _get('notifTypeCertificateAvailable');
  String get notifTypeMessageReceived => _get('notifTypeMessageReceived');
  String get notifTypeWelcome => _get('notifTypeWelcome');
  String get notifTypeCommunityComment => _get('notifTypeCommunityComment');
  String get notifTypeCommunityPostRemoved =>
      _get('notifTypeCommunityPostRemoved');
  String get notifTypeCommunityCommentRemoved =>
      _get('notifTypeCommunityCommentRemoved');
  String get notifTypeDocumentsPreparation =>
      _get('notifTypeDocumentsPreparation');
  String get notifTypeGeneric => _get('notifTypeGeneric');
  String get notifToday => _get('notifToday');
  String get notifWelcomeEmpty => _get('notifWelcomeEmpty');
  String get notifOfflineCached => _get('notifOfflineCached');
  String get notifUnavailable => _get('notifUnavailable');
  String get notifEmpty => _get('notifEmpty');
  String get notifUnreadOnly => _get('notifUnreadOnly');
  String get notifMarkRead => _get('notifMarkRead');
  String get notifMarkAllRead => _get('notifMarkAllRead');
  String get notifOpen => _get('notifOpen');

  // D6 progress + advisory logbook
  String get progressTitle => _get('progressTitle');
  String get progressTasks => _get('progressTasks');
  String get progressJournal => _get('progressJournal');
  String progressJournalPending(int n) =>
      _get('progressJournalPending').replaceAll('{n}', '$n');
  String get progressDeliverables => _get('progressDeliverables');
  String get progressEvaluations => _get('progressEvaluations');
  String progressEvaluationsCount(int n) =>
      _get('progressEvaluationsCount').replaceAll('{n}', '$n');
  String progressOf(int a, int b) => _get('progressOfTotal')
      .replaceAll('{a}', '$a')
      .replaceAll('{b}', '$b');
  String get aiBadge => _get('aiBadge');
  String get aiAdvisoryNote => _get('aiAdvisoryNote');
  String get aiCinExcluded => _get('aiCinExcluded');
  String get logbookTitle => _get('logbookTitle');
  String get logbookExplain => _get('logbookExplain');
  String get logbookGenerate => _get('logbookGenerate');
  String get logbookRegenerate => _get('logbookRegenerate');
  String get logbookEditHint => _get('logbookEditHint');
  String get logbookUnavailable => _get('logbookUnavailable');
  String get logbookSuggestions => _get('logbookSuggestions');
  String logbookModel(String n) =>
      _get('logbookModel').replaceAll('{n}', n);
  String get logbookSubmit => _get('logbookSubmit');
  String get logbookSubmitSending => _get('logbookSubmitSending');
  String get logbookSubmittedOk => _get('logbookSubmittedOk');
  String get logbookSubmitEmpty => _get('logbookSubmitEmpty');
  String logbookSubmitFailed(String e) =>
      _get('logbookSubmitFailed').replaceAll('{e}', e);
  String get logbookStatusSubmitted => _get('logbookStatusSubmitted');
  String get logbookStatusValidated => _get('logbookStatusValidated');
  String get logbookStatusRejected => _get('logbookStatusRejected');
  String get logbookStatusOfficial => _get('logbookStatusOfficial');
  String get logbookQueueTitle => _get('logbookQueueTitle');
  String get logbookNotSubmitted => _get('logbookNotSubmitted');
  String get logbookReviewTitle => _get('logbookReviewTitle');
  String get logbookContentLabel => _get('logbookContentLabel');
  String get logbookRejectReasonLabel => _get('logbookRejectReasonLabel');
  String get logbookRejectReasonHint => _get('logbookRejectReasonHint');
  String get logbookRejectReasonRequired =>
      _get('logbookRejectReasonRequired');
  String get logbookValidatedOk => _get('logbookValidatedOk');
  String get logbookRejectedOk => _get('logbookRejectedOk');
  String get logbookSubmittedBanner => _get('logbookSubmittedBanner');
  String get logbookValidatedBanner => _get('logbookValidatedBanner');
  String get logbookOfficialBanner => _get('logbookOfficialBanner');
  String logbookRejectedBanner(String r) =>
      _get('logbookRejectedBanner').replaceAll('{r}', r);
  String get logbookResubmit => _get('logbookResubmit');
  String get assistantTitle => _get('assistantTitle');
  String get assistantExplain => _get('assistantExplain');
  String get assistantPlaceholder => _get('assistantPlaceholder');
  String get assistantSend => _get('assistantSend');
  String get assistantEmpty => _get('assistantEmpty');
  String get assistantThinking => _get('assistantThinking');
  String get assistantUnavailable => _get('assistantUnavailable');
  String get assistantOffline => _get('assistantOffline');
  String get assistantNoInternship => _get('assistantNoInternship');
  String get assistantClearTitle => _get('assistantClearTitle');
  String get assistantClearMessage => _get('assistantClearMessage');
  String get assistantClearConfirm => _get('assistantClearConfirm');
  String get roleAdminSupervisor => _get('roleAdminSupervisor');
  // --- Centralized user-facing error messages (T00 error model) ---
  String get errGeneric => _get('errGeneric');
  String get errNetwork => _get('errNetwork');
  String get errSessionExpired => _get('errSessionExpired');
  String get errForbidden => _get('errForbidden');
  String get errNotFound => _get('errNotFound');
  String get errConflict => _get('errConflict');
  String get errValidation => _get('errValidation');
  String get errBadRequest => _get('errBadRequest');
  String get errMessageTooLong => _get('errMessageTooLong');
  String get errCommunityContactData => _get('errCommunityContactData');
  String get errCommunityDuplicate => _get('errCommunityDuplicate');
  String get errCommunityMuted => _get('errCommunityMuted');
  String get errCommunityReportOpen => _get('errCommunityReportOpen');
  String get errCommunityTooLong => _get('errCommunityTooLong');
  String get errServer => _get('errServer');
  String get errRateLimited => _get('errRateLimited');
  String get errInvalidTransition => _get('errInvalidTransition');
  String get errUploadRejected => _get('errUploadRejected');
  String get errAiUnavailable => _get('errAiUnavailable');
  String get errPasswordChangeRequired => _get('errPasswordChangeRequired');
  String get showPassword => _get('showPassword');
  String get hidePassword => _get('hidePassword');
  String get prevWeek => _get('prevWeek');
  String get nextWeek => _get('nextWeek');

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
