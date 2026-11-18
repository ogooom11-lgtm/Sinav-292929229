import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exam_app/theme/app_theme.dart';
import 'package:exam_app/models/question_model.dart';
import 'package:exam_app/models/app_settings.dart';
import 'package:exam_app/models/exam_result.dart';
import 'package:exam_app/services/question_service.dart';
import 'package:exam_app/services/storage_service.dart';
import 'package:exam_app/screens/result_screen.dart';

class ExamScreen extends StatefulWidget {
  final List<QuestionModel> allQuestions;
  final int questionCount;

  const ExamScreen({
    super.key,
    required this.allQuestions,
    required this.questionCount,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late AppSettings _settings;
  List<QuestionModel> _examQuestions = [];
  int _currentIndex = 0;
  bool _immediateFeedback = true;
  int _timeRemaining = 0;
  Timer? _timer;

  // إجابات المستخدم
  // للمتعدد/صح خطأ: الفهرس المختار (-1 = لم يجب)
  final Map<int, int> _userAnswers = {};
  // لإكمال الفراغ: النص المدخل
  final Map<int, String> _fillAnswers = {};
  // للوصل: قائمة أزواج [leftIndex, rightIndex]
  final Map<int, List<List<int>>> _matchAnswers = {};
  // متحكمات حقول النص لإكمال الفراغ (تُحفظ لحفظ حالة الحقل)
  final Map<int, TextEditingController> _fillControllers = {};

  bool _isAnswered = false;
  bool _showResult = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initExam();
  }

  Future<void> _initExam() async {
    _settings = StorageService.loadSettings();
    _immediateFeedback = _settings.immediateFeedback;

    // اختيار أسئلة عشوائية
    final selected = QuestionService.getRandomQuestions(
      widget.allQuestions,
      widget.questionCount,
    );

    // خلط الخيارات إذا كان مفعلاً
    if (_settings.shuffleOptions) {
      _examQuestions = QuestionService.shuffleOptions(selected);
    } else {
      _examQuestions = selected;
    }

    // إعداد المؤقت
    if (_settings.timeLimitMinutes > 0) {
      _timeRemaining = _settings.timeLimitMinutes * 60;
      _startTimer();
    }

    setState(() => _isLoading = false);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timeRemaining > 0) {
        setState(() => _timeRemaining--);
      } else if (_timeRemaining <= 0) {
        _timer?.cancel();
        _finishExam();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var ctrl in _fillControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  QuestionModel get _currentQuestion => _examQuestions[_currentIndex];

  /// الإجابة المختارة للسؤال الحالي (للمتعدد/صح خطأ)
  int? get _currentSelectedIndex => _userAnswers[_currentQuestion.id];

  /// الإجابة المدخلة لإكمال الفراغ
  String get _currentFillAnswer => _fillAnswers[_currentQuestion.id] ?? '';

  /// أزواج الوصل المختارة
  List<List<int>> get _currentMatchAnswer =>
      _matchAnswers[_currentQuestion.id] ?? [];

  bool get _isLastQuestion => _currentIndex == _examQuestions.length - 1;

  /// التحقق ما إذا تم الإجابة على السؤال الحالي
  bool get _currentIsAnswered {
    switch (_currentQuestion.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        return _currentSelectedIndex != null;
      case QuestionType.fillInBlank:
        return _currentFillAnswer.trim().isNotEmpty;
      case QuestionType.matching:
        return _currentMatchAnswer.length ==
            _currentQuestion.leftItems.length;
    }
  }

  /// جلب متحكم الحقل للسؤال الحالي (يُنشأ مرة واحدة ويُحفظ)
  TextEditingController _getFillController(QuestionModel q) {
    return _fillControllers.putIfAbsent(q.id, () {
      final c = TextEditingController(text: _currentFillAnswer);
      return c;
    });
  }

  void _onOptionSelected(int index) {
    if (_isAnswered && _immediateFeedback) return;
    setState(() {
      _userAnswers[_currentQuestion.id] = index;
      _isAnswered = true;
    });
  }

  void _onFillChanged(String text) {
    setState(() {
      _fillAnswers[_currentQuestion.id] = text;
    });
  }

  bool _checkCurrentAnswer() {
    switch (_currentQuestion.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        return _currentQuestion.isCorrect(_currentSelectedIndex ?? -1);
      case QuestionType.fillInBlank:
        return _currentQuestion.isFillCorrect(_currentFillAnswer);
      case QuestionType.matching:
        return _currentQuestion.isMatchingCorrect(_currentMatchAnswer);
    }
  }

  void _nextQuestion() {
    if (!_immediateFeedback || !_isAnswered) {
      if (_currentIndex < _examQuestions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswered = _currentIsAnswered;
        });
      }
      return;
    }
    // في وضع الرد الفوري، الانتقال للسؤال التالي
    if (_currentIndex < _examQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = _currentIsAnswered;
      });
    } else {
      _finishExam();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isAnswered = _currentIsAnswered;
      });
    }
  }

  void _finishExam() async {
    _timer?.cancel();
    await _saveResult();
  }

  int _getCorrectCount() {
    int correct = 0;
    for (var q in _examQuestions) {
      switch (q.type) {
        case QuestionType.multipleChoice:
        case QuestionType.trueFalse:
          if (_userAnswers[q.id] != null &&
              q.isCorrect(_userAnswers[q.id]!)) correct++;
          break;
        case QuestionType.fillInBlank:
          if (_fillAnswers[q.id] != null &&
              _fillAnswers[q.id]!.trim().isNotEmpty &&
              q.isFillCorrect(_fillAnswers[q.id]!)) correct++;
          break;
        case QuestionType.matching:
          if (_matchAnswers[q.id] != null &&
              q.isMatchingCorrect(_matchAnswers[q.id]!)) correct++;
          break;
      }
    }
    return correct;
  }

  int _getWrongCount() {
    int wrong = 0;
    for (var q in _examQuestions) {
      switch (q.type) {
        case QuestionType.multipleChoice:
        case QuestionType.trueFalse:
          if (_userAnswers[q.id] != null &&
              !q.isCorrect(_userAnswers[q.id]!)) wrong++;
          break;
        case QuestionType.fillInBlank:
          if (_fillAnswers[q.id] != null &&
              _fillAnswers[q.id]!.trim().isNotEmpty &&
              !q.isFillCorrect(_fillAnswers[q.id]!)) wrong++;
          break;
        case QuestionType.matching:
          if (_matchAnswers[q.id] != null &&
              _matchAnswers[q.id]!.isNotEmpty &&
              !q.isMatchingCorrect(_matchAnswers[q.id]!)) wrong++;
          break;
      }
    }
    return wrong;
  }

  int _getUnansweredCount() {
    int unanswered = 0;
    for (var q in _examQuestions) {
      switch (q.type) {
        case QuestionType.multipleChoice:
        case QuestionType.trueFalse:
          if (_userAnswers[q.id] == null) unanswered++;
          break;
        case QuestionType.fillInBlank:
          if (_fillAnswers[q.id] == null ||
              _fillAnswers[q.id]!.trim().isEmpty) unanswered++;
          break;
        case QuestionType.matching:
          if (_matchAnswers[q.id] == null ||
              _matchAnswers[q.id]!.isEmpty) unanswered++;
          break;
      }
    }
    return unanswered;
  }

  Future<void> _saveResult() async {
    final correct = _getCorrectCount();
    final wrong = _getWrongCount();
    final unanswered = _getUnansweredCount();
    final total = _examQuestions.length;
    final percentage = total > 0 ? (correct / total) * 100.0 : 0.0;
    final timeSpent =
        _settings.timeLimitMinutes > 0
            ? (_settings.timeLimitMinutes * 60) - _timeRemaining
            : 0;

    final result = ExamResult(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000).toInt(),
      dateTime: DateTime.now(),
      totalQuestions: total,
      correctAnswers: correct,
      wrongAnswers: wrong,
      unanswered: unanswered,
      percentage: percentage,
      timeSpentSeconds: timeSpent,
      immediateFeedback: _immediateFeedback,
      questionIds: _examQuestions.map((q) => q.id).toList(),
    );

    await StorageService.saveResult(result);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            questions: _examQuestions,
            userAnswers: _userAnswers,
            fillAnswers: _fillAnswers,
            matchAnswers: _matchAnswers,
            timeSpentSeconds: timeSpent,
          ),
        ),
      );
    }
  }

  Widget _buildQuestionWidget() {
    final q = _currentQuestion;
    switch (q.type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoiceWidget(q);
      case QuestionType.trueFalse:
        return _buildTrueFalseWidget(q);
      case QuestionType.matching:
        return _buildMatchingWidget(q);
      case QuestionType.fillInBlank:
        return _buildFillInBlankWidget(q);
    }
  }

  Widget _buildMultipleChoiceWidget(QuestionModel q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(q.options.length, (index) {
        final isSelected = _currentSelectedIndex == index;
        final isCorrect = q.correctIndex == index;
        bool showCorrect = false;
        Color? bgColor;
        Color? borderColor;

        if (_isAnswered && _immediateFeedback) {
          if (isSelected) {
            showCorrect = isCorrect;
            bgColor = isCorrect
                ? AppColors.correctBg
                : AppColors.wrongBg;
            borderColor = isCorrect
                ? AppColors.correctBorder
                : AppColors.wrongBorder;
          } else if (isCorrect) {
            bgColor = AppColors.correctBg;
            borderColor = AppColors.correctBorder;
          }
        } else if (_showResult && !_immediateFeedback) {
          if (isSelected) {
            showCorrect = isCorrect;
            bgColor = isCorrect
                ? AppColors.correctBg
                : AppColors.wrongBg;
            borderColor = isCorrect
                ? AppColors.correctBorder
                : AppColors.wrongBorder;
          } else if (isCorrect) {
            bgColor = AppColors.correctBg;
            borderColor = AppColors.correctBorder;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isAnswered && _immediateFeedback
                  ? null
                  : () => _onOptionSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor ??
                        (isSelected
                            ? AppColors.primary
                            : AppColors.divider),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (showCorrect
                                ? AppColors.success
                                : Colors.transparent),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (showCorrect
                                  ? AppColors.success
                                  : AppColors.divider),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          ['أ', 'ب', 'ج', 'د'][index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        q.options[index],
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (showCorrect)
                      const Icon(Icons.check_circle, color: AppColors.success),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: (index * 60).ms);
      }),
    );
  }

  Widget _buildTrueFalseWidget(QuestionModel q) {
    final correctIdx = q.correctIndex ?? 0;
    return Column(
      children: [
        _buildTFActionOption('صح', 0, q, correctIdx),
        const SizedBox(height: 12),
        _buildTFActionOption('خطأ', 1, q, correctIdx),
      ],
    );
  }

  Widget _buildTFActionOption(
    String text,
    int index,
    QuestionModel q,
    int correctIdx,
  ) {
    final isSelected = _currentSelectedIndex == index;
    final isCorrect = correctIdx == index;
    bool showCorrect = false;
    Color? bgColor;
    Color? borderColor;

    if (_isAnswered && _immediateFeedback) {
      if (isSelected) {
        showCorrect = isCorrect;
        bgColor = isCorrect
            ? AppColors.correctBg
            : AppColors.wrongBg;
        borderColor = isCorrect
            ? AppColors.correctBorder
            : AppColors.wrongBorder;
      } else if (isCorrect) {
        bgColor = AppColors.correctBg;
        borderColor = AppColors.correctBorder;
      }
    } else if (_showResult && !_immediateFeedback) {
      if (isSelected) {
        showCorrect = isCorrect;
        bgColor = isCorrect
            ? AppColors.correctBg
            : AppColors.wrongBg;
        borderColor = isCorrect
            ? AppColors.correctBorder
            : AppColors.wrongBorder;
      } else if (isCorrect) {
        bgColor = AppColors.correctBg;
        borderColor = AppColors.correctBorder;
      }
    }

    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isAnswered && _immediateFeedback
              ? null
              : () => _onOptionSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor ??
                    (isSelected ? AppColors.primary : AppColors.divider),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (showCorrect
                            ? AppColors.success
                            : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (showCorrect
                              ? AppColors.success
                              : AppColors.divider),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      index == 0 ? '✓' : '✗',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (showCorrect)
                  const Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildFillInBlankWidget(QuestionModel q) {
    final controller = _getFillController(q);
    // التأكد من أن النص في المتحكم متزامن مع الحالة
    if (controller.text != _currentFillAnswer) {
      controller.text = _currentFillAnswer;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          q.question,
          style: const TextStyle(
            fontSize: 18,
            height: 1.7,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _currentIsAnswered
                  ? (_checkCurrentAnswer()
                      ? AppColors.correctBorder
                      : AppColors.wrongBorder)
                  : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            onChanged: _onFillChanged,
            decoration: const InputDecoration(
              hintText: 'أكتب إجابتك هنا...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
        ),
        if (_isAnswered && _immediateFeedback) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _checkCurrentAnswer()
                  ? AppColors.correctBg
                  : AppColors.wrongBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _checkCurrentAnswer()
                    ? AppColors.correctBorder
                    : AppColors.wrongBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _checkCurrentAnswer()
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _checkCurrentAnswer()
                      ? AppColors.success
                      : AppColors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _checkCurrentAnswer()
                        ? 'إجابة صحيحة! ✅'
                        : 'الإجابة الصحيحة: ${q.answer}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _checkCurrentAnswer()
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMatchingWidget(QuestionModel q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primaryLight.withOpacity(0.5)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'اسحب العنصر من العمود الأيسر وأفلته على الرقم المقابل في العمود الأيمن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العمود ب - عناصر قابلة للسحب (Draggable) - على اليسار في RTL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(q.rightItems.length, (index) {
                  return _buildDraggableRight(
                    String.fromCharCode(1569 + index), // أ، ب، ج...
                    q.rightItems[index],
                    index,
                    q,
                  );
                }),
              ),
            ),
            const SizedBox(width: 32),
            // العمود أ - أهداف الإفلات (DragTarget) - على اليمين في RTL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(q.leftItems.length, (index) {
                  return _buildDragTargetLeft(
                    '${index + 1}',
                    q.leftItems[index],
                    index,
                    q,
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_currentMatchAnswer.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تم ربط ${_currentMatchAnswer.length} زوجاً',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'من أصل ${q.leftItems.length} زوج',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDragTargetLeft(
    String label,
    String text,
    int leftIndex,
    QuestionModel q,
  ) {
    final existingPair = _currentMatchAnswer.firstWhere(
      (pair) => pair[0] == leftIndex,
      orElse: () => [-1, -1],
    );
    final isPaired = existingPair[1] != -1;

    return DragTarget<List<int>>(
      onWillAccept: (data) => data != null,
      onAccept: (data) {
        final rightIdx = data[1];
        setState(() {
          final current = List<List<int>>.from(_matchAnswers[q.id] ?? []);
          current.removeWhere((p) => p[0] == leftIndex || p[1] == rightIdx);
          current.add([leftIndex, rightIdx]);
          _matchAnswers[q.id] = current;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData != null;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: isPaired
                  ? AppColors.successLight
                  : (isHovered
                      ? AppColors.primaryLight.withOpacity(0.5)
                      : AppColors.surfaceWhite),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPaired
                    ? AppColors.success
                    : (isHovered
                        ? AppColors.primary
                        : AppColors.divider),
                width: isPaired ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPaired || isHovered)
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isPaired ? AppColors.success : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isPaired
                          ? AppColors.successDark
                          : AppColors.textPrimary,
                      fontWeight: isPaired ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isPaired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.done,
                      color: AppColors.success,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableRight(
    String label,
    String text,
    int rightIndex,
    QuestionModel q,
  ) {
    final existingPair = _currentMatchAnswer.firstWhere(
      (pair) => pair[1] == rightIndex,
      orElse: () => [-1, -1],
    );
    final isPaired = existingPair[0] != -1;

    return Draggable<List<int>>(
      data: [0, rightIndex],
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildMatchItemRight(label, text, rightIndex, isPaired, q),
      ),
      child: _buildMatchItemRight(label, text, rightIndex, isPaired, q),
    );
  }

  Widget _buildMatchItemRight(
    String label,
    String text,
    int rightIndex,
    bool isPaired,
    QuestionModel q,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isPaired
              ? AppColors.successLight
              : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPaired
                ? AppColors.success
                : AppColors.divider,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isPaired ? AppColors.success : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: isPaired
                      ? AppColors.successDark
                      : AppColors.textPrimary,
                  fontWeight: isPaired ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isPaired) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.done,
                color: AppColors.success,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = _currentQuestion;
    final progress = (_currentIndex + 1) / _examQuestions.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        onPopInvoked: (bool didPop) {
          // منع الخروج أثناء الامتحان (يمكن التعديل لاحقاً لإضافة تأكيد)
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('سؤال ${_currentIndex + 1} من ${_examQuestions.length}'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _previousQuestion,
            ),
            actions: [
              if (_settings.timeLimitMinutes > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _timeRemaining < 60
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(_timeRemaining),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _timeRemaining < 60
                              ? AppColors.error
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // شريط التقدم
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.divider,
                color: AppColors.primary,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // بطاقة السؤال
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        q.typeIcon,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        q.typeLabel,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_immediateFeedback && _isAnswered)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _checkCurrentAnswer()
                                          ? AppColors.correctBg
                                          : AppColors.wrongBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _checkCurrentAnswer()
                                          ? 'صحيح ✅'
                                          : 'خطأ ❌',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _checkCurrentAnswer()
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              q.question,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildQuestionWidget(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              // أزرار التنقل
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentIndex == 0
                            ? null
                            : _previousQuestion,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'السابق',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (!_currentIsAnswered)
                            ? null
                            : (_isLastQuestion ? _finishExam : _nextQuestion),
                        child: Text(
                          _isLastQuestion ? 'إنهاء الامتحان' : 'التالي',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
