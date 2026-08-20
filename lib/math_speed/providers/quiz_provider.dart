import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/arithmetic_operation.dart';
import '../models/question.dart';
import 'settings_provider.dart';

class QuizProvider extends ChangeNotifier {
  List<List<Question>> sessions = [];
  int currentSessionIndex = 0;
  int currentQuestionIndex = 0;
  int totalScore = 0;
  late DateTime questionStartTime;
  Timer? timer;
  int remainingTime = 0;
  String currentAnswer = "";
  int totalSessions = 0;

  late ArithmeticOperation currentOperation;
  Set<String> globalGeneratedQuestions = {};

  bool get hasPendingSession => sessions.isNotEmpty && !isQuizFinished;

  void startNewQuiz(SettingsProvider settings) {
    sessions = [];
    currentSessionIndex = 0;
    currentQuestionIndex = 0;
    totalScore = 0;
    globalGeneratedQuestions = {};
    currentOperation = settings.selectedOperation;
    totalSessions = (100 / settings.questionsPerSession).ceil();
    for (int i = 0; i < totalSessions; i++) {
      sessions.add(_generateSession(settings));
    }
    notifyListeners();
  }

  List<Question> _generateSession(SettingsProvider settings) {
    List<Question> questions = [];
    Random rnd = Random();
    while (questions.length < settings.questionsPerSession) {
      Question q = _generateQuestion(settings.selectedOperation, rnd);
      if (!globalGeneratedQuestions.contains(q.questionText)) {
        globalGeneratedQuestions.add(q.questionText);
        questions.add(q);
      }
    }
    return questions;
  }

  Question _generateQuestion(ArithmeticOperation op, Random rnd) {
    int a = rnd.nextInt(10) + 1;
    int b = rnd.nextInt(10) + 1;
    String text = "";
    num answer = 0;
    switch (op) {
      case ArithmeticOperation.addition:
        text = "$a + $b";
        answer = a + b;
        break;
      case ArithmeticOperation.subtraction:
        int r = rnd.nextInt(10);
        int s = rnd.nextInt(10) + 1;
        int sumVal = r + s;
        text = "$sumVal - $s";
        answer = r;
        break;
      case ArithmeticOperation.multiplication:
        text = "$a × $b";
        answer = a * b;
        break;
      case ArithmeticOperation.division:
        text = "${a * b} ÷ $b";
        answer = a;
        break;
    }
    return Question(questionText: text, correctAnswer: answer);
  }

  Question get currentQuestion =>
      sessions[currentSessionIndex][currentQuestionIndex];

  void startQuestion(SettingsProvider settings) {
    currentAnswer = "";
    remainingTime = settings.questionTime;
    questionStartTime = DateTime.now();
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingTime--;
      if (remainingTime <= 0) {
        submitAnswer(timeout: true, settings: settings);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void addDigit(String digit) {
    currentAnswer += digit;
    notifyListeners();
  }

  void deleteDigit() {
    if (currentAnswer.isNotEmpty) {
      currentAnswer = currentAnswer.substring(0, currentAnswer.length - 1);
      notifyListeners();
    }
  }

  void submitAnswer(
      {bool timeout = false, required SettingsProvider settings}) {
    timer?.cancel();
    double timeTaken = settings.questionTime - remainingTime.toDouble();
    Question q = currentQuestion;
    q.timeTaken = timeTaken;
    if (!timeout && currentAnswer.isNotEmpty) {
      q.userAnswer = num.tryParse(currentAnswer) ?? 0;
      q.isCorrect = (q.userAnswer == q.correctAnswer);
      if (q.isCorrect) totalScore++;
    } else {
      q.userAnswer = num.tryParse(currentAnswer) ?? 0;
      q.isCorrect = false;
      if (timeout) q.timedOut = true;
    }
    if (currentQuestionIndex < sessions[currentSessionIndex].length - 1) {
      currentQuestionIndex++;
      startQuestion(settings);
    } else {
      timer?.cancel();
      remainingTime = 0;
      notifyListeners();
    }
  }

  double get currentSessionAverageTime {
    List<Question> qs = sessions[currentSessionIndex];
    if (qs.isEmpty) return 0;
    double total = qs.fold(0.0, (prev, q) => prev + q.timeTaken);
    return total / qs.length;
  }

  double get overallAverageTime {
    List<Question> all = sessions.expand((s) => s).toList();
    if (all.isEmpty) return 0;
    double total = all.fold(0.0, (prev, q) => prev + q.timeTaken);
    return total / all.length;
  }

  void nextSession(SettingsProvider settings) {
    if (currentSessionIndex < sessions.length - 1) {
      currentSessionIndex++;
      currentQuestionIndex = 0;
      startQuestion(settings);
    }
    notifyListeners();
  }

  void restartSession(SettingsProvider settings) {
    for (var q in sessions[currentSessionIndex]) {
      globalGeneratedQuestions.remove(q.questionText);
    }
    sessions[currentSessionIndex] = _generateSession(settings);
    currentQuestionIndex = 0;
    startQuestion(settings);
    notifyListeners();
  }

  void resetQuiz() {
    sessions = [];
    currentSessionIndex = 0;
    currentQuestionIndex = 0;
    totalScore = 0;
    globalGeneratedQuestions = {};
    timer?.cancel();
    notifyListeners();
  }

  bool get isQuizFinished {
    return sessions.isNotEmpty &&
        (currentSessionIndex == sessions.length - 1) &&
        (currentQuestionIndex == sessions[currentSessionIndex].length - 1) &&
        (remainingTime == 0);
  }
}
