import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'slide_creator_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController roomController = TextEditingController();
  String roomPin = '';
  String hostMessage = '';

  @override
  void dispose() {
    roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                hintText: 'Enter Room Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (roomController.text.trim().isEmpty) {
                  setState(() => hostMessage = 'Enter room name');
                  return;
                }
                final response =
                    await ApiService.createRoom(roomController.text);
                if (response['success'] == true) {
                  roomPin = response['room']['pin'];
                  SocketService.joinRoomAsHost(roomPin);
                  setState(() => hostMessage = 'Room Created');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SlideCreatorScreen(roomPin: roomPin),
                    ),
                  );
                } else {
                  setState(() => hostMessage =
                      response['message'] ?? 'Room creation failed');
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(15),
                child: Text('Create Room', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                hostMessage,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                roomPin.isEmpty ? '' : 'Room PIN : $roomPin',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
