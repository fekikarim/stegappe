import 'dart:async';
import 'dart:typed_data';

import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/internship/domain/dashboard.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/entities/logbook.dart';
import 'package:stegappe/features/internship/domain/entities/supervisor_tasks.dart';
import 'package:stegappe/features/internship/domain/entities/task_classification.dart';
import 'package:stegappe/features/internship/domain/entities/task_drafts.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/domain/repositories/internship_repository.dart';

DateTime day(DateTime base, int offset) {
  final d = base.add(Duration(days: offset));
  return DateTime(d.year, d.month, d.day);
}

Internship fixtureInternship(DateTime now) => Internship(
      id: 'internship-1',
      reference: 'STG-2026-0001',
      startDate: day(now, -10),
      endDate: day(now, 50),
      status: InternshipStatus.inProgress,
      type: InternshipType.perfectionnement,
      requirement: 'OBLIGATOIRE',
      paymentEligible: true,
      subject: 'Digitalisation du suivi des stagiaires',
      candidateFullName: 'Amira Ben Salah',
    );

List<InternTask> fixtureTasks(DateTime now) => [
      InternTask(
          id: 't-overdue', title: 'Overdue task', status: TaskStatus.todo, dueDate: day(now, -2)),
      InternTask(
          id: 't-today', title: 'Today task', status: TaskStatus.inProgress, dueDate: day(now, 0)),
      InternTask(
          id: 't-week', title: 'Week task', status: TaskStatus.todo, dueDate: day(now, 3)),
      InternTask(
          id: 't-done', title: 'Done task', status: TaskStatus.approved, dueDate: day(now, -5)),
    ];

List<JournalEntry> fixtureJournal(DateTime now) => [
      JournalEntry(
          id: 'j-draft', title: 'Draft entry', status: JournalStatus.draft, entryDate: day(now, 0)),
      JournalEntry(
          id: 'j-sub', title: 'Submitted entry', status: JournalStatus.submitted, entryDate: day(now, -1)),
      JournalEntry(
          id: 'j-val', title: 'Validated entry', status: JournalStatus.validated, entryDate: day(now, -2)),
    ];

DashboardData fixtureDashboard(DateTime now) => buildDashboard(
      DashboardInput(
        internship: fixtureInternship(now),
        assignments: [
          InternshipAssignment(
              id: 'a1',
              departmentName: 'DSI',
              supervisorName: 'Karim Feki',
              status: 'ACTIVE',
              startDate: day(now, -10),
              endDate: day(now, 50)),
        ],
        tasks: fixtureTasks(now),
        tasksCompletedTotal: 1,
        tasksGrandTotal: 4,
        journal: fixtureJournal(now),
        pendingJournalTotal: 1,
        journalValidatedTotal: 1,
        deliverables: const [
          DeliverableSummary(
              id: 'd1', title: 'Rapport', status: DeliverableStatus.submitted, currentVersion: 2),
        ],
        deliverablesTotal: 1,
        evaluations: [
          EvaluationSummary(
              id: 'e1', type: 'WEEKLY', evaluationDate: day(now, -7), totalScore: 15.5),
        ],
        notifications: [
          AppNotification(
              id: 'n1',
              title: 'Bienvenue',
              message: 'Bienvenue sur la plateforme',
              priority: 'NORMAL',
              createdAt: now,
              isRead: false),
        ],
        unreadNotifications: 1,
        unreadMessages: 2,
        now: now,
      ),
    );

Paged<T> pageOf<T>(List<T> items, {int total = -1}) => Paged<T>(
      items: items,
      page: 0,
      totalElements: total < 0 ? items.length : total,
      totalPages: 1,
      isLast: true,
    );

/// Fake repository for widget tests. Records write calls.
class FakeInternshipRepository implements InternshipRepository {
  FakeInternshipRepository({DateTime? now}) : now = now ?? DateTime.now();

  final DateTime now;
  TaskStatus? lastStatusFilter;
  final List<(String, TaskStatus)> statusUpdates = [];
  final List<String?> statusKeys = [];
  final List<(String, String?, String?)> decisions = [];
  final List<String> submitted = [];
  final List<Map<String, dynamic>> createdTasks = [];
  final List<Map<String, dynamic>> createdJournals = [];
  bool failWrites = false;
  bool noInternship = false;
  Completer<void>? statusGate;
  // T10: deliverable detail in DRAFT so the intern submit action renders.
  bool draftDetail = false;

  DashboardData get dashboard => fixtureDashboard(now);

  /// T13: per-section call counters proving the 13-call fan-out is gone
  /// (the dashboard must read through `internshipSummary` only).
  final Map<String, int> sectionCalls = {};

  void _count(String section) =>
      sectionCalls.update(section, (v) => v + 1, ifAbsent: () => 1);

  @override
  Future<String?> resolveMyInternshipId() async =>
      noInternship ? null : 'internship-1';

  @override
  Future<Internship> getInternship(String id) async {
    _count('internship');
    return fixtureInternship(now);
  }

  /// T13: one-call home snapshot assembled from the same fixture pieces
  /// the section lists use, so home rows are byte-identical to list rows.
  int summaryCalls = 0;

