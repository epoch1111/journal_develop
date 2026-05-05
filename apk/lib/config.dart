class AppConfig {
  static const String appName = 'Echo';
  static const String defaultServerUrl = 'http://10.0.2.2:8000';

  static const Map<String, Map<String, String>> moodColors = {
    '😊': {'accent': '#FEF3C7', 'border': '#F59E0B', 'label': '开心'},
    '😫': {'accent': '#E0E7FF', 'border': '#6366F1', 'label': '疲惫'},
    '😢': {'accent': '#DBEAFE', 'border': '#3B82F6', 'label': '难过'},
    '😡': {'accent': '#FEE2E2', 'border': '#EF4444', 'label': '生气'},
    '🥰': {'accent': '#FCE7F3', 'border': '#EC4899', 'label': '幸福'},
    '😐': {'accent': '#F3F4F6', 'border': '#9CA3AF', 'label': '平静'},
  };

  static const List<String> moodEmojis = ['😊', '😫', '😢', '😡', '🥰', '😐'];

  static const List<String> avatarPool = [
    '🐰', '🐱', '🐶', '🐻', '🦊', '🐼', '🐨', '🐙',
    '🦁', '🐮', '🐸', '🐵', '🦄', '🐳', '🌸', '⭐', '🌈', '🍀'
  ];

  static const List<String> writingPrompts = [
    '今天最让你印象深刻的一件事是什么？',
    '此刻你的心情像什么颜色？',
    '如果你可以给今天起一个标题，会是什么？',
    '今天有什么小事让你感到温暖？',
    '闭上眼睛，最先浮现在脑海的画面是？',
  ];
}
