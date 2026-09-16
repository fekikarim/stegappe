import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_card.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../providers/auth_providers.dart';

/// Login screen: email/password with mapped server field errors,
/// double-submit guard, preserved values on failure (UI_UX.md §14).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _emailError(AuthState state) {
    if (state is! AuthUnauthenticated) return null;
    final err = ref.read(authControllerProvider.notifier).lastError;
    return err?.fieldMessage('email');
  }

  String? _passwordError(AuthState state) {
    if (state is! AuthUnauthenticated) return null;
    final err = ref.read(authControllerProvider.notifier).lastError;
    return err?.fieldMessage('password');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.emailRequired)),
      );
      return;
    }
    if (_password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: email, password: _password.text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final topError =
        state is AuthUnauthenticated ? state.message : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: StegSpacing.screenPadding,
            shrinkWrap: true,
            children: [
              Image.asset(
                'assets/logo-steg-1200x327.png',
                height: 56,
                semanticLabel: 'STEG',
                errorBuilder: (_, _, _) => const SizedBox(height: 8),
              ),
              const SizedBox(height: StegSpacing.lg),
              StegCard(
                title: l10n.loginTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (topError != null) ...[
                      Semantics(
                        liveRegion: true,
                        label: topError,
                        child: Container(
                          padding: const EdgeInsets.all(StegSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                StegSpacing.radiusSm),
                          ),
                          child: Text(topError),
                        ),
                      ),
                      const SizedBox(height: StegSpacing.md),
                    ],
                    StegTextField(
                      controller: _email,
                      label: l10n.email,
                      required: true,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      error: _emailError(state),
                    ),
                    const SizedBox(height: StegSpacing.md),
                    StegTextField(
                      controller: _password,
                      label: l10n.password,
                      required: true,
                      obscure: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      error: _passwordError(state),
                      suffix: IconButton(
                        tooltip: _obscure
                            ? AppLocalizations.of(context)
                                .showPassword
                            : AppLocalizations.of(context)
                                .hidePassword,
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: StegSpacing.lg),
                    StegButton(
                      label: l10n.loginAction,
                      loading: _submitting || state is AuthLoading,
                      onPressed:
                          (_submitting || state is AuthLoading)
                              ? null
                              : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
