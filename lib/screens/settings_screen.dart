import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:exam_app/theme/app_theme.dart';
import 'package:exam_app/services/storage_service.dart';
import 'package:exam_app/models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _settings = StorageService.loadSettings();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await StorageService.saveSettings(_settings);
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حفظ الإعدادات بنجاح ✅'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مظهر التطبيق
              _sectionTitle('مظهر التطبيق'),
              const SizedBox(height: 12),
              _settingCard([
                _switchTile(
                  title: 'الوضع الليلي',
                  subtitle: 'تبديل بين السمة الفاتحة والداكنة',
                  value: _settings.darkMode,
                  onChanged: (val) => setState(() => _settings.darkMode = val),
                ),
              ]).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // طريقة التغذية الراجعة
              _sectionTitle('طريقة عرض الإجابات'),
              const SizedBox(height: 12),
              _settingCard([
                _switchTile(
                  title: 'إظهار الإجابة فوراً',
                  subtitle:
                      'تظهر الإجابة الصحيحة مباشرة بعد الإجابة على كل سؤال',
                  value: _settings.immediateFeedback,
                  onChanged: (val) =>
                      setState(() => _settings.immediateFeedback = val),
                ),
              ]).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // عدد الأسئلة
              _sectionTitle('عدد الأسئلة في الامتحان'),
              const SizedBox(height: 12),
              _settingCard([
                _dropdownTile(
                  title: 'عدد الأسئلة',
                  value: _settings.questionsPerExam.toString(),
                  items: const ['5', '10', '15', '20', '25', '30', '50'],
                  onChanged: (val) {
                    setState(() =>
                        _settings.questionsPerExam = int.parse(val!));
                  },
                ),
              ]).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // الوقت المحدد
              _sectionTitle('الوقت المحدد للامتحان'),
              const SizedBox(height: 12),
              _settingCard([
                _dropdownTile(
                  title: 'المدة الزمنية',
                  value: _settings.timeLimitMinutes == 0
                      ? 'بدون وقت'
                      : '${_settings.timeLimitMinutes} دقيقة',
                  items: const [
                    'بدون وقت',
                    '5 دقائق',
                    '10 دقائق',
                    '15 دقيقة',
                    '20 دقيقة',
                    '30 دقيقة',
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == 'بدون وقت') {
                        _settings.timeLimitMinutes = 0;
                      } else {
                        _settings.timeLimitMinutes =
                            int.parse(val!.replaceAll(' دقيقة', ''));
                      }
                    });
                  },
                ),
              ]).animate().fadeIn(delay: 300.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // خيارات التخصيص
              _sectionTitle('تخصيص الامتحان'),
              const SizedBox(height: 12),
              _settingCard([
                _switchTile(
                  title: 'خلط ترتيب الأسئلة',
                  subtitle: 'يأتي كل اختبار بترتيب مختلف للأسئلة',
                  value: _settings.shuffleQuestions,
                  onChanged: (val) =>
                      setState(() => _settings.shuffleQuestions = val),
                ),
                const Divider(height: 1),
                _switchTile(
                  title: 'خلط خيارات الإجابة',
                  subtitle: 'تقلب أماكن الخيارات في كل مرة يظهر فيها السؤال',
                  value: _settings.shuffleOptions,
                  onChanged: (val) =>
                      setState(() => _settings.shuffleOptions = val),
                ),
              ]).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: 40),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('حفظ الإعدادات'),
                ),
              ),
              const SizedBox(height: 24),

              // معلومات التطبيق
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'تطبيق امتحاني',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الإصدار 1.0.0\nتطبيق اختبارات إسلامي في الطهارة والصلاة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _settingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.3,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _dropdownTile({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
