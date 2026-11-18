import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exam_app/theme/app_theme.dart';
import 'package:exam_app/models/question_model.dart';
import 'package:exam_app/services/question_service.dart';
import 'package:exam_app/screens/lessons_screen.dart';
import 'package:exam_app/screens/settings_screen.dart';
import 'package:exam_app/models/exam_result.dart';
import 'package:exam_app/services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<QuestionModel> _allQuestions = [];
  bool _isLoading = true;
  List<ExamResult> _recentResults = [];
  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _allQuestions = await QuestionService.loadQuestions();
    _totalQuestions = _allQuestions.length;
    _recentResults = StorageService.loadResults().take(5).toList();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الرئيسية'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // بطاقة الترحيب
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                                'مرحباً بك في تطبيق امتحاني',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                )),
                            const SizedBox(height: 10),
                            Text(
                                'اختبر معلوماتك في الطهارة والصلاة عبر ${_totalQuestions} سؤال من بنك الأسئلة',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.5,
                                )),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _statItem('أسئلة', '$_totalQuestions'),
                                const VerticalDivider(
                                  color: Colors.white24,
                                  width: 24,
                                ),
                                _statItem('دروس',
                                    '${QuestionService.getLessons(_allQuestions).length}'),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideX(begin: 0.2, end: 0, duration: 500.ms),

                      const SizedBox(height: 26),

                      // عنوان القسم
                      const Text(
                        'ابدأ امتحان',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // أزرار البدء السريع
                      Row(
                        children: [
                          _startButton(
                            'امتحان سريع',
                            '10 أسئلة عشوائية',
                            Icons.flash_on_rounded,
                            10,
                          ),
                          const SizedBox(width: 12),
                          _startButton(
                            'امتحان كامل',
                            'جميع الأسئلة',
                            Icons.list_alt_rounded,
                            _totalQuestions,
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      // resultados الأخيرة
                      if (_recentResults.isNotEmpty) ...[
                        const Text(
                          'نتائجك الأخيرة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentResults.length,
                          itemBuilder: (context, index) {
                            final result = _recentResults[index];
                            return _resultItem(result).animate().fadeIn(
                                  delay: (index * 100).ms,
                                  duration: 400.ms,
                                );
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد نتائج بعد',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ابدأ امتحانك الأول لرؤية نتائجك هنا',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _startButton(String title, String subtitle, IconData icon, int count) {
    return Expanded(
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _startExam(count),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_back_ios, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _resultItem(ExamResult result) {
    final isPassed = result.percentage >= 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isPassed
                ? AppColors.successLight
                : AppColors.wrongBg,
            child: Icon(
              isPassed ? Icons.check_circle : Icons.cancel,
              color: isPassed ? AppColors.success : AppColors.error,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${result.totalQuestions} سؤال',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.dateTime.day}/${result.dateTime.month}/${result.dateTime.year}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${result.percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? AppColors.success : AppColors.error,
                ),
              ),
              Text(
                '${result.correctAnswers} صحيح',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startExam(int count) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonsScreen(
          allQuestions: _allQuestions,
          questionCount: count,
        ),
      ),
    );
  }
}
