import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/quiz_provider.dart';
import '../widgets/keypad.dart';
import 'session_result_screen.dart';
import 'final_result_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool navigated = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<QuizProvider>(context, listen: false).startQuestion(settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Consumer<QuizProvider>(
      builder: (context, quiz, child) {
        if (quiz.currentQuestionIndex ==
                quiz.sessions[quiz.currentSessionIndex].length - 1 &&
            quiz.remainingTime == 0 &&
            !navigated) {
          navigated = true;
          final navigator = Navigator.of(context);
          Future.microtask(() {
            if (!mounted) return;
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const SessionResultScreen()),
            );
          });
        }
        if (quiz.isQuizFinished && !navigated) {
          navigated = true;
          final navigator = Navigator.of(context);
          Future.microtask(() {
            if (!mounted) return;
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const FinalResultScreen()),
            );
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
                "Sesi ${quiz.currentSessionIndex + 1} dari ${quiz.sessions.length} - Soal ${quiz.currentQuestionIndex + 1} dari ${quiz.sessions[quiz.currentSessionIndex].length}"),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Waktu tersisa: ${quiz.remainingTime} detik",
                  style: TextStyle(
                    fontSize: 20,
                    color: quiz.remainingTime <= 3
                        ? Colors.red
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Text(
                      quiz.currentQuestion.questionText,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Text(
                  quiz.currentAnswer,
                  style: const TextStyle(fontSize: 32, color: Colors.blue),
                ),
                const SizedBox(height: 16),
                Keypad(keyboardSize: settings.keyboardSize),
              ],
            ),
          ),
        );
      },
    );
  }
}
