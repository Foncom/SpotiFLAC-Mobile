import 'package:flutter/material.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/services/shell_navigation_service.dart';

SnackBarAction buildViewQueueSnackBarAction(BuildContext context) {
  return SnackBarAction(
    label: context.l10n.snackbarViewQueue,
    onPressed: () {
      ShellNavigationService.requestTab(ShellTab.library);
    },
  );
}
