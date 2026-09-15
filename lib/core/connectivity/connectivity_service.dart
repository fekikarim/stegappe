import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current connectivity result list.
final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  final api = Connectivity();
  final controller = StreamController<List<ConnectivityResult>>();
  controller.add([ConnectivityResult.wifi]); // optimistic seed
  void emit() async {
    try {
      controller.add(await api.checkConnectivity());
    } on Exception {
      controller.add([ConnectivityResult.none]);
    }
  }

  emit();
  final sub = api.onConnectivityChanged.listen(controller.add);
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Simple online/offline boolean consumed by the banner + data layers.
/// `none` => offline; anything else => online.
final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityStreamProvider);
  return async.maybeWhen(
    data: (results) => !results.contains(ConnectivityResult.none),
    orElse: () => true,
  );
});
