import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _pingTimer;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect() async {
    final client = ApiClient();
    final token = client.token;
    if (token == null) return;

    final wsUrl =
        client.baseUrl.replaceFirst('http', 'ws').replaceFirst('https', 'wss');
    try {
      _channel = WebSocketChannel.connect(
          Uri.parse('$wsUrl/ws?token=$token'));
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String);
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {},
        onError: (_) {},
      );
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {
          _pingTimer?.cancel();
        }
      });
    } catch (_) {}
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
