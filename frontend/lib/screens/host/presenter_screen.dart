import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/slide_model.dart';
import '../../services/socket_service.dart';
import 'lobby_screen.dart';

class PresenterScreen extends StatefulWidget {
  final String roomPin;
  final List<SlideModel> slides;

  const PresenterScreen({
    super.key,
    required this.roomPin,
    required this.slides,
  });

  @override
  State<PresenterScreen> createState() => _PresenterScreenState();
}

class _PresenterScreenState extends State<PresenterScreen>
    with SingleTickerProviderStateMixin {
  int currentSlideIndex = 0;
  int timeLeft = 0;
  Timer? timer;

  List<dynamic> leaderboard = [];
  Map<String, int> answerCounts = {};
  List<Map<String, dynamic>> qaQuestions = [];
  String? spotlightedQaId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    SocketService.listenLeaderboard((data) {
      setState(() => leaderboard = data);
    });

    // Note: the host drives slide advancement directly via nextSlide().
    // We do NOT listen for 'slide-advanced' here to avoid double-advancing
    // when the host's own next-slide emit echoes back.

    SocketService.listenAnswerAggregate((counts) {
      setState(() => answerCounts = counts);
    });

    SocketService.listenQaQuestion((q) {
      setState(() {
        qaQuestions.add(q);
      });
      _tabController.animateTo(2);
    });

    SocketService.listenQaSpotlighted((id) {
      setState(() => spotlightedQaId = id);
    });

    SocketService.listenQaDismissed((id) {
      setState(() {
        if (spotlightedQaId == id) spotlightedQaId = null;
        qaQuestions.removeWhere((q) => q['id'] == id);
      });
    });

    sendCurrentSlide();
  }

  void sendCurrentSlide() {
    final slide = widget.slides[currentSlideIndex];

    setState(() {
      answerCounts = {};
      qaQuestions = [];
      spotlightedQaId = null;
    });

    if (slide.type == 'mcq') {
      final nonEmptyOptions =
          slide.options.where((o) => o.trim().isNotEmpty).toList();
      final emptyMap = <String, int>{};
      for (final opt in nonEmptyOptions) {
        emptyMap[opt] = 0;
      }
      setState(() => answerCounts = emptyMap);

      SocketService.sendQuestion(widget.roomPin, {
        'question': slide.content,
        'options': nonEmptyOptions,
        'correctAnswer': slide.correctAnswer,
        'timer': slide.timer,
      });

      SocketService.changeState(widget.roomPin, 'Question');
      startTimer(slide.timer);
      _tabController.animateTo(0);
    } else if (slide.type == 'info') {
      SocketService.changeState(widget.roomPin, 'Lobby');
    } else if (slide.type == 'qa') {
      SocketService.changeState(widget.roomPin, 'Q&A');
      _tabController.animateTo(2);
    }
  }

  void startTimer(int seconds) {
    timer?.cancel();
    setState(() => timeLeft = seconds);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        t.cancel();
        SocketService.changeState(widget.roomPin, 'Leaderboard');
        _tabController.animateTo(1);
      }
    });
  }

  void nextSlide() {
    if (!mounted) return;
    timer?.cancel();

    if (currentSlideIndex < widget.slides.length - 1) {
      setState(() {
        currentSlideIndex++;
        leaderboard = [];
      });
      sendCurrentSlide();
    } else {
      SocketService.changeState(widget.roomPin, 'Leaderboard');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomPin: widget.roomPin,
            slides: widget.slides,
            finalScores: leaderboard,
          ),
        ),
      );
    }
  }

  void _spotlightQuestion(String id) {
    SocketService.spotlightQa(widget.roomPin, id);
    setState(() => spotlightedQaId = id);
  }

  void _dismissQuestion(String id) {
    SocketService.dismissQa(widget.roomPin, id);
    setState(() {
      if (spotlightedQaId == id) spotlightedQaId = null;
      qaQuestions.removeWhere((q) => q['id'] == id);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[currentSlideIndex];
    final isLast = currentSlideIndex == widget.slides.length - 1;

    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.bar_chart),
              text: 'Live Chart',
            ),
            Tab(
              icon: const Icon(Icons.emoji_events),
              text: 'Podium',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: qaQuestions.isNotEmpty,
                label: Text('${qaQuestions.length}'),
                child: const Icon(Icons.question_answer),
              ),
              text: 'Q&A',
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ElevatedButton.icon(
          onPressed: nextSlide,
          icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
          label: Text(
            isLast ? 'Finish Quiz' : 'Next Slide',
            style: const TextStyle(fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast ? Colors.green : Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ),
      body: Column(
        children: [
          _SlideHeader(
            roomPin: widget.roomPin,
            slide: slide,
            currentIndex: currentSlideIndex,
            totalSlides: widget.slides.length,
            timeLeft: timeLeft,
          ),

          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LiveBarChart(
                  options: slide.type == 'mcq' ? slide.options : [],
                  counts: answerCounts,
                  correctAnswer: slide.correctAnswer,
                ),

                _LeaderboardPodium(leaderboard: leaderboard),

                _QaGrid(
                  questions: qaQuestions,
                  spotlightedId: spotlightedQaId,
                  onSpotlight: _spotlightQuestion,
                  onDismiss: _dismissQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideHeader extends StatelessWidget {
  final String roomPin;
  final SlideModel slide;
  final int currentIndex;
  final int totalSlides;
  final int timeLeft;

  const _SlideHeader({
    required this.roomPin,
    required this.slide,
    required this.currentIndex,
    required this.totalSlides,
    required this.timeLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PIN: $roomPin',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Slide ${currentIndex + 1} / $totalSlides',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (slide.type == 'mcq')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: timeLeft <= 5 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$timeLeft s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
          if (slide.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              slide.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (slide.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              slide.content,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}


class _LiveBarChart extends StatelessWidget {
  final List<String> options;
  final Map<String, int> counts;
  final String correctAnswer;

  const _LiveBarChart({
    required this.options,
    required this.counts,
    required this.correctAnswer,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Chart available during MCQ slides',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b).clamp(1, 999999);

    final barColors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Live Responses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      '$total response${total == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                final count = counts[opt] ?? 0;
                final pct = total == 0 ? 0.0 : count / total;
                final barFill = count / maxCount;
                final isCorrect = opt == correctAnswer;
                final color = barColors[i % barColors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isCorrect
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isCorrect)
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$count  (${(pct * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _AnimatedBar(
                          fill: barFill,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}


class _LeaderboardPodium extends StatelessWidget {
  final List<dynamic> leaderboard;

  const _LeaderboardPodium({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    if (leaderboard.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Podium appears after answers come in',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final top3 = leaderboard.take(3).toList();
    final rest = leaderboard.skip(3).toList();

    final podiumOrder = <int>[];
    if (top3.length >= 2) podiumOrder.add(1);
    if (top3.isNotEmpty) podiumOrder.add(0);
    if (top3.length >= 3) podiumOrder.add(2);

    const podiumHeights = [100.0, 140.0, 80.0];
    const podiumColors = [
      Color(0xFFB0BEC5),
      Color(0xFFFFD700),
      Color(0xFFCD7F32),
    ];
    const rankLabels = ['2nd', '1st', '3rd'];
    const medalIcons = ['🥈', '🥇', '🥉'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Leaderboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: podiumOrder.asMap().entries.map((entry) {
                final podiumSlot = entry.key;
                final playerIdx = entry.value;
                final player = top3[playerIdx];
                final nickname = player['nickname'] ?? '';
                final score = player['score'] ?? 0;
                final height = podiumHeights[podiumSlot];
                final color = podiumColors[podiumSlot];
                final label = rankLabels[podiumSlot];
                final medal = medalIcons[podiumSlot];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$score pts',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        width: 90,
                        height: height,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          if (rest.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            ...rest.asMap().entries.map((entry) {
              final rank = entry.key + 4;
              final user = entry.value;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade300,
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(user['nickname'] ?? ''),
                trailing: Text(
                  '${user['score']} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}


class _QaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final String? spotlightedId;
  final void Function(String id) onSpotlight;
  final void Function(String id) onDismiss;

  const _QaGrid({
    required this.questions,
    required this.spotlightedId,
    required this.onSpotlight,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.question_answer_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No questions yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Audience questions will appear here during Q&A slides',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final spotlighted = spotlightedId != null
        ? questions.firstWhere(
            (q) => q['id'] == spotlightedId,
            orElse: () => {},
          )
        : null;

    return Column(
      children: [
        if (spotlighted != null && spotlighted.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'SPOTLIGHTED',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onDismiss(spotlighted['id']),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  spotlighted['text'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '— ${spotlighted['nickname'] ?? 'Anonymous'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              final id = q['id'] as String? ?? '';
              final isSpotlighted = id == spotlightedId;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSpotlighted
                      ? Colors.purple.shade50
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSpotlighted
                        ? Colors.purple
                        : Colors.grey.shade300,
                    width: isSpotlighted ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.deepPurple.shade100,
                            child: Text(
                              (q['nickname'] as String? ?? 'A')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              q['nickname'] ?? 'Anonymous',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSpotlighted)
                            const Icon(Icons.star,
                                color: Colors.amber, size: 14),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          q['text'] ?? '',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSpotlighted
                                  ? null
                                  : () => onSpotlight(id),
                              icon: const Icon(Icons.star_outline, size: 14),
                              label: const Text(
                                'Spotlight',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4),
                                foregroundColor: Colors.purple,
                                side: const BorderSide(color: Colors.purple),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => onDismiss(id),
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: 'Dismiss',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class _AnimatedBar extends StatefulWidget {
  final double fill;
  final Color color;

  const _AnimatedBar({required this.fill, required this.color});

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar> {
  double _previousFill = 0;

  @override
  void didUpdateWidget(_AnimatedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousFill = oldWidget.fill;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _previousFill, end: widget.fill),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 28,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(widget.color),
        );
      },
    );
  }
}