  @override
  Future<InternshipSummary> internshipSummary(String internshipId) async {
    summaryCalls++;
    final d = dashboard;
    return InternshipSummary(
      internship: d.internship,
      assignments: d.assignments,
      tasks: fixtureTasks(now),
      tasksCompletedTotal: 1,
      tasksGrandTotal: 4,
      journal: fixtureJournal(now),
      pendingJournalTotal: 1,
      journalValidatedTotal: 1,
      deliverables: const [
        DeliverableSummary(
            id: 'd1',
            title: 'Rapport',
            status: DeliverableStatus.submitted,
            currentVersion: 2),
      ],
      deliverablesTotal: 1,
      evaluations: [
        if (d.latestEvaluation != null) d.latestEvaluation!,
      ],
      notifications: d.recentNotifications,
    );
  }

  @override
  Future<List<InternshipAssignment>> getAssignments(String id) async {
    _count('assignments');
    return dashboard.assignments;
  }

  @override
  Future<Paged<InternTask>> listTasks(String internshipId,
      {int page = 0, int size = 50, TaskStatus? status}) async {
    _count('tasks');
    lastStatusFilter = status;
    final all = fixtureTasks(now);
    final items =
        status == null ? all : all.where((t) => t.status == status).toList();
    return pageOf(items, total: items.length);
  }

  @override
  Future<InternTask> updateTaskStatus(
      String taskId, TaskStatus status,
      {String? idempotencyKey}) async {
    final gate = statusGate;
    if (gate != null) await gate.future;
    if (failWrites) {
      throw Exception('offline');
    }
    statusUpdates.add((taskId, status));
    statusKeys.add(idempotencyKey);
    final existing = fixtureTasks(now).where((e) => e.id == taskId);
    final t = existing.isEmpty
        ? InternTask(id: taskId, title: taskId, status: status)
        : existing.first;
    return InternTask(
        id: t.id,
        title: t.title,
        status: status,
        dueDate: t.dueDate,
        description: t.description);
  }

  // --- T09 journal document (B5 window + B6 AI generation) ---

  /// Server-shaped eligibility the tests override per scenario (window states,
  /// warning thresholds). Default: eligible, everything approved.
  JournalEligibility journalEligibilityFixture = const JournalEligibility(
    eligible: true,
    reason: 'ELIGIBLE_WINDOW',
    daysUntilOpen: 0,
    windowDays: 30,
    taskCount: 4,
    approvedTasks: 4,
    belowThreshold: false,
  );

  /// Failures the fake must raise on the eligibility read / generation.
  Object? eligibilityError;
  Object? journalGenerationError;

  /// Held-open generation (progress + cancel tests).
  Completer<void>? journalGate;

  /// `TASKS`, or `TEXT:<text>` for the text path.
  final List<String> journalGenerations = [];
  int eligibilityCalls = 0;
  int journalRegenerations = 0;

  /// What the next generation returns (null → a default DRAFT result).
  JournalGenerationResult? journalResult;

  @override
  Future<JournalEligibility> journalEligibility(String internshipId) async {
    eligibilityCalls++;
    final failure = eligibilityError;
    if (failure != null) throw failure;
    return journalEligibilityFixture;
  }

  @override
  Future<JournalGenerationResult> generateJournalFromTasks(
      String internshipId) async {
    final gate = journalGate;
    if (gate != null) await gate.future;
    final failure = journalGenerationError;
    if (failure != null) throw failure;
    journalGenerations.add('TASKS');
    return journalResult ?? _defaultJournalResult('TASKS');
  }

  @override
  Future<JournalGenerationResult> generateJournalFromText(
      String internshipId, String text) async {
    final gate = journalGate;
    if (gate != null) await gate.future;
    final failure = journalGenerationError;
    if (failure != null) throw failure;
    journalGenerations.add('TEXT:$text');
    return journalResult ?? _defaultJournalResult('TEXT');
  }

  JournalGenerationResult _defaultJournalResult(String source) =>
      JournalGenerationResult(
        deliverableId: 'del-journal',
        title: 'Journal de stage — INT-2026-00001',
        status: DeliverableStatus.draft,
        currentVersion: 1,
        fileName: 'journal-de-stage-INT-2026-00001.pdf',
        source: source,
        taskCount: 4,
        approvedTasks: 4,
        belowThreshold: false,
        replacedDraft: false,
        previousSubmitted: false,
      );

  @override
  Future<Paged<JournalEntry>> listJournal(String internshipId,
      {int page = 0,
      int size = 20,
      JournalStatus? status,
      DateTime? day}) async {
    _count('journal');
    var all = fixtureJournal(now);
    if (status != null) {
      all = all.where((j) => j.status == status).toList();
    }
    if (day != null) {
      all = all
          .where((j) =>
              j.entryDate.year == day.year &&
              j.entryDate.month == day.month &&
              j.entryDate.day == day.day)
          .toList();
    }
    return pageOf(all, total: all.length);
  }

  @override
  Future<InternTask> createTask(String internshipId,
      {required String title,
      String? description,
      DateTime? dueDate,
      DateTime? visibleFrom}) async {
    if (failWrites) throw Exception('offline');
    createdTasks.add({
      'title': title,
      'description': description,
      'dueDate': dueDate,
      'visibleFrom': visibleFrom,
      'internshipId': internshipId,
    });
    return InternTask(
        id: 't-new',
        title: title,
        status: TaskStatus.todo,
        dueDate: dueDate,
        description: description,
        visibleFrom: visibleFrom);
  }

