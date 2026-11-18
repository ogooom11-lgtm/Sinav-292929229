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

  /// حروف العمود (ب) بالترتيب
  static const List<String> matchLetters = [
    'أ',
    'ب',
    'ج',
    'د',
    'هـ',
    'و',
    'ز',
    'ح',
    'ط',
    'ي',
  ];

  /// حرف/رقم العنصر في العمود (ب)
  static String matchLetter(int index) {
    if (index >= 0 && index < matchLetters.length) return matchLetters[index];
    return '${index + 1}';
  }

  /// الأزواج الصحيحة التي تقع فهارسها داخل حدود العمودين
  List<List<int>> get validCorrectPairs => correctPairs
      .where(
        (p) =>
            p.length >= 2 &&
            p[0] >= 0 &&
            p[0] < leftItems.length &&
            p[1] >= 0 &&
            p[1] < rightItems.length,
      )
      .toList();

  /// عدد الأزواج المطلوب ربطها.
  ///
  /// قد يختلف عدد عناصر العمودين (مثال: 4 مقابل 5)، لذلك المطلوب هو
  /// أقل عدد بين العمودين — والعنصر الزائد يبقى بدون مقابل.
  int get matchingRequiredPairs {
    final leftCount = leftItems.length;
    final rightCount = rightItems.length;
    final keyCount = validCorrectPairs.length;

    int columnMin;
    if (leftCount == 0 && rightCount == 0) {
      columnMin = 0;
    } else if (leftCount == 0) {
      columnMin = rightCount;
    } else if (rightCount == 0) {
      columnMin = leftCount;
    } else {
      columnMin = leftCount < rightCount ? leftCount : rightCount;
    }

    if (keyCount == 0) return columnMin;
    if (columnMin == 0) return keyCount;
    return keyCount < columnMin ? keyCount : columnMin;
  }

  /// عدد الأزواج التي ربطها المستخدم بشكل صحيح
  int matchingCorrectCount(List<List<int>> userPairs) {
    var count = 0;
    for (final pair in userPairs) {
      if (pair.length < 2) continue;
      final isRight = correctPairs.any(
        (c) => c.length >= 2 && c[0] == pair[0] && c[1] == pair[1],
      );
      if (isRight) count++;
    }
    return count;
  }

  /// التحقق من صحة أزواج الوصل
  ///
  /// قد يختلف عدد عناصر العمودين (مثال: 4 مقابل 5)، فلا يُشترط ربط
  /// العنصر الزائد، ويكفي ربط الأزواج الصحيحة المطلوبة دون أي ربط خاطئ.
  bool isMatchingCorrect(List<List<int>> userPairs) {
    final key = validCorrectPairs;
    if (userPairs.isEmpty || key.isEmpty) return false;
    final required = matchingRequiredPairs;
    if (userPairs.length < required) return false;
    if (matchingCorrectCount(userPairs) < required) return false;
    // لا يُقبل الجواب إذا ربط المستخدم عنصراً بعنصر خاطئ
    for (final pair in userPairs) {
      if (pair.length < 2) continue;
      final isRight = key.any((c) => c[0] == pair[0] && c[1] == pair[1]);
      if (!isRight) return false;
    }
    return true;
  }

  /// وصف موجز للأزواج الصحيحة (للمراجعة)
  String get matchingAnswerText {
    if (correctPairs.isEmpty) return '';
    return correctPairs
        .where((p) => p.length >= 2)
        .map((p) => '${p[0] + 1} ← ${matchLetter(p[1])}')
        .join('  •  ');
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
