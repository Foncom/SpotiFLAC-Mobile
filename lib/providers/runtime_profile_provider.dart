import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True on low-end hardware (arm32-only or low-RAM, resolved at startup in
/// main.dart via a ProviderScope override). UI uses it to skip expensive
/// effects like the shell's backdrop blur.
final lowEndDeviceProvider = Provider<bool>((ref) => false);
