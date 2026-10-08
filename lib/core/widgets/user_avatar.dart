import 'package:flutter/material.dart';

/// Initials avatar for home headers (T13 ST-HOME-04/SH-PRO-01).
///
/// Initials by default (no uploaded picture exists on any contract);
/// colour comes from the theme so both modes stay legible, and the
/// semantics label always carries the full display name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.radius = 24,
  });

  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: displayName,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
