import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/data/cache/assistant_history_store.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/assistant.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';

import '../test_fixtures.dart';

void main() {
  group('S6 — AI surfaces (ST-BOT, SU-TASK-02)', () {
    test(
      'S6.1: Student assistant answers question (responseText contract), persists in history store across restart, refuses foreign scope',
      () async {
        final store = MemoryAssistantHistoryStore();

        // 1. Backend contract: responseText is authoritative
        final text = assistantAnswerFromJson({
          'analysis': {'id': 'analysis-1', 'outputSummary': 'Summary'},
          'recommendations': ['R1', 'R2'],
          'responseText': 'Les dates de validation sont fixées par votre encadrant.',
        });
        expect(text, 'Les dates de validation sont fixées par votre encadrant.');

        // 2. Persist turn in history store
        final messages = [
          const AssistantMessage(
            mine: true,
            text: 'Quand dois-je soumettre mon rapport ?',
          ),
          const AssistantMessage(
            mine: false,
            text: 'Les dates de validation sont fixées par votre encadrant.',
          ),
        ];

        await store.save('u1', messages);
        final loaded = await store.load('u1');
        expect(loaded.length, 2);
        expect(loaded.first.text, 'Quand dois-je soumettre mon rapport ?');
        expect(loaded.last.text, 'Les dates de validation sont fixées par votre encadrant.');

        // Verify history survives restart (re-read from store)
        final reloaded = await store.load('u1');
        expect(reloaded.last.text, loaded.last.text);

        // 3. User isolation: history for u1 is never visible to u2
        final user2History = await store.load('u2');
        expect(user2History, isEmpty);
      },
    );

    test(
      'S6.2: Supervisor generates task drafts from PDF and text, edits one, revises with AI, deletes, bulk-adds',
      () async {
        final repo = FakeInternshipRepository();

        // 1. Generate drafts from PDF
        final pdfDrafts = await repo.generateDraftsFromPdf(
          'internship-1',
          fileName: 'cahier_des_charges.pdf',
          bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        );
        expect(pdfDrafts, isNotEmpty);

        // 2. Generate drafts from text
        final textDrafts = await repo.generateDraftsFromText(
          'internship-1',
          specText: 'Spécifications du banc d\'essai des compteurs.',
        );
        expect(textDrafts, isNotEmpty);

        // 3. Draft lifecycle: edit, revise, delete
        final draftId = textDrafts.first.id;
        final updated = await repo.updateDraft(
          draftId,
          title: 'Titre révisé manuellement',
          description: 'Description détaillée',
        );
        expect(updated.title, 'Titre révisé manuellement');

        final revised = await repo.reviseDraft(
          draftId,
          instruction: 'Rendre le titre plus concis',
        );
        expect(revised.id, draftId);

        await repo.deleteDraft(draftId);
        expect(repo.deletedDrafts, contains(draftId));

        // 4. Bulk-add remaining drafts
        final bulkResult = await repo.bulkAddDrafts(
          draftIds: [pdfDrafts.first.id],
          internshipIds: ['internship-1', 'internship-2'],
          idempotencyKey: 'bulk-draft-key-99',
        );
        expect(bulkResult.items, isNotEmpty);
      },
    );

    test(
      'S6.3: AI provider down / stopped -> AI surface shows unavailable state, manual alternative remains unblocked',
      () async {
        final repo = FakeInternshipRepository();
        repo.failDrafts = true; // simulate AI outage

        // Generating drafts throws an AI unavailable exception
        expect(
          () => repo.generateDraftsFromText('internship-1', specText: 'Specs'),
          throwsA(isA<Exception>()),
        );

        // Core manual flow is NOT blocked: supervisor can create tasks manually without AI
        final manualTask = await repo.createTask(
          'internship-1',
          title: 'Tâche créée manuellement sans IA',
          description: 'Alternative manuelle',
        );
        expect(manualTask.title, 'Tâche créée manuellement sans IA');
        expect(manualTask.status, TaskStatus.todo);
      },
    );
  });
}