  @override
  Future<InternTask> updateTask(String taskId,
      {required String title,
      String? description,
      DateTime? dueDate,
      TaskStatus? status,
      DateTime? visibleFrom}) async {
    if (failWrites) throw Exception('offline');
    updatedTasks.add({
      'taskId': taskId,
      'title': title,
      'visibleFrom': visibleFrom,
    });
    return InternTask(
        id: taskId,
        title: title,
        status: status ?? TaskStatus.todo,
        dueDate: dueDate,
        description: description,
        visibleFrom: visibleFrom);
  }

  @override
  Future<JournalEntry> createJournal(String internshipId,
      {required String title,
      required String description,
      required DateTime entryDate}) async {
    if (failWrites) throw Exception('offline');
    createdJournals.add(
        {'title': title, 'description': description, 'entryDate': entryDate});
    return JournalEntry(
        id: 'j-new',
        title: title,
        description: description,
        status: JournalStatus.draft,
        entryDate: entryDate);
  }

  @override
  Future<JournalEntry> submitJournal(String entryId) async {
    if (failWrites) throw Exception('offline');
    submitted.add(entryId);
    final j = fixtureJournal(now).firstWhere((e) => e.id == entryId,
        orElse: () => JournalEntry(
            id: entryId,
            title: 'x',
            status: JournalStatus.draft,
            entryDate: now));
    return JournalEntry(
        id: j.id,
        title: j.title,
        description: j.description,
        status: JournalStatus.submitted,
        entryDate: j.entryDate);
  }

  @override
  Future<List<JournalComment>> journalComments(String entryId) async =>
      [
        JournalComment(
            id: 'c1',
            content: 'Bien détaillé, continue.',
            authorEmail: 'sup@steg.tn',
            createdAt: now),
      ];

  @override
  Future<JournalEntry> validateJournal(
      String entryId, String? comment) async {
    if (failWrites) throw Exception('offline');
    decisions.add((entryId, 'VALIDATED', comment));
    return JournalEntry(
        id: 'j-sub',
        title: 'Submitted entry',
        status: JournalStatus.validated,
        entryDate: now);
  }

  @override
  Future<JournalEntry> rejectJournal(String entryId, String? comment) async {
    if (failWrites) throw Exception('offline');
    decisions.add((entryId, 'REJECTED', comment));
    return JournalEntry(
        id: 'j-sub',
        title: 'Submitted entry',
        status: JournalStatus.rejected,
        entryDate: now);
  }

  @override
  Future<List<String>> supervisedInternshipIds() async =>
      (await supervisedInterns()).map((s) => s.internshipId).toList();

  @override
  Future<Paged<DeliverableSummary>> listDeliverables(String internshipId,
          {int page = 0, int size = 20}) async {
    _count('deliverables');
    return pageOf(const [
        DeliverableSummary(
            id: 'd-draft',
            title: 'Brouillon rapport',
            status: DeliverableStatus.draft,
            currentVersion: 1),
        DeliverableSummary(
            id: 'd-sub',
            title: 'Rapport de stage',
            status: DeliverableStatus.submitted,
            currentVersion: 2),
        DeliverableSummary(
            id: 'd-val',
            title: 'Présentation finale',
            status: DeliverableStatus.validated,
            currentVersion: 3),
      ]);
  }

  @override
  Future<Paged<EvaluationSummary>> listEvaluations(String internshipId,
          {int page = 0, int size = 20}) async {
    _count('evaluations');
    return pageOf([
      if (dashboard.latestEvaluation != null)
        dashboard.latestEvaluation!,
    ]);
  }

  @override
  Future<Paged<AppNotification>> listNotifications(
          {int page = 0, int size = 20}) async {
    _count('notifications');
    return pageOf(dashboard.recentNotifications,
          total: dashboard.unreadNotifications);
  }

  @override
  Future<int> unreadNotificationCount() async =>
      dashboard.unreadNotifications;

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<int> unreadMessageCount() async => dashboard.unreadMessages;

  /// T14/D14: the accepted count mirrors the request (one notification per
  /// covered internship), so a controller that sends the wrong set cannot
  /// pass on a hard-coded mock value. Fails when [failWrites] is set, like
  /// every other write fake.
  int notifyCalls = 0;
  final List<String?> notifyKeys = [];
  final List<List<String>> notifyIds = [];
  Object? notifyError;

  @override
  Future<int> notifyDocumentsPreparation(List<String> internshipIds,
      {String? idempotencyKey}) async {
    // A dispatched request records its key/targets even when the transport
    // rejects it: that is exactly the case where the server may already
    // have stored a receipt and the client must retry with the same key.
    notifyKeys.add(idempotencyKey);
    notifyIds.add(List.of(internshipIds));
    final failure = notifyError;
    if (failure != null) throw failure;
    if (failWrites) throw Exception('offline');
    notifyCalls++;
    return internshipIds.length;
  }

  /// T14: locale sync is fire-and-forget in the UI; the fake accepts it.
  int localeSyncCalls = 0;
  String? lastLocaleSynced;
  bool failLocaleSync = false;

  @override
  Future<void> syncLocale(String code) async {
    if (failLocaleSync) throw Exception('locale sync failed');
    localeSyncCalls++;
    lastLocaleSynced = code;
  }

  // --- D3 deliverables ---

  final List<Map<String, dynamic>> createdDeliverables = [];
  final List<Map<String, dynamic>> newVersions = [];
  final List<String> submittedDeliverables = [];
  final List<(String, String?, String?)> deliverableDecisions = [];
  final List<(String, int)> downloads = [];

