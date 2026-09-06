import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class RoomSocket {
  WebSocketChannel? _channel;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect({
    required String code,
    required String userId,
    required String name,
    required bool isHost,
  }) {
    final wsBase = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    _channel = WebSocketChannel.connect(Uri.parse('$wsBase/api/v1/rooms/$code/ws'));
    await _channel!.ready;
    _channel!.stream.listen(
      (raw) {
        try {
          _events.add(jsonDecode(raw as String) as Map<String, dynamic>);
        } catch (_) {}
      },
      onError: (Object error) => _events.add({'type': 'socket.error', 'message': '$error'}),
      onDone: () => _events.add({'type': 'socket.closed'}),
    );
    send('member.join', {'userId': userId, 'name': name, 'isHost': isHost});
  }

  void send(String type, Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode({'type': type, 'payload': payload, 'sentAt': DateTime.now().millisecondsSinceEpoch}));
  }

  void play(double seconds) => send('sync.play', {'position': seconds});
  void pause(double seconds) => send('sync.pause', {'position': seconds});
  void seek(double seconds) => send('sync.seek', {'position': seconds});
  void chat(String text) => send('chat.message', {'text': text});
  void reaction(String emoji) => send('reaction', {'emoji': emoji});

  Future<void> close() async {
    await _channel?.sink.close();
    await _events.close();
  }
}
