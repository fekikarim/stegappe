import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

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
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/dashboard.dart';
import 'package:stegappe/features/community/domain/entities/community.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/community/presentation/screens/community_feed_screen.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/assistant_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/deliverable_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/deliverables_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/evaluation_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/evaluation_form_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_home_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_composer_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_list_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/logbook_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/logbook_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/my_evaluations_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/progress_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervised_interns_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_calendar_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_home_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_tasks_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_validations_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/task_drafts_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/task_list_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/timeline_screen.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/chat_screen.dart';
import 'package:stegappe/features/messaging/presentation/screens/conversations_screen.dart';
import 'package:stegappe/features/messaging/presentation/screens/notifications_screen.dart';
import 'package:stegappe/features/shell/presentation/about_screen.dart';
import 'package:stegappe/features/shell/presentation/more_tab.dart';
import 'package:stegappe/features/shell/presentation/profile_screen.dart';

import '../support/queue_harness.dart';
import '../support/shell_harness.dart';
import '../test_fixtures.dart';
import '../features/community/community_test_support.dart';
import '../features/messaging/messaging_widget_test.dart'
    show FakeMessagingRepo, FakeNotifRepo, FakeStomp;

/// ── T15 evidence harness ─────────────────────────────────────────────────
///
/// One place that pumps any shipped screen under an arbitrary
/// locale / theme / text scale / connectivity state, so the accessibility,
/// RTL, text-scaling, offline and performance evidence all exercise the real
/// widgets with the real providers and the real fakes.
///
/// Nothing in here changes product behaviour; it is measurement only.

const kInternUser =
    AppUser(id: 'me', email: 'intern@steg.tn', roles: ['INTERN']);
const kSupervisorUser =
    AppUser(id: 'sup', email: 'supervisor@steg.tn', roles: ['SUPERVISOR']);

/// Role a screen is rendered for (drives which user the session holds).
enum UxRole { intern, supervisor }

/// The "long content" ceiling from `ux-ui.md` §2: an AI answer of ~2 000
/// characters, plus long AR/FR sentences used by the scaling probes.
const kLongAr =
    'متربص مجتهد جدا في قسم الأنظمة المعلوماتية والتحول الرقمي والتطوير المستمر للمنصة الذكية للتربصات والمتابعة اليومية';
const kLongFr =
    'Préparer une démonstration très détaillée du projet de digitalisation du suivi avec tous les écrans et tous les cas limites possibles et imaginables du parcours';
final kAiAnswer = List.filled(24, kLongFr).join(' ');

/// One screen from `ux-ui.md` §4, addressable by its documentation row.
class UxScreen {
  const UxScreen({
    required this.id,
    required this.name,
    required this.build,
    this.role = UxRole.intern,
    this.wide = false,
    this.tapTargetsRequired = true,
    this.scrollable = false,
  });

  /// `ux-ui.md` §4 row this widget belongs to.
  final String id;

  /// Human label used in the evidence matrix.
  final String name;

  /// Widget builder (const screens are built fresh per pump on purpose).
  final Widget Function() build;

  final UxRole role;

  /// Board/tablet-style screens need a wider surface.
  final bool wide;

  /// Whether the screen is expected to expose tappable targets (pure
  /// read-only pages legitimately have none).
  final bool tapTargetsRequired;

  /// True when the production container is a scroll view (the widget is
  /// always hosted in a sliver/list). Pumping it in a fixed-height Scaffold
  /// would report an overflow that a real device never shows.
  final bool scrollable;
}

List<SupervisedIntern> uxInterns(int count) => [
      for (var i = 0; i < count; i++)
        SupervisedIntern(
          internshipId: 'i$i',
          reference: 'STG-2026-${(i + 1).toString().padLeft(4, '0')}',
          internName: 'Métbribs ${i + 1}',
          status: InternshipStatus.inProgress,
          type: InternshipType.pfe,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          departmentName: 'DSI',
          tasksCompleted: i % 5,
          tasksTotal: 6,
          pendingJournal: i % 3,
          pendingDeliverables: 0,
          evaluationsCount: 0,
        ),
    ];

