import 'package:flutter/material.dart';

import '../../models/slide_model.dart';
import '../../services/socket_service.dart';
import 'presenter_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomPin;
  final List<SlideModel> slides;
  final List<dynamic>? finalScores;

  const LobbyScreen({
    super.key,
    required this.roomPin,
    required this.slides,
    this.finalScores,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  List<Map<String, dynamic>> participants = [];

  bool get _showResults =>
      widget.finalScores != null && widget.finalScores!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    SocketService.listenUsers((data) {
      setState(() => participants = data);
    });
  }

  void kickPlayer(String nickname) {
    SocketService.kickUser(widget.roomPin, nickname);
  }

  void startNewGame() {
    SocketService.changeState(widget.roomPin, 'Starting');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PresenterScreen(
          roomPin: widget.roomPin,
          slides: widget.slides,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _showResults ? _buildResultsView() : _buildLobbyView(),
    );
  }

  Widget _buildResultsView() {
    final scores = widget.finalScores!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Quiz Complete',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Room PIN: ${widget.roomPin}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: scores.length,
              itemBuilder: (context, index) {
                final user = scores[index];
                final rank = index + 1;
                Color? avatarColor;
                if (rank == 1) avatarColor = Colors.amber;
                if (rank == 2) avatarColor = Colors.grey[400];
                if (rank == 3) avatarColor = Colors.brown[300];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: avatarColor,
                      child: Text(
                        '$rank',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      user['nickname'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Text(
                      '${user['score']} pts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: startNewGame,
              icon: const Icon(Icons.replay),
              label: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Play Again', style: TextStyle(fontSize: 18)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(),
            ),
            child: Column(
              children: [
                const Text('ROOM PIN', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  widget.roomPin,
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Participants (${participants.length})',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: participants.isEmpty
                ? const Center(child: Text('Waiting for players...'))
                : ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final nickname = p['nickname'] ?? '';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(nickname),
                          trailing: IconButton(
                            onPressed: () => kickPlayer(nickname),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                SocketService.changeState(widget.roomPin, 'Starting');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PresenterScreen(
                      roomPin: widget.roomPin,
                      slides: widget.slides,
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(15),
                child: Text('Start Game', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
