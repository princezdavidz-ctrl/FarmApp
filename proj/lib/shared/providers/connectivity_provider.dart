import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline, unknown }

ConnectivityStatus _statusFrom(List<ConnectivityResult> results) =>
    results.every((result) => result == ConnectivityResult.none)
    ? ConnectivityStatus.offline
    : ConnectivityStatus.online;

final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) async* {
  yield _statusFrom(await Connectivity().checkConnectivity());
  yield* Connectivity().onConnectivityChanged.map(_statusFrom);
});
