import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/domain/repositories/notification_repository.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/shell/presentation/auth_gate.dart';

import '../test_fixtures.dart';
import '../features/messaging/messaging_widget_test.dart'
    show FakeMessagingRepo, FakeStomp;

/// Authenticated test user fixtures
const kAcceptanceIntern = AppUser(
  id: 'intern-qa-1',
  email: 'intern.qa@steg.tn',
  roles: ['INTERN'],
  mustChangePassword: false,
);

const kAcceptanceInternNeedsPasswordChange = AppUser(
  id: 'intern-qa-fresh',
  email: 'fresh.intern@steg.tn',
  roles: ['INTERN'],
  mustChangePassword: true,
);

const kAcceptanceSupervisor = AppUser(
  id: 'supervisor-qa-1',
  email: 'supervisor.qa@steg.tn',
  roles: ['SUPERVISOR'],
  mustChangePassword: false,
);

/// Comprehensive Test Auth Repository for Acceptance testing
class AcceptanceAuthRepository implements AuthRepository {
  AcceptanceAuthRepository({AppUser? initialUser}) : _currentUser = initialUser;

  AppUser? _currentUser;
  int loginCalls = 0;
  int changePasswordCalls = 0;
  int logoutCalls = 0;
  String? lastChangedPassword;

  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> login({required String email, required String password}) async {
    loginCalls++;
    if (email.contains('fresh')) {
      _currentUser = kAcceptanceInternNeedsPasswordChange;
    } else if (email.contains('supervisor')) {
      _currentUser = kAcceptanceSupervisor;
    } else {
      _currentUser = kAcceptanceIntern;
    }
    return _currentUser!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    lastChangedPassword = newPassword;
    if (_currentUser != null) {
      _currentUser = AppUser(
        id: _currentUser!.id,
        email: _currentUser!.email,
        roles: _currentUser!.roles,
        mustChangePassword: false,
      );
    }
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    _currentUser = null;
  }

  @override
  Future<bool> refreshSession() async => _currentUser != null;

  @override
  Future<AppUser?> restoreSession() async => _currentUser;
}

/// Acceptance Notification Repository with controllable items list
class AcceptanceNotifRepo implements NotificationRepository {
  AcceptanceNotifRepo({List<NotificationItem>? initialItems})
      : items = initialItems ?? [];

  final List<NotificationItem> items;
  final List<String> readIds = [];
  bool readAllMarked = false;

  @override
  Future<Paged<NotificationItem>> list({
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) async {
    final filtered = unreadOnly ? items.where((i) => !i.isRead).toList() : items;
    return Paged<NotificationItem>(
      items: filtered,
      page: page,
      totalElements: filtered.length,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    final idx = items.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      final old = items[idx];
      items[idx] = NotificationItem(
        id: old.id,
        title: old.title,
        message: old.message,
        priority: old.priority,
        createdAt: old.createdAt,
        isRead: true,
        type: old.type,
        relatedEntityType: old.relatedEntityType,
        relatedEntityId: old.relatedEntityId,
      );
    }
  }

  @override
  Future<void> markAllRead() async {
    readAllMarked = true;
    for (int i = 0; i < items.length; i++) {
      final old = items[i];
      items[i] = NotificationItem(
        id: old.id,
        title: old.title,
        message: old.message,
        priority: old.priority,
        createdAt: old.createdAt,
        isRead: true,
        type: old.type,
        relatedEntityType: old.relatedEntityType,
        relatedEntityId: old.relatedEntityId,
      );
    }
  }

  @override
  Future<int> unreadCount() async => items.where((i) => !i.isRead).length;
}

/// Harness configuration for pumping an acceptance environment
class AcceptanceHarness {
  AcceptanceHarness({
    this.user,
    FakeInternshipRepository? internshipRepo,
    FakeMessagingRepo? messagingRepo,
    AcceptanceNotifRepo? notifRepo,
    FakeStomp? stomp,
    this.online = true,
  })  : authRepo = AcceptanceAuthRepository(initialUser: user),
        internshipRepo = internshipRepo ?? FakeInternshipRepository(),
        stomp = stomp ?? FakeStomp(),
        messagingRepo =
            messagingRepo ?? FakeMessagingRepo(stomp: stomp ?? FakeStomp()),
        notifRepo = notifRepo ?? AcceptanceNotifRepo();

  final AppUser? user;
  final AcceptanceAuthRepository authRepo;
  final FakeInternshipRepository internshipRepo;
  final FakeMessagingRepo messagingRepo;
  final AcceptanceNotifRepo notifRepo;
  final FakeStomp stomp;
  bool online;
}

/// Pump full acceptance app with AuthGate and all Riverpod wiring
Future<ProviderContainer> pumpAcceptanceApp(
  WidgetTester tester, {
  required AcceptanceHarness harness,
  Locale? locale,
  StegThemeMode themeMode = StegThemeMode.light,
  Map<String, Object> seedPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(seedPrefs);
  final prefs = await PrefsStore.load();

  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(harness.authRepo),
      isOnlineProvider.overrideWith((ref) => harness.online),
      internshipRepositoryProvider.overrideWithValue(harness.internshipRepo),
      messagingRepositoryProvider.overrideWithValue(harness.messagingRepo),
      notificationRepositoryProvider.overrideWithValue(harness.notifRepo),
      stompChatServiceProvider.overrideWithValue(harness.stomp),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final currentLocale = ref.watch(localeProvider);
          final currentThemeMode = ref.watch(themeModeProvider);

          return MaterialApp(
            locale: currentLocale,
            supportedLocales: StegLocales.supported,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: StegTheme.light(),
            darkTheme: StegTheme.dark(),
            themeMode: switch (currentThemeMode) {
              StegThemeMode.light => ThemeMode.light,
              StegThemeMode.dark => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            home: const AuthGate(),
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  return container;
}
