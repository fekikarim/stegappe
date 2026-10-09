import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../providers/auth_providers.dart';

/// Login screen — premium STEG-branded design (UI_UX.md §14).
/// Features: gradient background, glassmorphism card, STEG logo,
/// double-submit guard, server field errors, preserved values on failure.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _submitting = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String? _emailError(AuthState state) {
    if (state is! AuthUnauthenticated) return null;
    return ref.read(authControllerProvider.notifier).lastError?.fieldMessage('email');
  }

  String? _passwordError(AuthState state) {
    if (state is! AuthUnauthenticated) return null;
    return ref.read(authControllerProvider.notifier).lastError?.fieldMessage('password');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showSnack(l10n.emailRequired);
      return;
    }
    if (_password.text.isEmpty) {
      _showSnack(l10n.passwordRequired);
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: StegColors.brandNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    final rawError = state is AuthUnauthenticated ? state.message : null;
    final topError = rawError == 'queue-auth-discarded'
        ? l10n.queueAuthDiscarded
        : rawError;
    final isLoading = _submitting || state is AuthLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  StegColors.brandNavy,   // #042843
                  Color(0xFF073858),
                  StegColors.brandPrimary, // #0B61A0
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Decorative wave / arc ────────────────────────────────────
          Positioned(
            top: -60,
            left: -80,
            right: -80,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StegColors.primaryBright.withValues(alpha: 0.07),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            // ── Logo section ──────────────────────────
                            _LogoSection(),
                            const Spacer(flex: 3),
                            // ── Glass card with form ──────────────────
                            _GlassCard(
                              topError: topError,
                              emailController: _email,
                              passwordController: _password,
                              emailFocus: _emailFocus,
                              passwordFocus: _passwordFocus,
                              obscure: _obscure,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              emailError: _emailError(state),
                              passwordError: _passwordError(state),
                              isLoading: isLoading,
                              onSubmit: isLoading ? null : _submit,
                              onNext: () => _passwordFocus.requestFocus(),
                              l10n: l10n,
                            ),
                            const Spacer(flex: 2),
                            // ── Footer ────────────────────────────────
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Text(
                                'STEG © ${DateTime.now().year}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo section
// ─────────────────────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // STEG banner logo
          Container(
            height: 64,
            constraints: const BoxConstraints(maxWidth: 340),
            child: Image.asset(
              'assets/logo-steg-1200x327.png',
              fit: BoxFit.contain,
              semanticLabel: 'STEG',
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (_, _, _) => _FallbackLogo(),
            ),
          ),
          const SizedBox(height: 16),
          // Subtitle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: StegColors.primaryBright.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Plateforme de Stage',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.bolt, color: Colors.white, size: 32),
        const SizedBox(width: 8),
        Text(
          'STEG',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass card + form
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.topError,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscure,
    required this.onToggleObscure,
    required this.emailError,
    required this.passwordError,
    required this.isLoading,
    required this.onSubmit,
    required this.onNext,
    required this.l10n,
  });

  final String? topError;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? emailError;
  final String? passwordError;
  final bool isLoading;
  final VoidCallback? onSubmit;
  final VoidCallback onNext;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  l10n.loginTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bienvenue sur votre espace stage',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),

                // Error banner
                if (topError != null) ...[
                  Semantics(
                    liveRegion: true,
                    label: topError,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: StegColors.brandRed.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: StegColors.brandRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade300, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topError!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                _GlassField(
                  controller: emailController,
                  focusNode: emailFocus,
                  label: l10n.email,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => onNext(),
                  errorText: emailError,
                ),
                const SizedBox(height: 16),

                // Password field
                _GlassField(
                  controller: passwordController,
                  focusNode: passwordFocus,
                  label: l10n.password,
                  icon: Icons.lock_outline,
                  obscure: obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit?.call(),
                  errorText: passwordError,
                  suffix: IconButton(
                    tooltip: obscure ? l10n.showPassword : l10n.hidePassword,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  ),
                ),
                const SizedBox(height: 28),

                // Submit button
                _SubmitButton(
                  label: l10n.loginAction,
                  isLoading: isLoading,
                  onPressed: onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass text field
// ─────────────────────────────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final String? errorText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? StegColors.brandRed.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 20,
                ),
              ),
              Expanded(
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    PasteTextIntent: CallbackAction<PasteTextIntent>(
                      onInvoke: (PasteTextIntent intent) async {
                        await _pasteIntoController(controller);
                        return null;
                      },
                    ),
                  },
                  child: Shortcuts(
                    shortcuts: <ShortcutActivator, Intent>{
                      LogicalKeySet(
                        LogicalKeyboardKey.meta,
                        LogicalKeyboardKey.keyV,
                      ): const PasteTextIntent(SelectionChangedCause.keyboard),
                      LogicalKeySet(
                        LogicalKeyboardKey.control,
                        LogicalKeyboardKey.keyV,
                      ): const PasteTextIntent(SelectionChangedCause.keyboard),
                    },
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enableInteractiveSelection: true,
                      contextMenuBuilder: (context, editableTextState) =>
                          _buildAdaptiveContextMenu(
                        context,
                        editableTextState,
                        controller,
                      ),
                      obscureText: obscure,
                      keyboardType: keyboardType,
                      textInputAction: textInputAction,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: label,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 0,
                        ),
                      ),
                      cursorColor: StegColors.primaryBright,
                    ),
                  ),
                ),
              ),
              ?suffix,
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Colors.orange.shade300,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit button
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF1478C8), StegColors.primaryBright],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: StegColors.brandPrimary.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            minimumSize: const Size.fromHeight(52),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

Widget _buildAdaptiveContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
  TextEditingController controller,
) {
  final buttonItems = editableTextState.contextMenuButtonItems;
  final hasPaste =
      buttonItems.any((item) => item.type == ContextMenuButtonType.paste);
  if (!hasPaste) {
    buttonItems.insert(
      0,
      ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        onPressed: () {
          _pasteIntoController(controller);
          editableTextState.hideToolbar();
        },
      ),
    );
  }
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );
}

Future<void> _pasteIntoController(TextEditingController controller) async {
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      final selection = controller.selection;
      if (selection.isValid &&
          selection.start >= 0 &&
          selection.end >= selection.start) {
        final old = controller.text;
        final newText = old.replaceRange(selection.start, selection.end, text);
        controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.collapsed(offset: selection.start + text.length),
        );
      } else {
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  } catch (_) {}
}


