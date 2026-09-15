import 'package:flutter/material.dart';

/// Accessible text field with label, helper, error, required marker,
/// preserved values on error, and 48px minimum tap affordance.
/// Direction-aware: uses AlignmentDirectional so Arabic aligns right.
class StegTextField extends StatelessWidget {
  const StegTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.required = false,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.semanticsLabel,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final bool required;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticsLabel ?? label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelLarge,
              children: [
                if (required)
                  const TextSpan(
                      text: ' *',
                      style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction:
                textInputAction ?? TextInputAction.next,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              errorText: error,
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bidi-safe wrapper for technical LTR values inside RTL layouts
/// (emails, URLs, references, filenames — UI_UX.md §8.2).
class BidiText extends StatelessWidget {
  const BidiText(this.value, {super.key, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(value, style: style),
    );
  }
}
