import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/services/app_navigation_service.dart';
import 'package:spotiflac_android/services/platform_bridge.dart';
import 'package:spotiflac_android/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = AppLogger('ExtensionAuthLauncher');

bool isExtensionVerificationRequired(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('verify_required') ||
      message.contains('verification_required') ||
      message.contains('verification required') ||
      message.contains('needsverification') ||
      message.contains('needs verification') ||
      message.contains('session is not authenticated') ||
      message.contains('unauthorized') ||
      message.contains('precondition required') ||
      _containsHttpStatusCode(message, '401') ||
      _containsHttpStatusCode(message, '428');
}

bool _containsHttpStatusCode(String message, String code) {
  return message.contains('http $code') ||
      message.contains('http status $code') ||
      message.contains('status $code') ||
      message.contains('$code for ') ||
      message.contains('$code:') ||
      message.contains('$code;');
}

Future<bool> openPendingExtensionVerification(
  String extensionId, {
  String browserMode = 'in_app_first',
  void Function(Uri authUri)? onAuthUri,
}) async {
  final normalizedExtensionId = extensionId.trim();
  if (normalizedExtensionId.isEmpty) return false;

  try {
    final pending = await PlatformBridge.getExtensionPendingAuth(
      normalizedExtensionId,
    );
    final authUrl = pending?['auth_url']?.toString().trim() ?? '';
    if (authUrl.isEmpty) return false;

    final uri = Uri.tryParse(authUrl);
    if (uri == null) return false;
    onAuthUri?.call(uri);

    final launched = await _launchVerificationUrl(uri, browserMode);

    if (launched) {
      _log.i('Opened verification challenge for $normalizedExtensionId');
    } else {
      _log.w(
        'Could not open verification challenge for $normalizedExtensionId',
      );
      return showExtensionVerificationHelpDialog(
        normalizedExtensionId,
        uri,
        browserMode: browserMode,
        immediateFailure: true,
      );
    }
    return launched;
  } catch (e) {
    _log.w(
      'Failed to open verification challenge for $normalizedExtensionId: $e',
    );
    return false;
  }
}

Timer? scheduleExtensionVerificationHelpDialog(
  String extensionId,
  Uri? authUri, {
  String browserMode = 'in_app_first',
  Duration delay = const Duration(seconds: 20),
}) {
  final normalizedExtensionId = extensionId.trim();
  if (normalizedExtensionId.isEmpty || authUri == null) return null;

  return Timer(delay, () {
    unawaited(
      showExtensionVerificationHelpDialog(
        normalizedExtensionId,
        authUri,
        browserMode: browserMode,
      ),
    );
  });
}

Future<bool> showExtensionVerificationHelpDialog(
  String extensionId,
  Uri authUri, {
  String browserMode = 'in_app_first',
  bool immediateFailure = false,
}) async {
  final context = AppNavigationService.rootNavigatorKey.currentContext;
  if (context == null) {
    _log.w('Cannot show verification help dialog without root context');
    return false;
  }

  final l10n = context.l10n;
  final title = immediateFailure
      ? l10n.extensionVerificationHelpTitleManual
      : l10n.extensionVerificationHelpTitleWaiting;
  final message = immediateFailure
      ? l10n.extensionVerificationHelpMessageManual
      : l10n.extensionVerificationHelpMessageWaiting;
  final normalizedExtensionId = extensionId.trim();
  BuildContext? activeDialogContext;
  late final StreamSubscription<ExtensionSessionGrantEvent> grantSub;
  grantSub = PlatformBridge.extensionSessionGrantEvents()
      .where(
        (event) =>
            event.success && event.extensionId.trim() == normalizedExtensionId,
      )
      .listen((_) {
        final dialogContext = activeDialogContext;
        if (dialogContext == null || !dialogContext.mounted) return;
        _log.i(
          'Closing verification help dialog after $normalizedExtensionId grant',
        );
        Navigator.of(dialogContext, rootNavigator: true).pop();
      });

  try {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        activeDialogContext = dialogContext;
        final dialogL10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    authUri.toString(),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogL10n.extensionVerificationClose),
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(dialogL10n.extensionVerificationCopyLink),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: authUri.toString()));
                ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                  SnackBar(
                    content: Text(dialogL10n.extensionVerificationLinkCopied),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste callback'),
              onPressed: () {
                unawaited(
                  _completeSessionGrantFromClipboard(
                    dialogContext,
                    extensionId,
                  ),
                );
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: Text(dialogL10n.extensionVerificationOpenBrowser),
              onPressed: () {
                unawaited(_launchVerificationUrl(authUri, browserMode));
              },
            ),
          ],
        );
      },
    );
  } finally {
    activeDialogContext = null;
    await grantSub.cancel();
  }
  return true;
}

Future<void> _completeSessionGrantFromClipboard(
  BuildContext context,
  String extensionId,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final parsed = _parseSessionGrantCallback(
      text,
      fallbackExtensionId: extensionId,
    );
    if (parsed == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No verification callback found')),
      );
      return;
    }

    final success = await PlatformBridge.completeExtensionSessionGrant(
      parsed.extensionId,
      parsed.grant,
    );
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Verification completed' : 'Verification failed',
        ),
      ),
    );
    if (success) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  } catch (e) {
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('Verification callback failed: $e')),
    );
  }
}

({String extensionId, String grant})? _parseSessionGrantCallback(
  String text, {
  required String fallbackExtensionId,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  String? grant;
  String? state;
  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    grant = uri.queryParameters['grant'] ?? uri.queryParameters['code'];
    state = uri.queryParameters['state'];

    final nestedCallback = uri.queryParameters['cb'];
    if ((grant == null || grant.trim().isEmpty) &&
        nestedCallback != null &&
        nestedCallback.trim().isNotEmpty) {
      final nested = _parseSessionGrantCallback(
        nestedCallback,
        fallbackExtensionId: fallbackExtensionId,
      );
      if (nested != null) return nested;
    }
  }

  grant ??= _firstRegexGroup(trimmed, RegExp(r'(?:^|[?&#\s])grant=([^&#\s]+)'));
  grant ??= _firstRegexGroup(trimmed, RegExp(r'(?:^|[?&#\s])code=([^&#\s]+)'));
  state ??= _firstRegexGroup(trimmed, RegExp(r'(?:^|[?&#\s])state=([^&#\s]+)'));

  grant = grant == null ? null : Uri.decodeComponent(grant.trim());
  state = state == null ? null : Uri.decodeComponent(state.trim());
  final extension = (state != null && state.isNotEmpty)
      ? state
      : fallbackExtensionId.trim();
  if (extension.isEmpty || grant == null || grant.isEmpty) return null;
  return (extensionId: extension, grant: grant);
}

String? _firstRegexGroup(String input, RegExp regex) {
  final match = regex.firstMatch(input);
  return match?.group(1);
}

Future<bool> _launchVerificationUrl(Uri uri, String browserMode) async {
  final preferInApp = browserMode.trim().toLowerCase() == 'in_app_first';
  final firstMode = preferInApp
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication;
  final fallbackMode = preferInApp
      ? LaunchMode.externalApplication
      : LaunchMode.inAppBrowserView;

  var launched = await launchUrl(uri, mode: firstMode);
  if (!launched) {
    launched = await launchUrl(uri, mode: fallbackMode);
  }
  return launched;
}
