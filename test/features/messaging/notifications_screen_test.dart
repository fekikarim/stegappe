import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/features/internship/presentation/widgets/status_labels.dart'
    show formatDay;
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/notifications_screen.dart';
import 'package:stegappe/features/messaging/presentation/widgets/notification_type_visuals.dart';

import 'notifications_test_support.dart';

void main() {
  group('catalogue rendering (acceptance 1)', () {
    test('the visual mapping is complete and pairwise distinct', () async {
      for (final locale in const [Locale('fr'), Locale('en'), Locale('ar')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final labels = <String>{};
        final icons = <IconData>{};
        for (final type in NotificationType.values) {
          final label = notificationTypeLabel(type, l10n);
          expect(label.trim(), isNotEmpty, reason: '$type has no label');
          icons.add(notificationTypeIcon(type));
          if (type != NotificationType.unknown) {
            expect(labels.add(label), isTrue,
                reason: '$type reuses the label "$label"');
          }
        }
        // 25 catalogue keys (22 + T08's 3 community keys), 25 distinct
        // icons, none of them the generic one.
        expect(icons, hasLength(NotificationType.values.length));
        expect(labels, hasLength(NotificationType.values.length - 1));
      }
    });

    testWidgets('each row shows its typed icon and localized label',
        (tester) async {
      final repo = FakeNotificationsRepository(
        unread: 2,
        items: [
          notif('n1',
              type: NotificationType.taskAssigned,
              title: 'Tâche assignée',
              createdAt: DateTime.now()),
          notif('n2',
              type: NotificationType.documentVerified,
              title: 'Document approuvé',
              createdAt: DateTime.now()),
          notif('n3',
              type: NotificationType.welcome,
              title: 'Bienvenue sur STEG intern',
              createdAt: DateTime.now()),
        ],
      );
      await pumpNotifications(tester, repo: repo);

      expect(find.text('Nouvelle tâche'), findsOneWidget);
      expect(find.text('Document vérifié'), findsOneWidget);
      expect(find.text('Bienvenue'), findsOneWidget);
      expect(find.byIcon(Icons.add_task), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
      expect(find.byIcon(Icons.waving_hand_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    });

    testWidgets('a legacy row without a type renders generically',
        (tester) async {
      await pumpNotifications(
        tester,
        repo: FakeNotificationsRepository(
          items: [
            notif('n1',
                title: 'Ancien événement', createdAt: DateTime.now()),
          ],
        ),
      );

      expect(find.text('Ancien événement'), findsOneWidget);
      expect(find.text('Notification'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('rows are grouped by day', (tester) async {
      final older = DateTime.now().subtract(const Duration(days: 3));
      await pumpNotifications(
        tester,
        repo: FakeNotificationsRepository(
          items: [
            notif('n1', title: 'Récent', createdAt: DateTime.now()),
            notif('n2', title: 'Plus ancien', createdAt: older),
          ],
        ),
      );

      expect(find.text('Aujourd’hui'), findsOneWidget);
      expect(find.text(formatDay(older, const Locale('fr'))), findsOneWidget);
      expect(find.text('Récent'), findsOneWidget);
      expect(find.text('Plus ancien'), findsOneWidget);
    });
  });

  group('states (acceptance 1/5)', () {
    testWidgets('the empty state says what will appear here', (tester) async {
      await pumpNotifications(tester, repo: FakeNotificationsRepository());

      expect(find.text('Aucune notification.'), findsOneWidget);
      expect(
        find.text(
            'Rien pour le moment — vos tâches et documents apparaîtront ici.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('a server failure renders a localized error with retry',
        (tester) async {
      final repo = FakeNotificationsRepository(
        items: [notif('n1', title: 'Après reprise', createdAt: DateTime.now())],
      )..failList = true;
      await pumpNotifications(tester, repo: repo);

      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Après reprise'), findsNothing);

      repo.failList = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Après reprise'), findsOneWidget);
    });

    testWidgets('offline keeps the last known rows with an honest banner',
        (tester) async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', title: 'Dernier état connu', createdAt: DateTime.now())],
      );
      final container = await pumpNotifications(tester, repo: repo);
      expect(find.text('Dernier état connu'), findsOneWidget);

      repo.failList = true;
      await container.read(notificationsControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();

      expect(find.text('Dernier état connu'), findsOneWidget);
      expect(
        find.text('Hors ligne — affichage du dernier état connu'),
        findsOneWidget,
      );
    });
  });

  group('read state (acceptance 4)', () {
    testWidgets('marking one read persists through the repository',
        (tester) async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', title: 'À lire', createdAt: DateTime.now())],
      );
      await pumpNotifications(tester, repo: repo);

      await tester.tap(find.text('Marquer comme lue'));
      await tester.pumpAndSettle();

      expect(repo.read, ['n1']);
    });

    testWidgets('mark all read persists and rolls back when the server refuses',
        (tester) async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', title: 'À lire', createdAt: DateTime.now())],
      )..failReadAll = true;
      final container = await pumpNotifications(tester, repo: repo);

      await tester.tap(find.text('Tout marquer comme lu'));
      await tester.pumpAndSettle();

      expect(repo.readAllCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        container.read(notificationsControllerProvider).items.single.isRead,
        isFalse,
        reason: 'the optimistic bulk read must be rolled back',
      );
    });

    testWidgets('the unread filter asks the server and hides read rows',
        (tester) async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [
          notif('n1', title: 'Non lue', createdAt: DateTime.now()),
          notif('n2', title: 'Déjà lue', createdAt: DateTime.now(), isRead: true),
        ],
      );
      await pumpNotifications(tester, repo: repo);
      expect(find.text('Déjà lue'), findsOneWidget);

      await tester.tap(find.text('Non lues'));
      await tester.pumpAndSettle();

      expect(repo.queries.last.unreadOnly, isTrue);
      expect(find.text('Non lue'), findsOneWidget);
      expect(find.text('Déjà lue'), findsNothing);
    });
  });

  group('deep links (acceptance 1)', () {
    testWidgets('tapping a typed task row marks it read and opens the board',
        (tester) async {
      int? opened;
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [
          // The title is deliberately not the catalogue label: the label chip
          // and the row title are independent pieces of text.
          notif('n1',
              type: NotificationType.taskUpdated,
              title: 'Tâche « cahier » modifiée',
              entity: 'Task',
              entityId: 't1',
              createdAt: DateTime.now()),
        ],
      );
      await pumpNotifications(tester, repo: repo, onOpenTab: (t) => opened = t);

      await tester.tap(find.text('Tâche « cahier » modifiée'));
      await tester.pumpAndSettle();

      expect(repo.read, ['n1']);
      expect(opened, 1);
      expect(find.byType(NotificationsScreen), findsNothing);
    });

    testWidgets(
        'a row with no safe destination stays in the center and shows its full text',
        (tester) async {
      const longMessage =
          'Votre paiement a été approuvé par l’administration. Le détail '
          'complet du dossier financier est disponible auprès du service.';
      await pumpNotifications(
        tester,
        repo: FakeNotificationsRepository(
          items: [
            notif('n1',
                type: NotificationType.paymentApproved,
                title: 'Dossier financier approuvé',
                message: longMessage,
                entity: 'FinanceCase',
                entityId: 'fc-1',
                isRead: true,
                createdAt: DateTime.now()),
          ],
        ),
      );

      // No shell tab exists for finance events: no arrow, no forced tab.
      expect(find.byIcon(Icons.arrow_forward_outlined), findsNothing);

      await tester.tap(find.text('Dossier financier approuvé'));
      await tester.pumpAndSettle();

      // The sheet shows the message untruncated (the list row keeps maxLines).
      final fullText = find.byType(SelectableText);
      expect(fullText, findsOneWidget);
      expect(tester.widget<SelectableText>(fullText).data, longMessage);
      expect(
        find.text('Notification introuvable ou expirée.'),
        findsOneWidget,
      );
    });

    testWidgets('a live frame merges into the list without losing the scroll',
        (tester) async {
      final repo = FakeNotificationsRepository(
        unread: 12,
        items: [
          for (var i = 0; i < 12; i++)
            notif('n$i',
                title: 'Notification $i',
                createdAt: DateTime.now().subtract(Duration(minutes: i)),
                isRead: false),
        ],
      );
      final container = await pumpNotifications(tester, repo: repo);
      expect(find.text('Notification 0'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(position, greaterThan(0));

      container.read(notificationFramesProvider).add(
          frame('live-1', type: 'MESSAGE_RECEIVED', title: 'Message direct'));
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(find.byType(Scrollable).last).position.pixels,
        position,
        reason: 'a live frame must not reset the viewport',
      );
      expect(
        container.read(notificationsControllerProvider).items.first.id,
        'live-1',
      );
    });

    testWidgets('a malformed frame never breaks the center', (tester) async {
      final container = await pumpNotifications(
        tester,
        repo: FakeNotificationsRepository(
          items: [notif('n1', title: 'Stable', createdAt: DateTime.now())],
        ),
      );

      container.read(notificationFramesProvider)
        ..add('not json')
        ..add('{"title":"no id"}');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Stable'), findsOneWidget);
    });
  });
}
