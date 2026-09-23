import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../data/authenticated_api_client.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final instance = PresenceService._();

  io.Socket? _socket;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    final token = await const FlutterSecureStorage().read(
      key: AuthenticatedApiClient.accessTokenKey,
    );
    if (token == null || token.isEmpty) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://hexora.dev',
    );
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    )..connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _socket?.connect();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _socket?.disconnect();
    }
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _socket = null;
    _started = false;
  }
}
