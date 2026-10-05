import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../data/authenticated_api_client.dart';
import '../data/session_token_store.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final instance = PresenceService._();

  io.Socket? _socket;
  bool _started = false;
  final _chatMessages = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageUpdates =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatTyping = StreamController<Map<String, dynamic>>.broadcast();
  final _chatReadReceipts = StreamController<Map<String, dynamic>>.broadcast();
  final _chatRequestUpdates =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get chatMessages => _chatMessages.stream;
  Stream<Map<String, dynamic>> get chatMessageUpdates =>
      _chatMessageUpdates.stream;
  Stream<Map<String, dynamic>> get chatTyping => _chatTyping.stream;
  Stream<Map<String, dynamic>> get chatReadReceipts => _chatReadReceipts.stream;
  Stream<Map<String, dynamic>> get chatRequestUpdates =>
      _chatRequestUpdates.stream;

  Future<void> start() async {
    if (_started) return;
    final token = await SessionTokenStore().read(
      AuthenticatedApiClient.accessTokenKey,
    );
    if (token == null || token.isEmpty) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://hexora.dev',
    );
    _socket =
        io.io(
            baseUrl,
            io.OptionBuilder()
                .setTransports(['websocket'])
                .setAuth({'token': token})
                .disableAutoConnect()
                .enableReconnection()
                .build(),
          )
          ..on('chat:message', (value) {
            if (value is Map) {
              _chatMessages.add(Map<String, dynamic>.from(value));
            }
          })
          ..on('chat:message_updated', (value) {
            if (value is Map) {
              _chatMessageUpdates.add(Map<String, dynamic>.from(value));
            }
          })
          ..on('chat:typing', (value) {
            if (value is Map) {
              _chatTyping.add(Map<String, dynamic>.from(value));
            }
          })
          ..on('chat:read', (value) {
            if (value is Map) {
              _chatReadReceipts.add(Map<String, dynamic>.from(value));
            }
          })
          ..on('chat:request_updated', (value) {
            if (value is Map) {
              _chatRequestUpdates.add(Map<String, dynamic>.from(value));
            }
          })
          ..connect();
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('chat:typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
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
