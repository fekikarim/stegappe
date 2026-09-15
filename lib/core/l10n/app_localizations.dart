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
