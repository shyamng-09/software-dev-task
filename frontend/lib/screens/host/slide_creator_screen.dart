import 'package:flutter/material.dart';

import '../../models/slide_model.dart';
import 'lobby_screen.dart';

class SlideCreatorScreen extends StatefulWidget {
  final String roomPin;

  const SlideCreatorScreen({
    super.key,
    required this.roomPin,
  });

  @override
  State<SlideCreatorScreen> createState() => _SlideCreatorScreenState();
}

class _SlideCreatorScreenState extends State<SlideCreatorScreen> {
  List<SlideModel> slides = [];

  void addSlide() {
    setState(() {
      slides.add(SlideModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'info',
        title: '',
        content: '',
        options: ['', '', '', ''],
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              if (slides.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add at least one slide')),
                );
                return;
              }
              for (int i = 0; i < slides.length; i++) {
                final s = slides[i];
                if (s.type == 'mcq') {
                  final nonEmpty =
                      s.options.where((o) => o.trim().isNotEmpty).toList();
                  if (nonEmpty.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Slide ${i + 1}: add at least 2 options')),
                    );
                    return;
                  }
                  if (s.correctAnswer.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Slide ${i + 1}: set a correct answer')),
                    );
                    return;
                  }
                  if (!s.options.contains(s.correctAnswer)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Slide ${i + 1}: correct answer must match an option exactly')),
                    );
                    return;
                  }
                }
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LobbyScreen(
                    roomPin: widget.roomPin,
                    slides: slides,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Go to Lobby',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addSlide,
        child: const Icon(Icons.add),
      ),
      body: slides.isEmpty
          ? const Center(child: Text('No Slides Added'))
          : ReorderableListView.builder(
              itemCount: slides.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = slides.removeAt(oldIndex);
                  slides.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final slide = slides[index];
                return _SlideCard(
                  key: ValueKey(slide.id),
                  index: index,
                  slide: slide,
                  onChanged: (updated) {
                    setState(() => slides[index] = updated);
                  },
                  onDelete: () {
                    setState(() => slides.removeAt(index));
                  },
                );
              },
            ),
    );
  }
}

class _SlideCard extends StatefulWidget {
  final int index;
  final SlideModel slide;
  final ValueChanged<SlideModel> onChanged;
  final VoidCallback onDelete;

  const _SlideCard({
    super.key,
    required this.index,
    required this.slide,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_SlideCard> createState() => _SlideCardState();
}

class _SlideCardState extends State<_SlideCard> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final List<TextEditingController> optionControllers;
  late final TextEditingController correctAnswerController;
  late final TextEditingController timerController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.slide.title);
    contentController = TextEditingController(text: widget.slide.content);
    optionControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: widget.slide.options.length > i ? widget.slide.options[i] : '',
      ),
    );
    correctAnswerController =
        TextEditingController(text: widget.slide.correctAnswer);
    timerController = TextEditingController(text: widget.slide.timer.toString());
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
    correctAnswerController.dispose();
    timerController.dispose();
    super.dispose();
  }

  SlideModel get _current => widget.slide;

  void _update({
    String? type,
    String? title,
    String? content,
    List<String>? options,
    String? correctAnswer,
    int? timer,
  }) {
    widget.onChanged(_current.copyWith(
      type: type,
      title: title,
      content: content,
      options: options,
      correctAnswer: correctAnswer,
      timer: timer,
    ));
  }

  List<String> get _currentOptions =>
      optionControllers.map((c) => c.text).toList();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Slide ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
            DropdownButton<String>(
              value: _current.type,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'info', child: Text('Info Slide')),
                DropdownMenuItem(value: 'mcq', child: Text('MCQ')),
                DropdownMenuItem(value: 'qa', child: Text('Q&A')),
              ],
              onChanged: (value) {
                if (value != null) _update(type: value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (value) => _update(title: value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              decoration: InputDecoration(
                labelText: _current.type == 'mcq' ? 'Question' : 'Content',
              ),
              onChanged: (value) => _update(content: value),
            ),
            if (_current.type == 'mcq') ...[
              const SizedBox(height: 10),
              for (int i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: optionControllers[i],
                    decoration:
                        InputDecoration(labelText: 'Option ${i + 1}'),
                    onChanged: (_) => _update(options: _currentOptions),
                  ),
                ),
              TextField(
                controller: correctAnswerController,
                decoration: const InputDecoration(
                  labelText: 'Correct Answer (must match one option exactly)',
                ),
                onChanged: (value) => _update(correctAnswer: value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timerController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Timer (seconds)'),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    _update(timer: parsed);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
