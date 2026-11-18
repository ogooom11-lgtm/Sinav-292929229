/// نوع السؤال المدعوم في التطبيق
enum QuestionType {
  multipleChoice,
  trueFalse,
  matching,
  fillInBlank,
}

/// نموذج السؤال الواحد المستخرج من ملفات Word
class QuestionModel {
  final int id;
  final String lesson;
  final String file;
  final QuestionType type;
  final String question; // نص السؤال
  final List<String> options; // خيارات الاختيار من متعدد / صح خطأ
  final int? correctIndex; // فهرس الإجابة الصحيحة في الخيارات
  final String correctText; // نص الإجابة الصحيحة
  final List<String> leftItems; // عناصر العمود أ للوصل
  final List<String> rightItems; // عناصر العمود ب للوصل
  final List<List<int>> correctPairs; // أزواج الوصل الصحيحة [leftIndex, rightIndex]
  final String answer; // إجابة إكمال الفراغ
  final String explanation; // تفسير الإجابة (مستقبلياً)

  QuestionModel({
    required this.id,
    required this.lesson,
    required this.file,
    required this.type,
    required this.question,
    this.options = const [],
    this.correctIndex,
    this.correctText = '',
    this.leftItems = const [],
    this.rightItems = const [],
    this.correctPairs = const [],
    this.answer = '',
    this.explanation = '',
  });

  /// إنشاء من JSON
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] ?? 0,
      lesson: json['lesson'] ?? '',
      file: json['file'] ?? '',
      type: _parseType(json['type']),
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'],
      correctText: json['correct_text'] ?? '',
      leftItems: List<String>.from(json['left_items'] ?? []),
      rightItems: List<String>.from(json['right_items'] ?? []),
      correctPairs: (json['correct_pairs'] as List?)
          ?.map((e) => List<int>.from(e))
          .toList() ??
          [],
      answer: json['answer'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }

  static QuestionType _parseType(String? type) {
    switch (type) {
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'matching':
        return QuestionType.matching;
      case 'fill_in_blank':
        return QuestionType.fillInBlank;
      default:
        return QuestionType.multipleChoice;
    }
  }

  /// التحقق من صحة الإجابة للمتعدد أو صح/خطأ
  bool isCorrect(int selectedIndex) {
    return correctIndex != null && selectedIndex == correctIndex;
  }

  /// التحقق من صحة الإجابة لإكمال الفراغ
  bool isFillCorrect(String userAnswer) {
    return answer.trim().toLowerCase() == userAnswer.trim().toLowerCase();
  }

  /// التحقق من صحة أزواج الوصل
  bool isMatchingCorrect(List<List<int>> userPairs) {
    if (userPairs.length != correctPairs.length) return false;
    // مقارنة irrespective of order
    final sortedCorrect = List<List<int>>.from(correctPairs)
      ..sort((a, b) => a[0].compareTo(b[0]));
    final sortedUser = List<List<int>>.from(userPairs)
      ..sort((a, b) => a[0].compareTo(b[0]));
    for (int i = 0; i < sortedCorrect.length; i++) {
      if (sortedCorrect[i][0] != sortedUser[i][0] ||
          sortedCorrect[i][1] != sortedUser[i][1]) {
        return false;
      }
    }
    return true;
  }

  /// عرض نوع السؤال باللغة العربية
  String get typeLabel {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صح أو خطأ';
      case QuestionType.matching:
        return 'وصل';
      case QuestionType.fillInBlank:
        return 'أكمل الفراغ';
    }
  }

  /// أيقونة نوع السؤال
  String get typeIcon {
    switch (type) {
      case QuestionType.multipleChoice:
        return '📋';
      case QuestionType.trueFalse:
        return '✅❌';
      case QuestionType.matching:
        return '🔗';
      case QuestionType.fillInBlank:
        return '✏️';
    }
  }
}
