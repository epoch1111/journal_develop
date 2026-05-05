import 'package:flutter/material.dart';
import '../config.dart';
import '../theme.dart';

class MoodSelector extends StatelessWidget {
  final String? selectedMood;
  final ValueChanged<String> onChanged;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConfig.moodEmojis.map((mood) {
        final isSelected = mood == selectedMood;
        final colors = AppConfig.moodColors[mood]!;
        final borderColor = Color(int.parse(colors['border']!.replaceFirst('#', '0xFF')));
        final accentColor = Color(int.parse(colors['accent']!.replaceFirst('#', '0xFF')));
        return GestureDetector(
          onTap: () => onChanged(mood),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? borderColor : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mood, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(colors['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? borderColor : AppTheme.textSecondary,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
