// Intern AI assistant screen (T11): contextual RAG chat over the
// controlled STEG knowledge base. The Gemini key never leaves Spring Boot:
// the app posts questions to /api/ai/assistant/query and renders the
// advisory answer decoded from the authoritative `responseText` field.
// Conversation state lives in the session controller (survives navigation)
// with local per-user persistence (survives restart, wiped on logout).
// Degraded mode never blocks core flows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/assistant.dart';
import '../providers/assistant_providers.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(assistantControllerProvider.notifier).restore());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final text = _controller.text;
    final sent = await ref.read(assistantControllerProvider.notifier).send(text);
    if (!mounted) return;
    if (sent) _controller.clear();
    _scrollToEnd();
  }

  Future<void> _retry(int index) async {
    await ref.read(assistantControllerProvider.notifier).retry(index);
    if (mounted) _scrollToEnd();
  }

  Future<void> _confirmClear() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantClearTitle),
        content: Text(l10n.assistantClearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.assistantClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(assistantControllerProvider.notifier).clear();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  /// Honest per-failure sentence. A 404 here means the backend found no
  /// internship for the caller — rendered as an empty state, not a crash.
  String _errorMessage(Object error, AppLocalizations l10n) {
    if (error is ApiException && error.kind == ApiErrorKind.notFound) {
      return l10n.assistantNoInternship;
    }
    return userMessageOf(error, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(assistantControllerProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final failedIndex = state.messages.lastIndexWhere((m) => m.failed);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantTitle),
        actions: [
          if (state.messages.isNotEmpty && !state.pending)
            Semantics(
              button: true,
              label: l10n.assistantClearTitle,
              child: IconButton(
                tooltip: l10n.assistantClearTitle,
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmClear,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: StegSpacing.cardPadding,
              child: StegStatusChip(label: l10n.aiBadge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StegSpacing.md),
              child: Text(l10n.assistantExplain,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StegSpacing.md),
              child: Text(l10n.aiAdvisoryNote,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: StegSpacing.sm),
            Expanded(
              child: state.messages.isEmpty && !state.pending
                  ? Center(
                      child: Text(l10n.assistantEmpty,
                          style: Theme.of(context).textTheme.bodyMedium))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(StegSpacing.md),
                      itemCount:
                          state.messages.length + (state.pending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= state.messages.length) {
                          return Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Semantics(
                              label: l10n.assistantThinking,
                              child: const Padding(
                                padding: EdgeInsets.all(StegSpacing.sm),
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                            ),
                          );
                        }
                        final m = state.messages[i];
                        return _Bubble(
                          message: m,
                          onRetry:
                              m.failed ? () => _retry(i) : null,
                        );
                      },
                    ),
            ),
            if (state.error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: StegSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        label: _errorMessage(state.error!, l10n),
                        excludeSemantics: true,
                        child: Text(
                          _errorMessage(state.error!, l10n),
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ),
                    if (failedIndex >= 0)
                      TextButton(
                        onPressed: state.pending
                            ? null
                            : () => _retry(failedIndex),
                        child: Text(l10n.retry),
                      ),
                  ],
                ),
              ),
            if (!isOnline)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: StegSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 18),
                    const SizedBox(width: StegSpacing.xs),
                    Expanded(
                      child: Text(l10n.assistantOffline,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(StegSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: l10n.assistantTitle,
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        enabled: !state.pending && isOnline,
                        decoration: InputDecoration(
                          hintText: l10n.assistantPlaceholder,
                        ),
                        onSubmitted: (_) => _ask(),
                      ),
                    ),
                  ),
                  const SizedBox(width: StegSpacing.sm),
                  Semantics(
                    button: true,
                    label: l10n.assistantSend,
                    child: FilledButton(
                      onPressed: (!state.pending && isOnline) ? _ask : null,
                      child: Text(l10n.assistantSend),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One chat bubble. Failed assistant rows render the error inline with a
/// retry affordance instead of pretending an answer arrived; long texts
/// wrap and scroll with the list (never truncated mid-word by the UI).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry});

  final AssistantMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: message.mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: StegSpacing.xs),
        padding: const EdgeInsets.all(StegSpacing.sm),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: message.mine
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.mine && message.failed)
              Text(
                l10n.assistantUnavailable,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              )
            else
              Text(message.text,
                  style: TextStyle(
                      color: message.mine
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface)),
            if (onRetry != null) ...[
              const SizedBox(height: StegSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(l10n.retry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
