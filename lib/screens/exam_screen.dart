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

  // العناصر المختارة حالياً في سؤال الوصل (للربط بالنقر)
  int? _selectedMatchLeft;
  int? _selectedMatchRight;

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
        // قد يختلف عدد عناصر العمودين (مثال: 4 مقابل 5)،
        // فيكفي ربط عدد الأزواج الأقل بين العمودين.
        final required = _currentQuestion.matchingRequiredPairs;
        return required == 0 || _currentMatchAnswer.length >= required;
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
          _selectedMatchLeft = null;
          _selectedMatchRight = null;
        });
      }
      return;
    }
    // في وضع الرد الفوري، الانتقال للسؤال التالي
    if (_currentIndex < _examQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = _currentIsAnswered;
        _selectedMatchLeft = null;
        _selectedMatchRight = null;
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
        _selectedMatchLeft = null;
        _selectedMatchRight = null;
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

  // ======================= سؤال الوصل =======================

  /// ألوان مميزة لكل زوج من أزواج الوصل
  static const List<Color> _matchPalette = [
    Color(0xFF2E7D5B),
    Color(0xFF1565C0),
    Color(0xFF8E24AA),
    Color(0xFFEF6C00),
    Color(0xFF00838F),
    Color(0xFFC2185B),
  ];

  Color _matchColor(int leftIndex) =>
      _matchPalette[leftIndex.abs() % _matchPalette.length];

  /// الزوج المرتبط بعنصر من العمود (أ)
  List<int>? _pairOfLeft(int leftIndex) {
    for (final pair in _currentMatchAnswer) {
      if (pair.length >= 2 && pair[0] == leftIndex) return pair;
    }
    return null;
  }

  /// الزوج المرتبط بعنصر من العمود (ب)
  List<int>? _pairOfRight(int rightIndex) {
    for (final pair in _currentMatchAnswer) {
      if (pair.length >= 2 && pair[1] == rightIndex) return pair;
    }
    return null;
  }

  /// ربط عنصرين (مع فك أي ربط سابق لأي منهما)
  void _linkPair(QuestionModel q, int leftIndex, int rightIndex) {
    if (_matchLocked) return;
    final required = q.matchingRequiredPairs;
    final existing = _currentMatchAnswer;
    final alreadyLinked = existing.any(
      (p) =>
          p.length >= 2 &&
          ((p[0] == leftIndex && p[1] == rightIndex)),
    );
    // منع تجاوز عدد الأزواج المطلوبة
    if (!alreadyLinked && required > 0 && existing.length >= required) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لقد ربطت $required أزواج، وهي المطلوبة. اضغط على أي عنصر لفك ربطه.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      final current = List<List<int>>.from(_matchAnswers[q.id] ?? []);
      current.removeWhere(
        (p) => p.length >= 2 && (p[0] == leftIndex || p[1] == rightIndex),
      );
      current.add([leftIndex, rightIndex]);
      _matchAnswers[q.id] = current;
      _selectedMatchLeft = null;
      _selectedMatchRight = null;
      _isAnswered = _currentIsAnswered;
    });
  }

  /// هل انتهى السؤال في وضع الرد الفوري (يُمنع التعديل بعدها)
  bool get _matchLocked => _isAnswered && _immediateFeedback;

  /// هل الزوج صحيح؟ (يُستخدم بعد الإجابة فقط)
  bool _isPairCorrect(QuestionModel q, List<int> pair) {
    if (pair.length < 2) return false;
    return q.correctPairs.any(
      (c) => c.length >= 2 && c[0] == pair[0] && c[1] == pair[1],
    );
  }

  void _onMatchLeftTap(QuestionModel q, int leftIndex) {
    if (_matchLocked) return;
    if (_pairOfLeft(leftIndex) != null) {
      // عنصر مرتبط: فك الربط واختياره من جديد لإعادة ربطه
      setState(() {
        final current = List<List<int>>.from(_matchAnswers[q.id] ?? []);
        current.removeWhere((p) => p.length >= 2 && p[0] == leftIndex);
        _matchAnswers[q.id] = current;
        _selectedMatchLeft = leftIndex;
        _selectedMatchRight = null;
        _isAnswered = _currentIsAnswered;
      });
      return;
    }
    if (_selectedMatchRight != null) {
      _linkPair(q, leftIndex, _selectedMatchRight!);
      return;
    }
    setState(() {
      _selectedMatchLeft = _selectedMatchLeft == leftIndex ? null : leftIndex;
    });
  }

  void _onMatchRightTap(QuestionModel q, int rightIndex) {
    if (_matchLocked) return;
    if (_pairOfRight(rightIndex) != null) {
      // عنصر مرتبط: فك الربط واختياره من جديد لإعادة ربطه
      setState(() {
        final current = List<List<int>>.from(_matchAnswers[q.id] ?? []);
        current.removeWhere((p) => p.length >= 2 && p[1] == rightIndex);
        _matchAnswers[q.id] = current;
        _selectedMatchRight = rightIndex;
        _selectedMatchLeft = null;
        _isAnswered = _currentIsAnswered;
      });
      return;
    }
    if (_selectedMatchLeft != null) {
      _linkPair(q, _selectedMatchLeft!, rightIndex);
      return;
    }
    setState(() {
      _selectedMatchRight =
          _selectedMatchRight == rightIndex ? null : rightIndex;
    });
  }

  Widget _buildMatchingWidget(QuestionModel q) {
    final pairs = _currentMatchAnswer;
    final required = q.matchingRequiredPairs;
    final done = pairs.length > required ? required : pairs.length;
    final isComplete = required > 0 && pairs.length >= required;
    final diff = q.leftItems.length - q.rightItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------- بطاقة الإرشاد ----------
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF6EF), Color(0xFFF8FCFA)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'اضغط على عبارة من العمود (أ) ثم على ما يناسبها من العمود (ب)، أو اسحب العنصر وأفلته على مقابله.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- مؤشر التقدّم ----------
        Row(
          children: [
            Icon(
              isComplete
                  ? Icons.verified_rounded
                  : Icons.link_rounded,
              size: 18,
              color: isComplete ? AppColors.success : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              isComplete ? 'أتممت الربط' : 'الربط',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isComplete ? AppColors.successDark : AppColors.primaryDark,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isComplete
                    ? AppColors.successLight
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$done / $required',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isComplete
                      ? AppColors.successDark
                      : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: required == 0 ? 0 : done / required,
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                color: isComplete ? AppColors.success : AppColors.primary,
              );
            },
          ),
        ),
        const SizedBox(height: 20),

        // ---------- رؤوس الأعمدة ----------
        Row(
          children: [
            Expanded(
              child: _buildMatchColumnHeader(
                title: 'العمود (أ)',
                subtitle: 'العبارات',
                icon: Icons.format_list_numbered_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMatchColumnHeader(
                title: 'العمود (ب)',
                subtitle: 'المقابل',
                icon: Icons.abc_rounded,
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---------- الأعمدة ----------
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العمود (أ) على اليمين في RTL
            Expanded(
              child: Column(
                children: List.generate(
                  q.leftItems.length,
                  (index) => _buildMatchLeftItem(q, index),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // العمود (ب) على اليسار في RTL
            Expanded(
              child: Column(
                children: List.generate(
                  q.rightItems.length,
                  (index) => _buildMatchRightItem(q, index),
                ),
              ),
            ),
          ],
        ),

        // ---------- ملاحظة اختلاف الأعداد ----------
        if (diff != 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _extraItemsNote(diff, required),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ---------- أدوات ----------
        if (pairs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              // مفتاح الألوان
              Expanded(
                child: Text(
                  'اضغط على أي عنصر مرتبط لفك ربطه',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _matchLocked
                    ? null
                    : () {
                        setState(() {
                          _matchAnswers[q.id] = [];
                          _selectedMatchLeft = null;
                          _selectedMatchRight = null;
                          _isAnswered = _currentIsAnswered;
                        });
                      },
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('فك ربط الكل'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],

        // ---------- شريط الإتمام ----------
        if (isComplete) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'تم ربط جميع العناصر المطلوبة، يمكنك الانتقال للسؤال التالي.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successDark,
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

  /// نص ملاحظة اختلاف عدد عناصر العمودين
  String _extraItemsNote(int diff, int required) {
    final n = diff.abs();
    final countText = n == 1
        ? 'عنصر واحد'
        : n == 2
            ? 'عنصرين'
            : (n <= 10 ? '$n عناصر' : '$n عنصراً');
    final column = diff > 0 ? 'العمود (أ)' : 'العمود (ب)';
    final pairs = required == 1
        ? 'زوجاً واحداً'
        : required == 2
            ? 'زوجين'
            : (required <= 10 ? '$required أزواج' : '$required زوجاً');
    return 'في $column $countText بدون مقابل، لذلك يكفي ربط $pairs فقط.';
  }

  /// رأس عمود
  Widget _buildMatchColumnHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// عنصر من العمود (أ) — هدف إفلات + اختيار بالنقر
  Widget _buildMatchLeftItem(QuestionModel q, int leftIndex) {
    final pair = _pairOfLeft(leftIndex);
    final isPaired = pair != null;
    final isSelected = _selectedMatchLeft == leftIndex;
    final isRevealed = _matchLocked && isPaired;
    final color = isRevealed
        ? (_isPairCorrect(q, pair!) ? AppColors.success : AppColors.error)
        : _matchColor(leftIndex);

    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (details) =>
          !_matchLocked && details.data.isNotEmpty,
      onAcceptWithDetails: (details) {
        if (details.data.isNotEmpty) {
          _linkPair(q, leftIndex, details.data.first);
        }
      },
      builder: (context, candidate, rejected) {
        final isHovered = candidate.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _onMatchLeftTap(q, leftIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isHovered
                      ? color.withValues(alpha: 0.16)
                      : (isPaired
                          ? color.withValues(alpha: 0.09)
                          : (isSelected
                              ? AppColors.primaryLight
                              : AppColors.surfaceWhite)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHovered || isSelected || isPaired
                        ? color
                        : AppColors.divider,
                    width: isHovered || isSelected ? 1.8 : 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPaired
                          ? color.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: isPaired ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // رقم العنصر
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPaired
                              ? [color, color.withValues(alpha: 0.75)]
                              : [AppColors.primaryLight, AppColors.primaryLight],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPaired ? color : AppColors.primary,
                          width: 1.3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${leftIndex + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isPaired
                                ? Colors.white
                                : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        q.leftItems[leftIndex],
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight:
                              isPaired ? FontWeight.w600 : FontWeight.normal,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isPaired) ...[
                      const SizedBox(width: 4),
                      Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isRevealed
                                    ? (_isPairCorrect(q, pair!)
                                        ? Icons.check_rounded
                                        : Icons.close_rounded)
                                    : Icons.link_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                QuestionModel.matchLetter(pair![1]),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 260.ms, delay: (leftIndex * 40).ms);
      },
    );
  }

  /// عنصر من العمود (ب) — قابل للسحب + اختيار بالنقر
  Widget _buildMatchRightItem(QuestionModel q, int rightIndex) {
    final pair = _pairOfRight(rightIndex);
    final isPaired = pair != null;
    final isSelected = _selectedMatchRight == rightIndex;
    final isRevealed = _matchLocked && isPaired;
    final color = isRevealed
        ? (_isPairCorrect(q, pair!) ? AppColors.success : AppColors.error)
        : (isPaired ? _matchColor(pair![0]) : AppColors.info);

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          color: isPaired
              ? color.withValues(alpha: 0.09)
              : (isSelected ? AppColors.infoLight : AppColors.surfaceWhite),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPaired || isSelected ? color : AppColors.divider,
            width: isSelected ? 1.8 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: isPaired
                  ? color.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isPaired ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حرف العنصر
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isPaired ? color : AppColors.info,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPaired ? color : AppColors.info,
                  width: 1.3,
                ),
              ),
              child: Center(
                child: Text(
                  QuestionModel.matchLetter(rightIndex),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                q.rightItems[rightIndex],
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: isPaired ? FontWeight.w600 : FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isPaired) ...[
              const SizedBox(width: 4),
              Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRevealed
                            ? (_isPairCorrect(q, pair!)
                                ? Icons.check_rounded
                                : Icons.close_rounded)
                            : Icons.link_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${pair![0] + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    return Draggable<List<int>>(
      data: [rightIndex],
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    QuestionModel.matchLetter(rightIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q.rightItems[rightIndex],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onMatchRightTap(q, rightIndex),
        child: card,
      ),
    ).animate().fadeIn(duration: 260.ms, delay: (rightIndex * 40).ms);
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
