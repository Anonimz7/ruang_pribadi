/// Model soal.
class Question {
  final String questionText;
  final num correctAnswer;
  num? userAnswer;
  bool isCorrect;
  double timeTaken;
  bool timedOut; // Menandai kehabisan waktu

  Question({
    required this.questionText,
    required this.correctAnswer,
    this.userAnswer,
    this.isCorrect = false,
    this.timeTaken = 0,
    this.timedOut = false,
  });
}
