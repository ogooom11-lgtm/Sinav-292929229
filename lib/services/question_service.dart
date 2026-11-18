import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:exam_app/models/question_model.dart';

/// خدمة تحميل وإدارة بنك الأسئلة من ملف JSON
class QuestionService {
  static List<QuestionModel> _allQuestions = [];
  static bool _isLoaded = false;

  /// تحميل الأسئلة من ملف الأصول
  static Future<List<QuestionModel>> loadQuestions() async {
    if (_isLoaded && _allQuestions.isNotEmpty) return _allQuestions;

    final String jsonString = await rootBundle
        .loadString('assets/questions/question_bank.json');
    final Map<String, dynamic> data = json.decode(jsonString);

    final List<dynamic> lessons = data['lessons'];
    for (var lessonJson in lessons) {
      final List<dynamic> questions = lessonJson['questions'];
      for (var qJson in questions) {
        _allQuestions.add(QuestionModel.fromJson(qJson));
      }
    }

    _isLoaded = true;
    return _allQuestions;
  }

  /// جميع الدروس المتاحة (بدون تكرار)
  static List<String> getLessons(List<QuestionModel> questions) {
    final Set<String> lessonSet = {};
    for (var q in questions) {
      lessonSet.add(q.lesson);
    }
    return lessonSet.toList()..sort();
  }

  /// أسئلة درس محدد
  static List<QuestionModel> getQuestionsByLesson(
      List<QuestionModel> questions, String lesson) {
    return questions.where((q) => q.lesson == lesson).toList();
  }

  /// اختيار أسئلة عشوائية للامتحان من جميع الدروس
  static List<QuestionModel> getRandomQuestions(
      List<QuestionModel> questions, int count) {
    if (count >= questions.length) return List.from(questions);
    final shuffled = List<QuestionModel>.from(questions)..shuffle();
    return shuffled.take(count).toList();
  }

  /// خلط خيارات الإجابة لكل سؤال مع Tracking للفهارس
  static List<QuestionModel> shuffleOptions(List<QuestionModel> questions) {
    final result = <QuestionModel>[];
    for (var q in questions) {
      if (q.type == QuestionType.multipleChoice && q.options.isNotEmpty) {
        final indexedOptions = List.generate(
          q.options.length,
          (i) => {'text': q.options[i], 'originalIndex': i},
        );
        indexedOptions.shuffle();
        final newOptions =
            indexedOptions.map((e) => e['text'] as String).toList();
        final correctOriginal = q.correctIndex ?? 0;
        final newCorrectIndex = indexedOptions.indexWhere(
          (e) => e['originalIndex'] == correctOriginal,
        );
        result.add(QuestionModel(
          id: q.id,
          lesson: q.lesson,
          file: q.file,
          type: q.type,
          question: q.question,
          options: newOptions,
          correctIndex: newCorrectIndex,
          correctText: q.correctText,
          leftItems: q.leftItems,
          rightItems: q.rightItems,
          correctPairs: q.correctPairs,
          answer: q.answer,
          explanation: q.explanation,
        ));
      } else {
        result.add(q);
      }
    }
    return result;
  }
}
