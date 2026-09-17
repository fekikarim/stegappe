// Intern AI assistant screen (E3.2/E5): contextual RAG chat over the
// controlled STEG knowledge base. The Gemini key never leaves Spring Boot:
// the app posts questions to /api/ai/assistant/query and renders the
// advisory answer. Degraded mode never blocks core flows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../providers/workspace_providers.dart';

class _ChatMessage {
  const _ChatMessage({required this.mine, required this.text});
  final bool mine;
  final String text;
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _pending) return;
    setState(() {
      _messages.add(_ChatMessage(mine: true, text: question));
      _controller.clear();
      _pending = true;
      _error = null;
    });
    _scrollToEnd();
    try {
      final repo = ref.read(internshipRepositoryProvider);
      final answer = await repo.askAssistant(question);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(mine: false, text: answer));
        _pending = false;
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = l10n.assistantUnavailable;
        _pending = false;
      });
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistantTitle)),
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
              child: _messages.isEmpty && !_pending
                  ? Center(
                      child: Text(l10n.assistantEmpty,
                          style: Theme.of(context).textTheme.bodyMedium))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(StegSpacing.md),
                      itemCount: _messages.length + (_pending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _messages.length) {
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
                        final m = _messages[i];
                        return Align(
                          alignment: m.mine
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: StegSpacing.xs),
                            padding: const EdgeInsets.all(StegSpacing.sm),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8),
                            decoration: BoxDecoration(
                              color: m.mine
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(StegSpacing.radiusMd),
                            ),
                            child: Text(m.text,
                                style: TextStyle(
                                    color: m.mine
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: StegSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(_error!,
                            semanticsLabel: _error,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error))),
                    TextButton(
                        onPressed: _pending ? null : _ask,
                        child: const Text('OK')),
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
                        enabled: !_pending,
                        decoration: InputDecoration(
                          hintText: l10n.assistantPlaceholder,
                          counterText: '',
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
                      onPressed: _pending ? null : _ask,
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
