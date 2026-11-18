/// إعدادات التطبيق
class AppSettings {
  bool darkMode;
  bool immediateFeedback;
  int questionsPerExam;
  int timeLimitMinutes; // 0 = بدون مؤقت
  bool shuffleQuestions;
  bool shuffleOptions;
  bool soundEnabled;

  AppSettings({
    this.darkMode = false,
    this.immediateFeedback = true,
    this.questionsPerExam = 10,
    this.timeLimitMinutes = 0,
    this.shuffleQuestions = true,
    this.shuffleOptions = true,
    this.soundEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'darkMode': darkMode,
        'immediateFeedback': immediateFeedback,
        'questionsPerExam': questionsPerExam,
        'timeLimitMinutes': timeLimitMinutes,
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
        'soundEnabled': soundEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        darkMode: json['darkMode'] ?? false,
        immediateFeedback: json['immediateFeedback'] ?? true,
        questionsPerExam: json['questionsPerExam'] ?? 10,
        timeLimitMinutes: json['timeLimitMinutes'] ?? 0,
        shuffleQuestions: json['shuffleQuestions'] ?? true,
        shuffleOptions: json['shuffleOptions'] ?? true,
        soundEnabled: json['soundEnabled'] ?? true,
      );
}
