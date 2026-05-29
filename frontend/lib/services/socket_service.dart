import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config.dart';

class SocketService {
  static late IO.Socket socket;

  static void connect() {
    socket = IO.io(
      AppConfig.serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();
    socket.onConnect((_) => print('SOCKET CONNECTED'));
    socket.onDisconnect((_) => print('SOCKET DISCONNECTED'));
  }

  static void joinRoom(String pin, {String nickname = ''}) {
    socket.emit('join-room', {'pin': pin, 'nickname': nickname});
  }

  static void joinRoomAsHost(String pin) {
    socket.emit('host-join', {'pin': pin});
  }

  static void changeState(String pin, String state) {
    socket.emit('change-state', {'pin': pin, 'state': state});
  }

  static void listenState(Function(String) callback) {
    socket.off('state-changed');
    socket.on('state-changed', (state) => callback(state));
  }

  static void sendQuestion(String pin, Map<String, dynamic> question) {
    socket.emit('start-question', {'pin': pin, 'question': question});
  }

  static void listenQuestion(Function(Map<String, dynamic>) callback) {
    socket.off('question-started');
    socket.on('question-started', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  static void submitAnswer(String pin, String answer) {
    socket.emit('submit-answer', {'pin': pin, 'answer': answer});
  }

  static void listenAnswerResult(Function(Map<String, dynamic>) callback) {
    socket.off('answer-result');
    socket.on('answer-result', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  static void listenLeaderboard(Function(List<dynamic>) callback) {
    socket.off('leaderboard');
    socket.on('leaderboard', (data) => callback(data));
  }

  static void listenUsers(Function(List<Map<String, dynamic>>) callback) {
    socket.off('participants-updated');
    socket.on('participants-updated', (data) {
      callback(List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e)),
      ));
    });
  }

  static void kickUser(String pin, String nickname) {
    socket.emit('kick-user', {'pin': pin, 'nickname': nickname});
  }

  static void nextSlide(String pin) {
    socket.emit('next-slide', {'pin': pin});
  }

  static void resetScores(String pin) {
    socket.emit('reset-scores', {'pin': pin});
  }

  static void listenError(Function(String) callback) {
    socket.off('error-message');
    socket.on('error-message', (msg) => callback(msg.toString()));
  }

  static void listenJoined(Function(Map<String, dynamic>) callback) {
    socket.off('joined-successfully');
    socket.on('joined-successfully', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  static void listenSlideAdvanced(Function() callback) {
    socket.off('slide-advanced');
    socket.on('slide-advanced', (_) => callback());
  }

  static void listenKicked(Function() callback) {
    socket.off('kicked');
    socket.on('kicked', (_) => callback());
  }

  static void submitQaQuestion(String pin, String nickname, String text) {
    socket.emit('submit-qa', {'pin': pin, 'nickname': nickname, 'text': text});
  }

  static void listenQaQuestion(Function(Map<String, dynamic>) callback) {
    socket.off('qa-question-received');
    socket.on('qa-question-received', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  static void spotlightQa(String pin, String questionId) {
    socket.emit('spotlight-qa', {'pin': pin, 'questionId': questionId});
  }

  static void dismissQa(String pin, String questionId) {
    socket.emit('dismiss-qa', {'pin': pin, 'questionId': questionId});
  }

  static void listenQaSpotlighted(Function(String) callback) {
    socket.off('qa-spotlighted');
    socket.on('qa-spotlighted', (data) {
      callback(data['questionId']?.toString() ?? '');
    });
  }

  static void listenQaDismissed(Function(String) callback) {
    socket.off('qa-dismissed');
    socket.on('qa-dismissed', (data) {
      callback(data['questionId']?.toString() ?? '');
    });
  }

  static void listenAnswerAggregate(Function(Map<String, int>) callback) {
    socket.off('answer-aggregate');
    socket.on('answer-aggregate', (data) {
      final map = Map<String, dynamic>.from(data);
      final counts = map.map((k, v) => MapEntry(k, (v as num).toInt()));
      callback(counts);
    });
  }
}
