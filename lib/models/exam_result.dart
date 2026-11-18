/// نتيجة امتحان واحدة تُحفظ محلياً
class ExamResult {
  final int id;
  final DateTime dateTime;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int unanswered;
  final double percentage;
  final int timeSpentSeconds;
  final bool immediateFeedback;
  final List<int> questionIds; // معرفات الأسئلة التي ظهرت

  ExamResult({
    required this.id,
    required this.dateTime,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.unanswered,
    required this.percentage,
    required this.timeSpentSeconds,
    required this.immediateFeedback,
    required this.questionIds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'unanswered': unanswered,
        'percentage': percentage,
        'timeSpentSeconds': timeSpentSeconds,
        'immediateFeedback': immediateFeedback,
        'questionIds': questionIds,
      };

  factory ExamResult.fromJson(Map<String, dynamic> json) => ExamResult(
        id: json['id'],
        dateTime: DateTime.parse(json['dateTime']),
        totalQuestions: json['totalQuestions'],
        correctAnswers: json['correctAnswers'],
        wrongAnswers: json['wrongAnswers'],
        unanswered: json['unanswered'],
        percentage: json['percentage'].toDouble(),
        timeSpentSeconds: json['timeSpentSeconds'],
        immediateFeedback: json['immediateFeedback'],
        questionIds: List<int>.from(json['questionIds'] ?? []),
      );
}
