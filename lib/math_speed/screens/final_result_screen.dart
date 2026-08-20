import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/record_provider.dart';
import 'main_page.dart';

class FinalResultScreen extends StatefulWidget {
  const FinalResultScreen({super.key});
  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  bool newRecordAchieved = false;
  bool recordChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quiz = Provider.of<QuizProvider>(context, listen: false);
      final recordProvider =
          Provider.of<RecordProvider>(context, listen: false);
      bool updated = await recordProvider.updateRecord(
          quiz.currentOperation, quiz.totalScore, quiz.overallAverageTime);
      setState(() {
        newRecordAchieved = updated;
        recordChecked = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = Provider.of<QuizProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Akhir"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (recordChecked && newRecordAchieved)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  "Selamat, anda melampaui rekor sebelumnya!",
                  style: TextStyle(fontSize: 20, color: Colors.green),
                ),
              ),
            Text(
              "Nilai Akhir: ${quiz.totalScore}",
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 16),
            Text(
              "Rata-rata Waktu Keseluruhan: ${quiz.overallAverageTime.toStringAsFixed(2)} detik",
              style: const TextStyle(fontSize: 20),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                quiz.resetQuiz();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainPage()),
                  (route) => false,
                );
              },
              child: const Text("Main Lagi"),
            ),
          ],
        ),
      ),
    );
  }
}