  // --- T10 B7/B8/SU-VAL-01: submission window + document kind ---

  /// Server-shaped window the tests override per scenario (open, before,
  /// late, cancelled). Default: open (existing flows keep working).
  SubmissionWindow submissionWindowFixture = const SubmissionWindow(
      open: true, reason: 'OPEN', daysUntilOpen: 0, windowDays: 7);

  /// Kind returned by [getDeliverable] (null = free document).
  String? documentKindFixture;

  /// `(deliverableId, kind)` pairs registered through the fake.
  final List<(String, String)> registeredKinds = [];

  /// Set to make [submissionWindow] fail (window read error UX).
  Object? submissionWindowError;

  @override
  Future<SubmissionWindow> submissionWindow(String internshipId) async {
    final error = submissionWindowError;
    if (error != null) throw error;
    return submissionWindowFixture;
  }

  @override
  Future<DeliverableDetail> registerDocumentKind(
      String deliverableId, String documentKind) async {
    if (failWrites) throw Exception('offline');
    registeredKinds.add((deliverableId, documentKind));
    documentKindFixture = documentKind;
    return fixtureDetail();
  }

  DeliverableDetail fixtureDetail() => DeliverableDetail(
        id: 'd-sub',
        title: 'Rapport de stage',
        description: 'Version revue',
        status: DeliverableStatus.submitted,
        currentVersion: 2,
        versions: [
          DeliverableVersionInfo(
              id: 'v2',
              versionNumber: 2,
              fileName: 'rapport-v2.pdf',
              mimeType: 'application/pdf',
              size: 120000,
              uploadedByEmail: 'intern@u.tn',
              changeSummary: 'Corrections',
              uploadedAt: now),
          DeliverableVersionInfo(
              id: 'v1',
              versionNumber: 1,
              fileName: 'rapport-v1.pdf',
              mimeType: 'application/pdf',
              size: 100000,
              uploadedByEmail: 'intern@u.tn',
              uploadedAt: now),
        ],
      );

  @override
  Future<DeliverableDetail> createDeliverable(String internshipId,
      {required String title,
      String? description,
      String? documentKind,
      required String fileName,
      required Uint8List fileBytes,
      void Function(int sent, int total)? onProgress}) async {
    if (failWrites) throw Exception('offline');
    createdDeliverables.add({
      'title': title,
      'fileName': fileName,
      'internshipId': internshipId,
      'documentKind': documentKind,
    });
    onProgress?.call(fileBytes.length, fileBytes.length);
    return DeliverableDetail(
        id: 'd-new',
        title: title,
        description: description,
        status: DeliverableStatus.draft,
        currentVersion: 1,
        internshipId: internshipId,
        documentKind: documentKind);
  }

  @override
  Future<DeliverableDetail> uploadNewVersion(String deliverableId,
      {required String fileName,
      required Uint8List fileBytes,
      String? changeSummary,
      void Function(int sent, int total)? onProgress}) async {
    if (failWrites) throw Exception('offline');
    newVersions.add(
        {'id': deliverableId, 'fileName': fileName, 'note': changeSummary});
    onProgress?.call(fileBytes.length, fileBytes.length);
    return fixtureDetail();
  }

  @override
  Future<DeliverableDetail> getDeliverable(String deliverableId) async {
    final d = fixtureDetail();
    // Models the server truth: a submitted deliverable reads back SUBMITTED
    // (which hides the submit action), otherwise the T10 draft flag decides.
    final isSubmitted =
        submittedDeliverables.contains(deliverableId) || !draftDetail;
    return DeliverableDetail(
      id: d.id,
      title: d.title,
      description: d.description,
      status: isSubmitted ? DeliverableStatus.submitted : DeliverableStatus.draft,
      currentVersion: d.currentVersion,
      internshipId: 'internship-1',
      documentKind: documentKindFixture,
      versions: d.versions,
    );
  }

  @override
  Future<List<DeliverableVersionInfo>> deliverableVersions(
          String deliverableId) async =>
      fixtureDetail().versions;

  @override
  Future<DeliverableDetail> submitDeliverable(String deliverableId) async {
    if (failWrites) throw Exception('offline');
    submittedDeliverables.add(deliverableId);
    return fixtureDetail();
  }

  @override
  Future<DeliverableDetail> validateDeliverable(
      String deliverableId, String? comment) async {
    if (failWrites) throw Exception('offline');
    deliverableDecisions.add((deliverableId, 'VALIDATED', comment));
    return fixtureDetail();
  }

  @override
  Future<DeliverableDetail> rejectDeliverable(
      String deliverableId, String? comment) async {
    if (failWrites) throw Exception('offline');
    deliverableDecisions.add((deliverableId, 'REJECTED', comment));
    return fixtureDetail();
  }

  @override
  Future<Uint8List> downloadDeliverable(String deliverableId,
      {int? version}) async {
    if (failWrites) throw Exception('offline');
    downloads.add((deliverableId, version ?? -1));
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
  }

  @override
  Future<List<JournalComment>> deliverableComments(
          String deliverableId) async =>
      [
        JournalComment(
            id: 'c9',
            content: 'Bon travail.',
            authorEmail: 'sup@steg.tn',
            createdAt: now),
      ];

