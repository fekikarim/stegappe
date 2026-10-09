import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/steg_colors.dart';
import '../providers/auth_providers.dart';

/// Redesigned Change Password Screen for STEG mobile.
///
/// Features:
/// - Visual parity with the modern STEG dark gradient & glassmorphism aesthetic
/// - Dynamic real-time password policy checklist (16+ chars, upper, lower, digit, symbol)
/// - Visibility toggle for all 3 fields
/// - Seamless session refresh ensuring immediate transition to student shell upon success
/// - Logout affordance so users are never trapped without navigation options
/// - Motion durations capped at 250ms and RTL-compliant (EdgeInsetsDirectional)
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  final _currentFocus = FocusNode();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;

  String? _error;
  bool _saving = false;
  bool _success = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _next.addListener(_onFieldChanged);
    _confirm.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _next.removeListener(_onFieldChanged);
    _confirm.removeListener(_onFieldChanged);
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _currentFocus.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _next.text.length >= 16;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_next.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_next.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_next.text);
  bool get _hasSymbol => RegExp(r'[^A-Za-z0-9]').hasMatch(_next.text);
  bool get _passwordsMatch =>
      _next.text.isNotEmpty && _next.text == _confirm.text;

  bool get _isPolicySatisfied =>
      _hasMinLength &&
      _hasUpper &&
      _hasLower &&
      _hasDigit &&
      _hasSymbol &&
      _passwordsMatch;

  Future<void> _submit() async {
    if (_saving || _success) return;

    if (_current.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your current temporary password.');
      _currentFocus.requestFocus();
      return;
    }

    if (_next.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      _confirmFocus.requestFocus();
      return;
    }

    if (!_hasMinLength || !_hasUpper || !_hasLower || !_hasDigit || !_hasSymbol) {
      setState(
        () => _error =
            'Use 16+ characters with upper, lower, digit, and symbol.',
      );
      _nextFocus.requestFocus();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _saving = false;
        _success = true;
      });

      // If screen was pushed onto navigator, pop back cleanly with feedback
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mot de passe mis à jour avec succès!'),
            backgroundColor: StegColors.brandNavy,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      // If screen was rendered by AuthGate (mandatory first-time change),
      // the updated authControllerProvider state (mustChangePassword=false)
      // immediately causes AuthGate to transition to InternShell.
    } else {
      setState(() {
        _saving = false;
        _error = ref.read(authControllerProvider.notifier).lastError?.message ??
            'Password change failed. Please check current password and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Gradient background matching login screen ──────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  StegColors.brandNavy, // #042843
                  Color(0xFF073858),
                  StegColors.brandPrimary, // #0B61A0
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Ambient background circles ─────────────────────────────────────
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
            bottom: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StegColors.primaryBright.withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Foreground content ─────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Navigation Bar
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (canPop)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white, size: 20),
                              tooltip: 'Back',
                              onPressed: () => Navigator.of(context).pop(),
                            )
                          else
                            const SizedBox(width: 48),
                          // Subtle brand watermark
                          SizedBox(
                            height: 26,
                            child: Image.asset(
                              'assets/logo-steg-1200x327.png',
                              fit: BoxFit.contain,
                              color: Colors.white.withValues(alpha: 0.85),
                              colorBlendMode: BlendMode.srcIn,
                              errorBuilder: (_, _, _) => const Text(
                                'STEG',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          // Logout button affordance
                          IconButton(
                            icon: const Icon(Icons.logout_outlined,
                                color: Colors.white70, size: 22),
                            tooltip: 'Se déconnecter / Logout',
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .logout(),
                          ),
                        ],
                      ),
                    ),

                    // Title header
                    const Text(
                      'Change temporary password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set a new password before continuing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Glassmorphism Form Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Field 1: Current Password ────────────────
                              _buildGlassField(
                                controller: _current,
                                focusNode: _currentFocus,
                                label: 'Current password',
                                icon: Icons.key_outlined,
                                obscure: _obscureCurrent,
                                onToggleObscure: () => setState(
                                    () => _obscureCurrent = !_obscureCurrent),
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _nextFocus.requestFocus(),
                              ),
                              const SizedBox(height: 12),

                              // ── Field 2: New Password ────────────────────
                              _buildGlassField(
                                controller: _next,
                                focusNode: _nextFocus,
                                label: 'New password',
                                icon: Icons.shield_outlined,
                                obscure: _obscureNext,
                                onToggleObscure: () => setState(
                                    () => _obscureNext = !_obscureNext),
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) =>
                                    _confirmFocus.requestFocus(),
                              ),
                              const SizedBox(height: 12),

                              // ── Field 3: Confirm New Password ────────────
                              _buildGlassField(
                                controller: _confirm,
                                focusNode: _confirmFocus,
                                label: 'Confirm new password',
                                icon: Icons.verified_user_outlined,
                                obscure: _obscureConfirm,
                                onToggleObscure: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),

                              // ── Error Callout ────────────────────────────
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade900
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ── Success Callout ──────────────────────────
                              if (_success) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade900
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.greenAccent
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.greenAccent,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Mot de passe mis à jour. Redirection...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // ── Continue / Submit Button ─────────────────
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed: _saving ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _isPolicySatisfied
                                        ? StegColors.brandPrimary
                                        : StegColors.brandNavy,
                                    disabledBackgroundColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _saving
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Saving...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Continue',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Dynamic Policy Checklist (Below Form Card) ─────────
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined,
                                  color: Colors.cyanAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Exigences de mot de passe / Requirements:',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _CheckItem(
                                label: '16+ caractères / characters',
                                isMet: _hasMinLength,
                              ),
                              _CheckItem(
                                label: 'Majuscule (A-Z)',
                                isMet: _hasUpper,
                              ),
                              _CheckItem(
                                label: 'Minuscule (a-z)',
                                isMet: _hasLower,
                              ),
                              _CheckItem(
                                label: 'Chiffre (0-9)',
                                isMet: _hasDigit,
                              ),
                              _CheckItem(
                                label: 'Symbole (!@#\$...)',
                                isMet: _hasSymbol,
                              ),
                              if (_confirm.text.isNotEmpty)
                                _CheckItem(
                                  label: 'Correspondance',
                                  isMet: _passwordsMatch,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggleObscure,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.65),
              size: 18,
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
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                  ),
                  cursorColor: Colors.cyanAccent,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white.withValues(alpha: 0.60),
              size: 18,
            ),
            tooltip: obscure ? 'Show password' : 'Hide password',
            onPressed: onToggleObscure,
          ),
        ],
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

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: isMet ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isMet ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
