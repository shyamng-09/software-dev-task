import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController pinController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  String joinMessage = '';
  bool hasJoined = false;
  String currentState = 'Lobby';
  String question = '';
  List<String> options = [];
  String correctAnswer = '';
  int timeLeft = 10;
  Timer? timer;
  bool answered = false;
  int totalScore = 0;
  int earnedScore = 0;
  bool? lastAnswerCorrect;
  List<dynamic> leaderboard = [];

  @override
  void initState() {
    super.initState();

    SocketService.listenState((state) {
      setState(() {
        currentState = state;
        if (state == 'Question') {
          answered = false;
          lastAnswerCorrect = null;
          earnedScore = 0;
        }
      });
    });

    SocketService.listenQuestion((data) {
      int newTimeLeft;
      setState(() {
        question = data['question'] ?? '';
        options = List<String>.from(data['options'] ?? []);
        correctAnswer = data['correctAnswer'] ?? '';
        final timerVal = data['timer'];
        newTimeLeft = (timerVal is int) ? timerVal : 20;
        timeLeft = newTimeLeft;
        currentState = 'Question';
        answered = false;
        lastAnswerCorrect = null;
        earnedScore = 0;
      });
      startTimer(timeLeft);
    });

    SocketService.listenAnswerResult((data) {
      setState(() {
        lastAnswerCorrect = data['correct'] == true;
        earnedScore = data['earnedScore'] ?? 0;
        totalScore = data['totalScore'] ?? totalScore;
      });
    });

    SocketService.listenLeaderboard((data) {
      setState(() => leaderboard = data);
    });

    SocketService.listenError((msg) {
      if (msg == 'Nickname already taken') {
        setState(() {
          joinMessage = 'Nickname already taken in this room';
          hasJoined = false;
        });
      }
    });

    SocketService.listenKicked(() {
      if (!mounted) return;
      setState(() {
        hasJoined = false;
        currentState = 'Lobby';
        joinMessage = 'You were removed by the host';
      });
    });
  }

  void startTimer(int seconds) {
    timer?.cancel();
    setState(() => timeLeft = seconds);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        timer?.cancel();
      }
    });
  }

  void submitAnswer(String answer) {
    if (answered || timeLeft == 0) return;
    setState(() => answered = true);
    timer?.cancel();
    SocketService.submitAnswer(pinController.text.trim(), answer);
  }

  @override
  void dispose() {
    timer?.cancel();
    pinController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasJoined) ...[
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(hintText: 'Enter Nickname'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Enter PIN'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final nickname = nameController.text.trim();
                  final pin = pinController.text.trim();
                  if (nickname.isEmpty || pin.isEmpty) {
                    setState(() => joinMessage = 'Fill all fields');
                    return;
                  }
                  final response = await ApiService.joinRoom(pin);
                  if (response['success'] == true) {
                    SocketService.joinRoom(pin, nickname: nickname);
                    setState(() {
                      hasJoined = true;
                      joinMessage = 'Joined successfully';
                      currentState = 'Lobby';
                    });
                  } else {
                    setState(() {
                      joinMessage = response['message'] ?? 'Room not found';
                    });
                  }
                },
                child: const Text('Join Room'),
              ),
              const SizedBox(height: 20),
              if (joinMessage.isNotEmpty)
                Center(
                  child: Text(
                    joinMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: joinMessage.contains('success')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
            ],
            if (hasJoined && currentState == 'Lobby')
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Waiting for host to start the game...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasJoined && currentState == 'Starting')
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Text(
                        'Get Ready!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'The game is starting...',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasJoined && currentState == 'Question') ...[
              Text(
                '$timeLeft s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              ...options.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed:
                          answered ? null : () => submitAnswer(entry.value),
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              if (answered && lastAnswerCorrect != null) ...[
                Icon(
                  lastAnswerCorrect! ? Icons.check_circle : Icons.cancel,
                  color: lastAnswerCorrect! ? Colors.green : Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 10),
                Text(
                  lastAnswerCorrect!
                      ? 'Correct!  +$earnedScore pts'
                      : 'Wrong!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: lastAnswerCorrect! ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: $totalScore pts',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (answered && lastAnswerCorrect == null)
                const Center(
                  child: Text('Answer submitted!',
                      style: TextStyle(fontSize: 20)),
                ),
            ],
            if (hasJoined && currentState == 'Leaderboard') ...[
              const Text(
                'Leaderboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...leaderboard.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final user = entry.value;
                final isMe =
                    user['nickname'] == nameController.text.trim();
                return Card(
                  color: isMe ? Colors.blue[50] : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey[400]
                              : rank == 3
                                  ? Colors.brown[300]
                                  : null,
                      child: Text('$rank'),
                    ),
                    title: Text(
                      user['nickname'] ?? '',
                      style: TextStyle(
                        fontWeight: isMe
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: Text(
                      '${user['score']} pts',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ],
            if (hasJoined && currentState == 'Q&A')
              _QaSubmitPanel(
                pin: pinController.text.trim(),
                nickname: nameController.text.trim(),
              ),
          ],
        ),
      ),
    );
  }
}

class _QaSubmitPanel extends StatefulWidget {
  final String pin;
  final String nickname;

  const _QaSubmitPanel({required this.pin, required this.nickname});

  @override
  State<_QaSubmitPanel> createState() => _QaSubmitPanelState();
}

class _QaSubmitPanelState extends State<_QaSubmitPanel> {
  final TextEditingController _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    SocketService.submitQaQuestion(widget.pin, widget.nickname, text);
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.question_answer,
              size: 48, color: Colors.deepPurple),
          const SizedBox(height: 12),
          const Text(
            'Open Q&A',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Submit a question for the host',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (!_submitted) ...[
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Submit Question',
                      style: TextStyle(fontSize: 16)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else
            Column(
              children: const [
                Icon(Icons.check_circle, color: Colors.green, size: 48),
                SizedBox(height: 12),
                Text(
                  'Question submitted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'The host may spotlight your question.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
