import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/arithmetic_operation.dart';
import '../providers/settings_provider.dart';
import '../providers/quiz_provider.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    timeController.text = settings.questionTime.toString();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    if (timeController.text != settings.questionTime.toString()) {
      timeController.text = settings.questionTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final quiz = Provider.of<QuizProvider>(context, listen: false);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pilih Operasi Matematika:",
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            DropdownButton<ArithmeticOperation>(
              value: settings.selectedOperation,
              items: ArithmeticOperation.values.map((op) {
                return DropdownMenuItem(
                  value: op,
                  child: Text(opToString(op)),
                );
              }).toList(),
              onChanged: (newOp) {
                if (newOp != null) {
                  QuizProvider quiz =
                      Provider.of<QuizProvider>(context, listen: false);
                  if (quiz.hasPendingSession &&
                      quiz.currentOperation != newOp) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Lanjutkan Quiz?"),
                        content: Text(
                          "Anda telah memulai quiz dengan operasi ${opToString(quiz.currentOperation)}. "
                          "Apakah Anda ingin melanjutkan quiz tersebut atau memulai ulang dengan operasi baru?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Provider.of<SettingsProvider>(context,
                                      listen: false)
                                  .updateSelectedOperation(
                                      quiz.currentOperation);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Lanjutkan"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Provider.of<SettingsProvider>(context,
                                      listen: false)
                                  .updateSelectedOperation(newOp);
                              quiz.resetQuiz();
                              quiz.startNewQuiz(Provider.of<SettingsProvider>(
                                  context,
                                  listen: false));
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Ulang dari awal"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    Provider.of<SettingsProvider>(context, listen: false)
                        .updateSelectedOperation(newOp);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            const Text("Jumlah Soal per Sesi:", style: TextStyle(fontSize: 18)),
            RadioGroup<int>(
              groupValue: settings.questionsPerSession,
              onChanged: (int? val) {
                if (val != null) settings.updateQuestionsPerSession(val);
              },
              child: Row(
                children: [
                  Radio<int>(value: 10),
                  const Text("10 Soal"),
                  Radio<int>(value: 20),
                  const Text("20 Soal"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("Waktu per Soal (detik):",
                style: TextStyle(fontSize: 18)),
            TextField(
              controller: timeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Masukkan waktu (detik)",
              ),
              onChanged: (value) {
                int? time = int.tryParse(value);
                if (time != null && time > 0) settings.updateQuestionTime(time);
              },
            ),
            const SizedBox(height: 16),
            const Text("Ukuran Keyboard PIN:", style: TextStyle(fontSize: 18)),
            DropdownButton<String>(
              value: settings.keyboardSize,
              items: ["small", "medium", "large"].map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text(size.toUpperCase()),
                );
              }).toList(),
              onChanged: (size) {
                if (size != null) settings.updateKeyboardSize(size);
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (quiz.hasPendingSession) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Lanjutkan Quiz?"),
                        content: Text(
                            "Anda sudah menyelesaikan ${quiz.currentSessionIndex} sesi dan sedang mengerjakan sesi ${quiz.currentSessionIndex + 1} dari ${quiz.sessions.length}."),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Lanjutkan"),
                          ),
                          TextButton(
                            onPressed: () {
                              quiz.resetQuiz();
                              quiz.startNewQuiz(settings);
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Ulang dari awal"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    quiz.resetQuiz();
                    quiz.startNewQuiz(settings);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    );
                  }
                },
                child: const Text("Mulai Quiz"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
