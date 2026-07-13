import 'package:flutter/widgets.dart';

/// Horizontal inset that centers full-width list content at [contentMaxWidth]
/// on tablets/landscape; zero on phones, so rows stop stretching across the
/// whole screen.
double wideListInset(BuildContext context, {double contentMaxWidth = 720}) {
  final width = MediaQuery.sizeOf(context).width;
  return width > contentMaxWidth ? (width - contentMaxWidth) / 2 : 0;
}
