// lib/utils/snackbar_utils.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class SnackbarUtils {
  Timer? _snackbarTimer;

  void _showTopSnackbar(
    BuildContext context,
    String message,
    Color color,
    int seconds,
  ) {
    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: color,
      duration: Duration(seconds: seconds),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(top: 40, left: 10, right: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    _snackbarTimer = Timer(Duration(seconds: seconds), () {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  void showConnectionLost(BuildContext context) {
    _showTopSnackbar(context, 'No internet connection', Colors.red, 5);
  }

  void showConnectionRestored(BuildContext context) {
    _showTopSnackbar(context, 'Internet connection restored', Colors.green, 3);
  }

  void dispose() {
    _snackbarTimer?.cancel();
  }
}

class ConnectivityService {
  final SnackbarUtils snackbarUtils;
  late StreamSubscription<ConnectivityResult> _subscription;

  ConnectivityService({required this.snackbarUtils});

  StreamSubscription<ConnectivityResult> monitorConnection(
    BuildContext context,
    void Function(bool) updateConnectionState,
  ) {
    return _subscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final isConnected = result != ConnectivityResult.none;
      if (isConnected) {
        snackbarUtils.showConnectionRestored(context);
      } else {
        snackbarUtils.showConnectionLost(context);
      }
      updateConnectionState(isConnected);
    });
  }

  void handleNetworkAction(
    BuildContext context,
    bool isConnected,
    VoidCallback action, {
    VoidCallback? onNoConnection,
  }) {
    if (!isConnected) {
      snackbarUtils.showConnectionLost(context);
      onNoConnection?.call();
      return;
    }
    action();
  }

  void dispose() {
    _subscription.cancel();
  }
}