  @override
  Future<List<PendingDeliverableReview>> pendingDeliverableReviews() async =>
      [
        PendingDeliverableReview(
            internshipId: 'internship-1',
            internshipReference: 'STG-2026-0001',
            deliverable: const DeliverableSummary(
                id: 'd-sub',
                title: 'Rapport de stage',
                status: DeliverableStatus.submitted,
                currentVersion: 2)),
      ];

  // --- D4 evaluations ---

  final List<Map<String, dynamic>> createdEvaluations = [];
  final List<Map<String, dynamic>> submittedScores = [];
  final List<Map<String, dynamic>> taskReviewCalls = [];

  List<EvaluationCriterion> fixtureCriteria() => const [
        EvaluationCriterion(
            id: 'c-tech',
            templateId: 't1',
            name: 'Technique',
            weight: 60,
            maxScore: 20),
        EvaluationCriterion(
            id: 'c-soft',
            templateId: 't1',
            name: 'Comportement',
            weight: 40,
            maxScore: 20),
      ];

  @override
  Future<List<EvaluationTemplate>> listTemplates(
          {bool activeOnly = true}) async =>
      const [
        EvaluationTemplate(
            id: 't1', name: 'Standard', active: true),
      ];

  @override
  Future<List<EvaluationCriterion>> templateCriteria(
          String templateId) async =>
      fixtureCriteria();

  @override
  Future<EvaluationSummary> createEvaluation(String internshipId,
      {String? templateId,
      required EvaluationKind kind,
      required DateTime date,
      String? feedback}) async {
    if (failWrites) throw Exception('offline');
    createdEvaluations.add({'templateId': templateId, 'feedback': feedback});
    return EvaluationSummary(
        id: 'e-new',
        type: evaluationKindToApi(kind),
        evaluationDate: date,
        feedback: feedback);
  }

  @override
  Future<void> submitScores(String evaluationId,
      List<Map<String, dynamic>> scores) async {
    if (failWrites) throw Exception('offline');
    submittedScores.addAll(scores);
  }

  @override
  Future<void> addTaskReview(
      String evaluationId, Map<String, dynamic> review) async {
    if (failWrites) throw Exception('offline');
    taskReviewCalls.add(review);
  }

  @override
  Future<EvaluationSummary> evaluationDetail(String evaluationId) async =>
      EvaluationSummary(
          id: evaluationId,
          type: 'WEEKLY',
          evaluationDate: now,
          totalScore: 15.0,
          feedback: 'Bon travail.');

  @override
  Future<List<EvaluationScore>> evaluationScores(
          String evaluationId) async =>
      const [
        EvaluationScore(
            criterionId: 'c-tech',
            criterionName: 'Technique',
            score: 15,
            maxScore: 20,
            weight: 60),
        EvaluationScore(
            criterionId: 'c-soft',
            criterionName: 'Comportement',
            score: 15,
            maxScore: 20,
            weight: 40),
      ];

  @override
  Future<List<EvaluationTaskReview>> evaluationTaskReviews(
          String evaluationId) async =>
      const [
        EvaluationTaskReview(
            taskId: 't-done',
            taskTitle: 'Done task',
            completed: true,
            score: 16),
      ];

  @override
  Future<List<JournalComment>> evaluationComments(
          String evaluationId) async =>
      [
        JournalComment(
            id: 'ce1',
            content: 'Continue ainsi.',
            authorEmail: 'sup@steg.tn',
            createdAt: now),
      ];

  @override
  Future<List<SupervisedIntern>> supervisedInterns() async {
    if (failSupervised) throw Exception('supervised list failed');
    return supervisedOverride ??
        [
          SupervisedIntern(
              internshipId: 'internship-1',
              reference: 'STG-2026-0001',
              internName: 'Amira Ben Salah',
              status: InternshipStatus.inProgress,
              type: InternshipType.perfectionnement,
              startDate: day(now, -10),
              endDate: day(now, 50),
              departmentName: 'DSI',
              tasksCompleted: 1,
              tasksTotal: 4,
              pendingJournal: 1,
              submittedJournal: 1,
              pendingDeliverables: 1,
              evaluationsCount: 1),
        ];
  }

  /// T12: scripted supervised list (proves the list needs no conversation)
  /// and a failure switch for the error state.
  List<SupervisedIntern>? supervisedOverride;
  bool failSupervised = false;

  // --- D6 logbook ---

  bool failAi = false;
  final List<LogbookSubmission> submittedLogbooks = [];

  @override
  Future<LogbookDraft> generateLogbookDraft(
      String internshipId) async {
    if (failAi) throw Exception('AI unavailable');
    return LogbookDraft(
      analysisId: 'ai-1',
      analysisType: 'LOGBOOK_GENERATION',
      modelUsed: 'test-model',
      cinExcluded: true,
      createdAt: now,
      draftText: '| Période | Tâche |\n| Lundi | Setup |',
      recommendations: const ['Vérifiez les dates.'],
    );
  }

  @override
  Future<void> submitLogbook(
      String internshipId, String finalText) async {
    if (failAi) throw Exception('AI unavailable');
    submittedLogbooks
        .add(LogbookSubmission(internshipId: internshipId, text: finalText));
    logbooks[internshipId] = _withStatus(
      _withText(internshipId, finalText),
      LogbookStatus.submitted,
      internshipId: internshipId,
    );
  }

