import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Watches the network state so screens can show an offline banner.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> start() async {
    try {
      _apply(await Connectivity().checkConnectivity());
    } catch (_) {}
    try {
      _sub = Connectivity().onConnectivityChanged.listen(_apply);
    } catch (_) {}
  }

  void _apply(List<ConnectivityResult> results) {
    isOnline.value = results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _sub?.cancel();
    isOnline.dispose();
  }
}