/// Extra internship repository that can serve arbitrary list sizes (the
/// 200-item performance probes) without touching the shared fixture.
class UxInternshipRepository extends FakeInternshipRepository {
  UxInternshipRepository({
    super.now,
    this.taskCount = 4,
    this.internCount = 3,
    this.deliverableCount = 3,
  });

  final int taskCount;
  final int internCount;
  final int deliverableCount;

  /// Per-endpoint call counters (T15 fan-out proof).
  final Map<String, int> calls = {};

  void _count(String endpoint) =>
      calls.update(endpoint, (v) => v + 1, ifAbsent: () => 1);

  @override
  Future<String?> resolveMyInternshipId() async {
    _count('resolveMyInternshipId');
    return super.resolveMyInternshipId();
  }

  @override
  Future<InternshipSummary> internshipSummary(String internshipId) async {
    _count('internshipSummary');
    return super.internshipSummary(internshipId);
  }

  @override
  Future<List<SupervisedIntern>> supervisedInterns() async {
    _count('supervisedInterns');
    return uxInterns(internCount);
  }

  @override
  Future<Paged<InternTask>> listTasks(
    String internshipId, {
    int page = 0,
    int size = 50,
    TaskStatus? status,
  }) async {
    _count('listTasks');
    final all = [
      for (var i = 0; i < taskCount; i++)
        InternTask(
          id: 't$i',
          title: 'Tâche numéro $i — un intitulé suffisamment long pour tester '
              'la mise en page',
          description: 'Description $i',
          status: TaskStatus.values[i % 6],
          dueDate: day(now, i % 21 - 7),
        ),
    ];
    final items =
        status == null ? all : all.where((t) => t.status == status).toList();
    return pageOf(items, total: items.length);
  }

  @override
  Future<Paged<DeliverableSummary>> listDeliverables(
    String internshipId, {
    int page = 0,
    int size = 50,
  }) async {
    _count('listDeliverables');
    final items = [
      for (var i = 0; i < deliverableCount; i++)
        DeliverableSummary(
          id: 'd$i',
          title: 'Rapport de stage définitif — version $i ($kLongFr)',
          status: DeliverableStatus.values[i % 4],
          currentVersion: i + 1,
        ),
    ];
    return pageOf(items, total: items.length);
  }

  @override
  Future<String> askAssistant(String question) async {
    _count('askAssistant');
    return kAiAnswer;
  }

  @override
  Future<Paged<AppNotification>> listNotifications(
      {int page = 0, int size = 20}) async {
    _count('listNotifications');
    return super.listNotifications(page: page, size: size);
  }

  @override
  Future<Paged<EvaluationSummary>> listEvaluations(
    String internshipId, {
    int page = 0,
    int size = 20,
  }) async {
    _count('listEvaluations');
    return super.listEvaluations(internshipId, page: page, size: size);
  }

  @override
  Future<Internship> getInternship(String id) async {
    _count('getInternship');
    return super.getInternship(id);
  }
}

/// Community repository serving a configurable feed size.
class UxCommunityRepository extends FakeCommunityRepository {
  UxCommunityRepository({this.postCount = 3});

  final int postCount;

  @override
  Future<CommunityFeedPage> feed(
      {DateTime? cursorTs, String? cursorId, int size = 20}) async {
    // The inherited counter is the one tests read.
    feedCalls++;
    final items = [
      for (var i = 0; i < postCount; i++)
        communityPost(
          'p$i',
          authorId: 'u$i',
          authorDisplayName: 'Étudiant ${i + 1}',
          body: 'Message communautaire numéro $i — un texte assez long pour '
              'éprouver le retour à la ligne dans les deux directions.',
          at: DateTime(2026, 9, 15, 10 - (i % 6)),
        ),
    ];
    return CommunityFeedPage(items: items, hasMore: false);
  }
}