  /// Convenience seeding for supervisor scenarios: a SUBMITTED logbook.
  void seedSubmittedLogbook({
    String internshipId = 'internship-1',
    String text = 'Rapport final du carnet de stage.',
  }) {
    logbooks[internshipId] = LogbookState(
      id: 'logbook-1',
      internshipId: internshipId,
      status: LogbookStatus.submitted,
      finalText: text,
      submittedAt: now,
      createdAt: now,
    );
  }

  /// Server-authoritative logbooks keyed by internship id (test control).
  final Map<String, LogbookState> logbooks = {};
  bool failLogbookRead = false;

  @override
  Future<LogbookState?> getLogbook(String internshipId) async {
    if (failLogbookRead) throw Exception('logbook read failed');
    return logbooks[internshipId];
  }

  @override
  Future<LogbookState> validateLogbook(
      String internshipId, String logbookId) async {
    final current =
        logbooks[internshipId] ?? (throw Exception('no logbook'));
    final updated = _withStatus(
      current,
      LogbookStatus.validated,
      internshipId: internshipId,
      validatedAt: DateTime.now(),
    );
    logbooks[internshipId] = updated;
    return updated;
  }

  @override
  Future<LogbookState> rejectLogbook(
      String internshipId, String logbookId, String reason) async {
    final current =
        logbooks[internshipId] ?? (throw Exception('no logbook'));
    final updated = LogbookState(
      id: current.id,
      internshipId: internshipId,
      status: LogbookStatus.rejected,
      draftText: current.draftText,
      finalText: current.finalText,
      submittedById: current.submittedById,
      submittedAt: current.submittedAt,
      validatedById: current.validatedById,
      validatedAt: current.validatedAt,
      rejectionReason: reason,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    logbooks[internshipId] = updated;
    return updated;
  }

  @override
  Future<LogbookState> promoteLogbookOfficial(
      String internshipId, String logbookId) async {
    final current =
        logbooks[internshipId] ?? (throw Exception('no logbook'));
    final updated = _withStatus(
      current,
      LogbookStatus.official,
      internshipId: internshipId,
      updatedAt: DateTime.now(),
    );
    logbooks[internshipId] = updated;
    return updated;
  }

  @override
  Future<List<PendingLogbookReview>> pendingLogbookReviews() async {
    final out = <PendingLogbookReview>[];
    for (final e in logbooks.entries) {
      final lb = e.value;
      if (lb.status == LogbookStatus.submitted) {
        out.add(PendingLogbookReview(
          internshipId: e.key,
          internshipReference: 'STG-2026-0001',
          logbook: lb,
        ));
      }
    }
    return out;
  }

  LogbookState _withText(
          String internshipId, String finalText) =>
      _withStatus(
        LogbookState(
          id: 'logbook-1',
          internshipId: internshipId,
          status: LogbookStatus.draft,
          finalText: null,
          submittedAt: null,
          createdAt: now,
        ),
        LogbookStatus.draft,
        internshipId: internshipId,
        finalText: finalText,
      );

  LogbookState _withStatus(
    LogbookState current,
    LogbookStatus status, {
    required String internshipId,
    String? finalText,
    String? rejectionReason,
    DateTime? validatedAt,
    DateTime? updatedAt,
  }) =>
      LogbookState(
        id: current.id,
        internshipId: internshipId,
        status: status,
        draftText: current.draftText,
        finalText: finalText ?? current.finalText,
        submittedById: current.submittedById,
        submittedAt: current.submittedAt ?? DateTime.now(),
        validatedById: current.validatedById,
        validatedAt: validatedAt ?? current.validatedAt,
        rejectionReason: rejectionReason ?? current.rejectionReason,
        createdAt: current.createdAt ?? now,
        updatedAt: updatedAt ?? current.updatedAt,
      );

  @override
  Future<String> askAssistant(String question) async {
    askedQuestions.add(question);
    final failure = assistantError;
    if (failure != null) throw failure;
    if (failAi) throw Exception('AI unavailable');
    return 'Réponse de test (indicative) : $question';
  }

  /// T11: scripted assistant failure (e.g. an ApiException with a coded
  /// kind); recorded questions prove dispatch identity for retry tests.
  Object? assistantError;
  final List<String> askedQuestions = [];

  // --- T03 classification fakes (server-authoritative behavior, scripted) ---

  ClassificationBoard fakeBoard = ClassificationBoard.empty;
  List<CategoryProposal> fakeProposals = [];
  int fakeUnclassifiedCount = 0;
  bool failClassificationWrites = false;
  bool failSuggest = false;
  Completer<void>? suggestGate;
  int suggestCalls = 0;
  int applyCalls = 0;
  final List<Map<String, dynamic>> appliedItems = [];
  final List<String> undoneBatches = [];

  @override
  Future<ClassificationBoard> classificationBoard(String internshipId) async {
    if (noInternship) throw StateError('no-internship');
    return fakeBoard;
  }

  @override
  Future<TaskCategory> createCategory(String internshipId,
      {required String name, String? color}) async {
    if (failClassificationWrites) throw Exception('offline');
    final created = TaskCategory(
        id: 'cat-${fakeBoard.categories.length + 1}',
        name: name,
        colorToken: color,
        position: fakeBoard.categories.length);
    fakeBoard = ClassificationBoard(
        categories: [...fakeBoard.categories, created],
        assignments: fakeBoard.assignments);
    return created;
  }

  @override
  Future<TaskCategory> renameCategory(String categoryId,
      {String? name, String? color}) async {
    if (failClassificationWrites) throw Exception('offline');
    final updated = [
      for (final c in fakeBoard.categories)
        if (c.id == categoryId)
          TaskCategory(
              id: c.id,
              name: name ?? c.name,
              colorToken: color ?? c.colorToken,
              position: c.position)
        else
          c,
    ];
    fakeBoard =
        ClassificationBoard(categories: updated, assignments: fakeBoard.assignments);
    return updated.firstWhere((c) => c.id == categoryId,
        orElse: () => TaskCategory(id: categoryId, name: name ?? categoryId));
  }

  @override
  Future<List<TaskCategory>> reorderCategories(List<String> orderedIds) async {
    if (failClassificationWrites) throw Exception('offline');
    final byId = {for (final c in fakeBoard.categories) c.id: c};
    final ordered = [
      for (var i = 0; i < orderedIds.length; i++)
        if (byId[orderedIds[i]] case final c?)
          c.copyWith(position: i),
    ];
    fakeBoard =
        ClassificationBoard(categories: ordered, assignments: fakeBoard.assignments);
    return ordered;
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    if (failClassificationWrites) throw Exception('offline');
    fakeBoard = ClassificationBoard(
      categories: [
        for (final c in fakeBoard.categories)
          if (c.id != categoryId) c,
      ],
      assignments: Map.fromEntries(fakeBoard.assignments.entries
          .where((e) => e.value != categoryId)),
    );
  }

  @override
  Future<void> assignTaskCategory(String taskId,
      {String? categoryId,
      String? expectedCategoryId,
      bool force = false}) async {
    if (failClassificationWrites) throw Exception('offline');
    final assignments = Map<String, String>.of(fakeBoard.assignments);
    if (categoryId == null) {
      assignments.remove(taskId);
    } else {
      assignments[taskId] = categoryId;
    }
    fakeBoard =
        ClassificationBoard(categories: fakeBoard.categories, assignments: assignments);
  }

  @override
  Future<ClassificationSuggestion> suggestCategories(
      String internshipId) async {
    suggestCalls++;
    final gate = suggestGate;
    if (gate != null) await gate.future;
    if (failSuggest) throw Exception('AI unavailable');
    return ClassificationSuggestion(
        proposals: fakeProposals,
        unclassifiedCount: fakeUnclassifiedCount,
        capped: false);
  }

  @override
  Future<ApplyCategoriesResult> applyCategories(String internshipId,
      {required List<Map<String, dynamic>> items,
      required String idempotencyKey}) async {
    applyCalls++;
    if (failClassificationWrites) throw Exception('offline');
    appliedItems.addAll(items);
    final assignments = Map<String, String>.of(fakeBoard.assignments);
    final results = <ApplyCategoryResult>[];
    for (final item in items) {
      final taskId = item['taskId'] as String;
      final categoryId = item['categoryId'] as String?;
      if (categoryId == null) {
        results.add(ApplyCategoryResult(
            taskId: taskId, status: 'INVALID_CATEGORY'));
        continue;
      }
      assignments[taskId] = categoryId;
      results.add(ApplyCategoryResult(
          taskId: taskId, status: 'APPLIED', categoryId: categoryId));
    }
    fakeBoard =
        ClassificationBoard(categories: fakeBoard.categories, assignments: assignments);
    return ApplyCategoriesResult(batchId: 'batch-1', items: results);
  }

  @override
  Future<List<ApplyCategoryResult>> undoApplyBatch(String batchId) async {
    if (failClassificationWrites) throw Exception('offline');
    undoneBatches.add(batchId);
    return const [];
  }

  // --- T04 supervisor lifecycle fakes (server-authoritative, scripted) ---

  final List<String> deletedTasks = [];
  final List<Map<String, dynamic>> reviewedTasks = [];
  final List<Map<String, dynamic>> updatedTasks = [];
  int bulkCalls = 0;
  Completer<void>? bulkGate;
  final List<String> bulkKeys = [];
  final List<Map<String, dynamic>> bulkMutations = [];
  bool failReviewReason = false;

  @override
  Future<void> deleteTask(String taskId) async {
    if (failWrites) throw Exception('offline');
    deletedTasks.add(taskId);
  }

  @override
  Future<InternTask> reviewTask(String taskId,
      {required bool approve, String? comment}) async {
    if (failWrites) throw Exception('offline');
    if (!approve && (comment == null || comment.trim().isEmpty)) {
      if (failReviewReason) throw Exception('review-reason-required');
    }
    reviewedTasks.add({'taskId': taskId, 'approve': approve, 'comment': comment});
    final existing = fixtureTasks(now).where((e) => e.id == taskId);
    final t = existing.isEmpty
        ? InternTask(id: taskId, title: taskId, status: TaskStatus.todo)
        : existing.first;
    return InternTask(
        id: t.id,
        title: t.title,
        status: approve ? TaskStatus.approved : TaskStatus.denied,
        dueDate: t.dueDate,
        description: t.description,
        reviewReason: approve ? null : comment);
  }

  @override
  Future<SupervisorBulkResult> bulkTasks(
      {required List<Map<String, dynamic>> mutations,
      required String idempotencyKey}) async {
    bulkCalls++;
    final gate = bulkGate;
    if (gate != null) await gate.future;
    bulkKeys.add(idempotencyKey);
    bulkMutations.addAll(mutations);
    if (failWrites) throw Exception('offline');
    return SupervisorBulkResult(
      items: [
        for (var i = 0; i < mutations.length; i++)
          SupervisorBulkItem(
              index: i,
              action: (mutations[i]['action'] as String?) ?? 'CREATE',
              taskId: 'bulk-t-$i',
              internshipId: mutations[i]['internshipId'] as String?,
              status: 'OK'),
      ],
    );
  }

  // --- T05 AI draft fakes (server-authoritative, scripted) ---

  List<TaskDraft> fakeDrafts = [];
  List<TaskDraft> generatedDrafts = [];
  bool failDrafts = false;
  Completer<void>? draftGate;
  int generateCalls = 0;
  int bulkDraftCalls = 0;
  final List<String> bulkDraftKeys = [];
  final List<String> deletedDrafts = [];
  final List<Map<String, String>> revisedDrafts = [];
  DateTime? lastBulkVisibleFrom;

  List<TaskDraft> get _seedDrafts => generatedDrafts.isNotEmpty
      ? generatedDrafts
      : [
          TaskDraft(
              id: 'd1',
              referenceInternshipId: 'internship-1',
              title: 'Draft one',
              description: 'First',
              dueDate: DateTime.utc(2026, 3, 1)),
          TaskDraft(
              id: 'd2',
              referenceInternshipId: 'internship-1',
              title: 'Draft two',
              dueDate: DateTime.utc(2026, 3, 10)),
        ];

  List<TaskDraft> _seedFor(String internshipId) => _seedDrafts
      .map((d) => TaskDraft(
          id: d.id,
          referenceInternshipId: internshipId,
          title: d.title,
          description: d.description,
          dueDate: d.dueDate,
          createdAt: d.createdAt))
      .toList();

  @override
  Future<List<TaskDraft>> generateDraftsFromPdf(String internshipId,
      {required String fileName,
      required Uint8List bytes,
      void Function(int sent, int total)? onProgress}) async {
    generateCalls++;
    final gate = draftGate;
    if (gate != null) await gate.future;
    if (failDrafts) throw Exception('AI unavailable');
    onProgress?.call(bytes.length, bytes.length);
    fakeDrafts = _seedFor(internshipId);
    return fakeDrafts;
  }

  @override
  Future<List<TaskDraft>> generateDraftsFromText(String internshipId,
      {required String specText}) async {
    generateCalls++;
    final gate = draftGate;
    if (gate != null) await gate.future;
    if (failDrafts) throw Exception('AI unavailable');
    if (specText.trim().isEmpty) throw Exception('spec-empty');
    fakeDrafts = _seedFor(internshipId);
    return fakeDrafts;
  }

  @override
  Future<List<TaskDraft>> listDrafts({String? internshipId}) async =>
      internshipId == null
          ? fakeDrafts
          : fakeDrafts
              .where((d) => d.referenceInternshipId == internshipId)
              .toList();

  @override
  Future<TaskDraft> addDraftManual(String internshipId,
      {required String title,
      String? description,
      DateTime? dueDate}) async {
    if (failWrites) throw Exception('offline');
    final created = TaskDraft(
        id: 'd-manual-${fakeDrafts.length + 1}',
        referenceInternshipId: internshipId,
        title: title,
        description: description,
        dueDate: dueDate);
    fakeDrafts = [...fakeDrafts, created];
    return created;
  }

  @override
  Future<TaskDraft> updateDraft(String draftId,
      {String? title, String? description, DateTime? dueDate}) async {
    if (failWrites) throw Exception('offline');
    TaskDraft? updated;
    fakeDrafts = [
      for (final d in fakeDrafts)
        if (d.id == draftId)
          updated = TaskDraft(
              id: d.id,
              referenceInternshipId: d.referenceInternshipId,
              title: title ?? d.title,
              description: description ?? d.description,
              dueDate: dueDate ?? d.dueDate,
              createdAt: d.createdAt)
        else
          d,
    ];
    return updated ??
        TaskDraft(
            id: draftId,
            referenceInternshipId: 'internship-1',
            title: title ?? draftId);
  }

  @override
  Future<TaskDraft> reviseDraft(String draftId,
      {required String instruction}) async {
    if (failWrites) throw Exception('offline');
    revisedDrafts.add({'draftId': draftId, 'instruction': instruction});
    return updateDraft(draftId,
        title: 'Revised: $instruction', description: null);
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    if (failWrites) throw Exception('offline');
    deletedDrafts.add(draftId);
    fakeDrafts = [for (final d in fakeDrafts) if (d.id != draftId) d];
  }

  @override
  Future<DraftBulkResult> bulkAddDrafts(
      {required List<String> draftIds,
      required List<String> internshipIds,
      required String idempotencyKey,
      DateTime? visibleFrom}) async {
    bulkDraftCalls++;
    bulkDraftKeys.add(idempotencyKey);
    lastBulkVisibleFrom = visibleFrom;
    if (failWrites) throw Exception('offline');
    var index = 0;
    return DraftBulkResult(items: [
      for (final draftId in draftIds)
        for (final internshipId in internshipIds)
          DraftBulkItem(
              index: index++,
              draftId: draftId,
              internshipId: internshipId,
              taskId: 't-$draftId-$internshipId',
              status: 'OK'),
    ]);
  }
}

/// Recorded logbook submission captured by the fake repository.
class LogbookSubmission {
  const LogbookSubmission({required this.internshipId, required this.text});
  final String internshipId;
  final String text;
}
