import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exam_app/theme/app_theme.dart';
import 'package:exam_app/models/question_model.dart';
import 'package:exam_app/models/exam_result.dart';
import 'package:exam_app/screens/home_screen.dart';

class ResultScreen extends StatefulWidget {
  final ExamResult result;
  final List<QuestionModel> questions;
  final Map<int, int> userAnswers;
  final Map<int, String> fillAnswers;
  final Map<int, List<List<int>>> matchAnswers;
  final int timeSpentSeconds;

  const ResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.userAnswers,
    required this.fillAnswers,
    required this.matchAnswers,
    required this.timeSpentSeconds,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.result.percentage >= 60) {
      _confettiController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  bool _isQuestionCorrect(QuestionModel q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
        final ans = widget.userAnswers[q.id];
        return ans != null && q.isCorrect(ans);
      case QuestionType.fillInBlank:
        final ans = widget.fillAnswers[q.id];
        return ans != null &&
            ans.trim().isNotEmpty &&
            q.isFillCorrect(ans);
      case QuestionType.matching:
        final ans = widget.matchAnswers[q.id];
        return ans != null && q.isMatchingCorrect(ans);
    }
  }

  String _getUserAnswerText(QuestionModel q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        final idx = widget.userAnswers[q.id];
        if (idx == null) return 'لم يتم الإجابة';
        if (idx >= 0 && idx < q.options.length) return q.options[idx];
        return 'غير معروف';
      case QuestionType.trueFalse:
        final idx = widget.userAnswers[q.id];
        if (idx == null) return 'لم يتم الإجابة';
        return idx == 0 ? 'صح' : 'خطأ';
      case QuestionType.fillInBlank:
        final ans = widget.fillAnswers[q.id];
        if (ans == null || ans.trim().isEmpty) return 'لم يتم الإجابة';
        return ans;
      case QuestionType.matching:
        final pairs = widget.matchAnswers[q.id];
        if (pairs == null || pairs.isEmpty) return 'لم يتم الإجابة';
        return 'تم ربط ${pairs.length} زوج';
    }
  }

  String _getCorrectAnswerText(QuestionModel q) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        if (q.correctIndex != null &&
            q.correctIndex! >= 0 &&
            q.correctIndex! < q.options.length) {
          return q.options[q.correctIndex!];
        }
        return q.correctText;
      case QuestionType.trueFalse:
        return q.correctText;
      case QuestionType.fillInBlank:
        return q.answer;
      case QuestionType.matching:
        return 'انظر الأزواج الصحيحة في السؤال';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPassed = widget.result.percentage >= 60;
    final minutes = widget.timeSpentSeconds ~/ 60;
    final seconds = widget.timeSpentSeconds % 60;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPassed
                  ? [AppColors.primary, AppColors.primaryDark]
                  : [AppColors.error, AppColors.error],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // رأس الشاشة
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home_rounded,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                      ),
                      const Spacer(),
                      Text(
                        'نتيجة الامتحان',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          // دائرة النتيجة
                          AnimatedBuilder(
                            animation: _confettiController,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 160,
                                    height: 160,
                                    child: CircularProgressIndicator(
                                      value: widget.result.percentage / 100,
                                      strokeWidth: 10,
                                      backgroundColor: AppColors.divider,
                                      color: isPassed
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${widget.result.percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: isPassed
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isPassed ? 'ممتاز!' : 'يمكن التحسن',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // إحصائيات سريعة
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statCircle(
                                'صحيح',
                                '${widget.result.correctAnswers}',
                                AppColors.success,
                              ),
                              _statCircle(
                                'خطأ',
                                '${widget.result.wrongAnswers}',
                                AppColors.error,
                              ),
                              _statCircle(
                                'بدون إجابة',
                                '${widget.result.unanswered}',
                                AppColors.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // الوقت المستغرق
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _timeItem('الوقت', '$minutes:${seconds.toString().padLeft(2, '0')}'),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                                _timeItem('الأسئلة', '${widget.result.totalQuestions}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),

                          // زر عرض التفاصيل
                          SizedBox(
                            width: 220,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() => _showDetails = !_showDetails);
                              },
                              icon: Icon(
                                _showDetails
                                    ? Icons.remove
                                    : Icons.list_rounded,
                              ),
                              label: Text(
                                _showDetails
                                    ? 'إخفاء التفاصيل'
                                    : 'عرض التفاصيل',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // التفاصيل
                          if (_showDetails) ...[
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'مراجعة الأسئلة',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: widget.questions.length,
                                    itemBuilder: (context, index) {
                                      final q = widget.questions[index];
                                      final isCorrect = _isQuestionCorrect(q);
                                      return _detailItem(q, isCorrect)
                                          .animate()
                                          .fadeIn(delay: (index * 50).ms);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // أزرار الإجراءات
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (_) => const HomeScreen()),
                                      (route) => false,
                                    );
                                  },
                                  icon: const Icon(Icons.replay_rounded),
                                  label: const Text('امتحان جديد'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('الرئيسية'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCircle(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            )),
      ],
    );
  }

  Widget _timeItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            )),
      ],
    );
  }

  Widget _detailItem(QuestionModel q, bool isCorrect) {
    final userAns = _getUserAnswerText(q);
    final correctAns = _getCorrectAnswerText(q);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.correctBg
            : AppColors.wrongBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect
              ? AppColors.correctBorder
              : AppColors.wrongBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${q.id}. ${q.question}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCorrect ? 'صحيح' : 'خطأ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (userAns != 'لم يتم الإجابة') ...[
            const SizedBox(height: 8),
            Text(
              'إجابتك: $userAns',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'الإجابة الصحيحة: $correctAns',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCorrect
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