/// Messaging repository whose history carries the longest realistic content
/// (a long Arabic/French mix plus a long filename attachment).
class UxMessagingRepository extends FakeMessagingRepo {
  UxMessagingRepository({super.stomp}) {
    convos = const [
      Conversation(
        id: 'c1',
        type: ConversationType.private,
        title: 'Superviseur Karim Feki — DSI/DSIT',
        unreadCount: 12,
      ),
    ];
  }

  @override
  Future<Paged<ChatMessage>> history(
    String conversationId, {
    int? cursor,
    int size = 30,
  }) async {
    if (failHistory) throw Exception('history failed');
    ChatMessage msg(int seq, {bool mine = false}) => ChatMessage(
          id: 'm$seq',
          conversationId: conversationId,
          senderId: mine ? 'me' : 'u2',
          content: '$kLongAr\n\n$kLongFr\n\n$kAiAnswer',
          status: MessageStatus.delivered,
          sequenceNumber: seq,
          sentAt: DateTime(2026, 9, 15, 10, seq),
          mine: mine,
        );
    return Paged(
      items: [msg(3, mine: true), msg(2), msg(1)],
      page: 0,
      totalElements: 3,
      totalPages: 1,
      isLast: true,
    );
  }
}

/// Internship repository that never answers (loading-state evidence).
class LoadingInternshipRepository extends UxInternshipRepository {
  @override
  Future<InternshipSummary> internshipSummary(String internshipId) =>
      Completer<InternshipSummary>().future;
}

/// Result of one pumped screen: container + fakes + the layout errors the
/// screen actually produced, for assertions and for the evidence report.
class UxPump {
  UxPump({
    required this.container,
    required this.internship,
    required this.community,
    required this.messaging,
    required this.stomp,
    required this.errors,
    this.scrollable = false,
  });

  /// Whether the screen was hosted in a scroll view (see [UxScreen.scrollable]).
  final bool scrollable;

  final ProviderContainer container;
  final UxInternshipRepository internship;
  final UxCommunityRepository community;
  final FakeMessagingRepo messaging;
  final FakeStomp stomp;

  /// Every error the framework reported while this screen was pumped.
  final List<FlutterErrorDetails> errors;

  /// Layout failures with the app source location that caused them — the
  /// measurable form of "no clipped text / no overflow" (a bare colour dump
  /// is not evidence).
  List<String> get layoutOffenders {
    final out = <String>[];
    for (final d in errors) {
      final message = d.exceptionAsString();
      if (!message.contains('overflowed by')) continue;
      final pixels = RegExp(r'overflowed by (\S+) pixels')
              .firstMatch(message)
              ?.group(1) ??
          '?';
      final direction = RegExp(r'on the (right|left|bottom|top)')
              .firstMatch(message)
              ?.group(1) ??
          '?';
      out.add('overflowed $pixels px $direction @ ${_appLocation(d) ?? '?'}');
    }
    return out.toSet().toList();
  }

  static String? _appLocation(FlutterErrorDetails d) {
    final pattern =
        RegExp(r'file:///\S*?/stegappe/lib/[^\s]*?\.dart:\d+:\d+');
    for (final text in describeError(d)) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        return m.group(0)!.replaceAll(RegExp(r'^file:///.*?/stegappe/'), '');
      }
    }
    return null;
  }
}

/// Full text of one reported error, including the widget/creation context the
/// framework attaches (which `FlutterErrorDetails.toString()` omits).
Iterable<String> describeError(FlutterErrorDetails d) sync* {
  yield d.exceptionAsString();
  yield d.toString();
  final ctx = d.context;
  if (ctx != null) yield ctx.toStringDeep();
  final collector = d.informationCollector;
  if (collector != null) {
    for (final node in collector()) {
      yield node.toStringDeep();
    }
  }
}

