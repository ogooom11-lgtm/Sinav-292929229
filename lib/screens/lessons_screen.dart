import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exam_app/theme/app_theme.dart';
import 'package:exam_app/models/question_model.dart';
import 'package:exam_app/services/question_service.dart';
import 'package:exam_app/screens/exam_screen.dart';

class LessonsScreen extends StatefulWidget {
  final List<QuestionModel> allQuestions;
  final int questionCount;

  const LessonsScreen({
    super.key,
    required this.allQuestions,
    required this.questionCount,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final Set<String> _selectedLessons = {};
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    // تحديد جميع الدروس افتراضياً
    final lessons = QuestionService.getLessons(widget.allQuestions);
    for (var l in lessons) _selectedLessons.add(l);
  }

  @override
  Widget build(BuildContext context) {
    final lessons = QuestionService.getLessons(widget.allQuestions);
    final selectedCount = _selectedLessons.length;
    final totalCount = lessons.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختر الدروس'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // ملخص الاختيار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'تم اختيار $selectedCount من $totalCount درس',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Switch(
                        value: _selectAll,
                        onChanged: (val) {
                          setState(() {
                            _selectAll = val;
                            if (val) {
                              for (var l in lessons) _selectedLessons.add(l);
                            } else {
                              _selectedLessons.clear();
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'سيتم اختيار ${widget.questionCount} سؤال عشوائياً من الدروس المختارة',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // قائمة الدروس
            Expanded(
              child: ListView.builder(
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  final questionCount =
                      widget.allQuestions.where((q) => q.lesson == lesson).length;
                  final isSelected = _selectedLessons.contains(lesson);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.neutralBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        lesson,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '$questionCount سؤال',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedLessons.add(lesson);
                            } else {
                              _selectedLessons.remove(lesson);
                              _selectAll = false;
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedLessons.remove(lesson);
                            _selectAll = false;
                          } else {
                            _selectedLessons.add(lesson);
                            if (_selectedLessons.length == lessons.length) {
                              _selectAll = true;
                            }
                          }
                        });
                      },
                    ),
                  ).animate().fadeIn(delay: (index * 40).ms);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _selectedLessons.isEmpty
              ? null
              : () {
                  final filteredQuestions = widget.allQuestions
                      .where((q) => _selectedLessons.contains(q.lesson))
                      .toList();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExamScreen(
                        allQuestions: filteredQuestions,
                        questionCount: widget.questionCount,
                      ),
                    ),
                  );
                },
          backgroundColor: _selectedLessons.isEmpty
              ? AppColors.textSecondary
              : AppColors.primary,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('ابدأ الامتحان'),
        ),
      ),
    );
  }
}
