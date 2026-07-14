import 'package:flutter/widgets.dart';

/// Horizontal inset that centers content of [maxWidth] at [contentMaxWidth];
/// zero once it fits, so rows stop stretching across a wide surface. Prefer
/// this constraint-based form when the widget may live inside an already
/// clamped box (e.g. a bottom sheet), where screen width would over-inset.
double wideInsetForWidth(double maxWidth, {double contentMaxWidth = 720}) =>
    maxWidth > contentMaxWidth ? (maxWidth - contentMaxWidth) / 2 : 0;

/// Horizontal inset that centers full-width list content at [contentMaxWidth]
/// on tablets/landscape; zero on phones, so rows stop stretching across the
/// whole screen.
double wideListInset(BuildContext context, {double contentMaxWidth = 720}) =>
    wideInsetForWidth(
      MediaQuery.sizeOf(context).width,
      contentMaxWidth: contentMaxWidth,
    );
