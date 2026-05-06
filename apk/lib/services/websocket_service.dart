import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _pingTimer;
  bool _connected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    if (_connected) return;

    final client = ApiClient();
    final token = client.token;
    if (token == null || token.isEmpty) return;

    final wsUrl = client.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/messages?token=$token'),
      );

      _connected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              _messageController.add(decoded);
            } else if (decoded is Map) {
              _messageController.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _pingTimer?.cancel();
        },
        onError: (_) {
          _connected = false;
          _pingTimer?.cancel();
        },
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _connected = false;
          _pingTimer?.cancel();
        }
      });
    } catch (_) {
      _connected = false;
    }
  }

  void disconnect() {
    _connected = false;
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
