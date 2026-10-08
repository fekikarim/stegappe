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
    this.onChanged,
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

  /// Live text notifications (e.g. enabling a submit button as the user
  /// types). Optional; existing callers without it are unaffected.
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // T15 · WCAG 4.1.2 (Name, Role, Value): the *actionable* node is the one
    // a screen reader focuses, so that is the node that must carry the name.
    // Declaring `textField: true` here made this wrapper a separate semantic
    // boundary: the wrapper ended up labelled but without actions, while the
    // real editable node underneath was announced unnamed (measured on the
    // app's forms — 300×48 node, `acts=…setValue+tap`, empty label).
    //
    // Without that flag the wrapper merges into the TextField's own node,
    // which keeps the text-field role from the field itself and moves the
    // label onto the node that has the tap/setValue actions. The visible
    // label is excluded from semantics because it is already announced
    // through that merged label — otherwise it would be read twice.
    return Semantics(
      label: semanticsLabel ?? (required ? '$label *' : label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: RichText(
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
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction:
                textInputAction ?? TextInputAction.next,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
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
  const BidiText(
    this.value, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String value;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Isolates an LTR technical value that is *embedded* in a localized
  /// sentence (a reference inside "Période • STG-2026-0001 • …", a filename in
  /// a caption, a value inside a chip). Unicode first-strong-isolate/…/pop
  /// keeps the run readable in RTL without changing the surrounding text
  /// direction, which is what [BidiText] does for a value on its own line.
  static String isolate(String value) => '\u2068$value\u2069';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(value, style: style, maxLines: maxLines, overflow: overflow),
    );
  }
}