/// Pumps one screen with full provider overrides in a chosen UX state.
///
/// Defaults mirror the shipped app: French, light theme, 1.0× text, online,
/// a connected socket and a phone-sized surface.
Future<UxPump> pumpUx(
  WidgetTester tester,
  Widget page, {
  Locale locale = const Locale('fr'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool online = true,
  bool socketConnected = true,
  UxRole role = UxRole.intern,
  Size surface = const Size(400, 800),
  UxInternshipRepository? internship,
  UxCommunityRepository? community,
  FakeMessagingRepo? messaging,
  FakeNotifRepo? notifications,
  bool bootstrap = true,
  bool scrollable = false,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final repo = internship ?? UxInternshipRepository();
  final comm = community ?? UxCommunityRepository();
  final stomp = FakeStomp();
  if (socketConnected) stomp.setState(ChatConnectionState.connected);
  final msgs = messaging ?? FakeMessagingRepo(stomp: stomp);
  final user = role == UxRole.supervisor ? kSupervisorUser : kInternUser;
  final prefs = await PrefsStore.load();

  final collected = <FlutterErrorDetails>[];
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    collected.add(details);
    priorOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = priorOnError);

  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(HarnessAuthRepository(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        communityRepositoryProvider.overrideWithValue(comm),
        messagingRepositoryProvider.overrideWithValue(msgs),
        notificationRepositoryProvider
            .overrideWithValue(notifications ?? FakeNotifRepo()),
        stompChatServiceProvider.overrideWithValue(stomp),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: brightness == Brightness.light
            ? StegTheme.light()
            : StegTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: textScale >= 2,
          ),
          child: Scaffold(
            body: scrollable
                ? SingleChildScrollView(child: page)
                : page,
          ),
        ),
      ),
    ),
  );
  // Allow MaterialApp + localization delegates to complete their first build.
  await tester.pump();

  final ctx = tester.element(find.byType(Scaffold).first);
  final container = ProviderScope.containerOf(ctx);
  if (bootstrap) {
    await container.read(authControllerProvider.notifier).bootstrap();
  }
  await tester.pumpAndSettle();
  return UxPump(
    container: container,
    internship: repo,
    community: comm,
    messaging: msgs,
    stomp: stomp,
    errors: collected,
    scrollable: scrollable,
  );
}

