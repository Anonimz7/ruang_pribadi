import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../providers/settings_provider.dart';
import '../providers/quiz_provider.dart';
import 'quiz_screen.dart';
import 'final_result_screen.dart';

class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final quiz = Provider.of<QuizProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    List<Question> currentSession = quiz.sessions[quiz.currentSessionIndex];
    int correctCount = currentSession.where((q) => q.isCorrect).length;
    int sessionScore = ((correctCount * 100) / currentSession.length).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Sesi"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Skor Sesi: $sessionScore",
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              "Rata-rata Waktu: ${quiz.currentSessionAverageTime.toStringAsFixed(2)} detik per soal",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text("Riwayat Soal:", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: currentSession.length,
                itemBuilder: (context, index) {
                  Question q = currentSession[index];
                  return ListTile(
                    title: Text(q.questionText),
                    subtitle: Text(
                        "Jawaban Anda: ${q.timedOut ? 'Kehabisan waktu' : q.userAnswer.toString()} | Jawaban Benar: ${q.correctAnswer}"),
                    trailing: Icon(
                      q.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: q.isCorrect ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    quiz.restartSession(settings);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    );
                  },
                  child: const Text("Ulang"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (quiz.currentSessionIndex < quiz.sessions.length - 1) {
                      quiz.nextSession(settings);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const QuizScreen()),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FinalResultScreen()),
                      );
                    }
                  },
                  child: const Text("Lanjut"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