/// The shipped screen inventory from `ux-ui.md` §4, wired to the real widgets.
///
/// Every row of the §4 tables appears here; widget-level rows that live inside
/// another screen's file (message bubble, intern card) are covered by
/// `test/long_strings_test.dart` and the feature suites instead of being
/// re-pumped as standalone screens.
List<UxScreen> uxScreens() => [
      // ── Student ────────────────────────────────────────────────────────
      UxScreen(
        id: 'ST-HOME',
        name: 'Intern home',
        build: () => const InternHomeScreen(user: kInternUser),
      ),
      UxScreen(
        id: 'ST-TASK',
        name: 'Task board',
        wide: true,
        build: () => const TaskListScreen(),
      ),
      UxScreen(
        id: 'ST-JRN-list',
        name: 'Journal list',
        build: () => const JournalListScreen(),
      ),
      UxScreen(
        id: 'ST-JRN-compose',
        name: 'Journal composer',
        build: () => JournalComposerScreen(
          internshipId: 'internship-1',
          day: DateTime(2026, 9, 15),
        ),
      ),
      UxScreen(
        id: 'ST-VAL-doc',
        name: 'Deliverables',
        build: () => const DeliverablesScreen(),
      ),
      UxScreen(
        id: 'ST-VAL-detail',
        name: 'Deliverable detail',
        build: () => const DeliverableDetailScreen(deliverableId: 'd0'),
      ),
      UxScreen(
        id: 'ST-PROG',
        name: 'Progress',
        build: () => const ProgressScreen(),
      ),
      UxScreen(
        id: 'ST-PROG-timeline',
        name: 'Timeline',
        build: () => const TimelineScreen(),
      ),
      UxScreen(
        id: 'ST-PROG-logbook',
        name: 'Logbook',
        build: () => const LogbookScreen(),
      ),
      UxScreen(
        id: 'ST-PROG-logbook-detail',
        name: 'Logbook detail',
        build: () => const LogbookDetailScreen(internshipId: 'internship-1'),
      ),
      UxScreen(
        id: 'ST-EVAL',
        name: 'My evaluations',
        build: () => const MyEvaluationsScreen(),
      ),
      UxScreen(
        id: 'ST-BOT',
        name: 'Assistant',
        build: () => const AssistantScreen(),
      ),
      UxScreen(
        id: 'ST-MSG-list',
        name: 'Conversations',
        build: () => const ConversationsScreen(),
      ),
      UxScreen(
        id: 'ST-MSG-chat',
        name: 'Chat',
        build: () => const ChatScreen(conversationId: 'c1', title: 'Karim Feki'),
      ),
      UxScreen(
        id: 'ST-NOT',
        name: 'Notifications',
        build: () => const NotificationsScreen(),
      ),
      UxScreen(
        id: 'ST-COM',
        name: 'Community feed',
        build: () => const CommunityFeedScreen(),
      ),
      UxScreen(
        id: 'SH-SET',
        name: 'Settings (More)',
        build: () => const MoreTab(),
      ),
      UxScreen(
        id: 'SH-PRO',
        name: 'Profile',
        build: () => const ProfileScreen(),
      ),
      UxScreen(
        id: 'SH-SET-about',
        name: 'About',
        build: () => const AboutScreen(),
      ),
      // ── Supervisor ─────────────────────────────────────────────────────
      UxScreen(
        id: 'SU-HOME',
        name: 'Supervisor home',
        role: UxRole.supervisor,
        build: () => const SupervisorHomeScreen(user: kSupervisorUser),
      ),
      UxScreen(
        id: 'W12',
        name: 'Interns list',
        role: UxRole.supervisor,
        build: () => const SupervisedInternsScreen(),
      ),
      UxScreen(
        id: 'SU-CAL',
        name: 'Calendar',
        role: UxRole.supervisor,
        // Hosted in a SliverToBoxAdapter by `SupervisedInternsScreen`.
        scrollable: true,
        build: () => SupervisorCalendar(interns: uxInterns(4)),
      ),
      UxScreen(
        id: 'SU-CAL-03',
        name: 'Intern detail',
        role: UxRole.supervisor,
        build: () => const InternDetailScreen(internshipId: 'i0'),
      ),
      UxScreen(
        id: 'W11',
        name: 'Validations',
        role: UxRole.supervisor,
        build: () => const SupervisorValidationsScreen(),
      ),
      UxScreen(
        id: 'SU-TASK',
        name: 'Task management',
        role: UxRole.supervisor,
        wide: true,
        build: () => const SupervisorTasksScreen(),
      ),
      UxScreen(
        id: 'SU-TASK-02',
        name: 'AI task generation',
        role: UxRole.supervisor,
        wide: true,
        build: () => const TaskDraftsScreen(referenceInternshipId: 'i0'),
      ),
      UxScreen(
        id: 'SU-EVAL',
        name: 'Evaluation form',
        role: UxRole.supervisor,
        build: () => const EvaluationFormScreen(internshipId: 'i0'),
      ),
      UxScreen(
        id: 'SU-EVAL-detail',
        name: 'Evaluation detail',
        role: UxRole.supervisor,
        build: () => const EvaluationDetailScreen(evaluationId: 'e1'),
      ),
    ];

/// ── Measurement helpers ─────────────────────────────────────────────────

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
///
/// Measured, not asserted from a table: the value is computed from the real
/// theme tokens so a token change moves the number and fails the gate.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Blends [fg] over [bg] using the theme's actual surface composition
/// (Flutter composites translucent colours; the measured ratio must too).
Color composite(Color fg, Color bg) => Color.alphaBlend(fg, bg);

/// All render objects that report a layout overflow during the current pump.
List<FlutterErrorDetails> drainOverflow(WidgetTester tester) {
  final errors = <FlutterErrorDetails>[];
  Object? ex = tester.takeException();
  while (ex != null) {
    if (ex is FlutterError) {
      errors.add(FlutterErrorDetails(exception: ex));
    }
    ex = tester.takeException();
  }
  return errors;
}

/// True when the rendered [Text] is painted inside its own box (no clipping).
bool textFits(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.hasSize && !box.size.isEmpty;
}

/// Nothing to assert; declared so tests can reference the fake's upload path.
Uint8List fakePdfBytes() => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
