import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../widgets/mood_selector.dart';
import '../../providers/diary_provider.dart';
import '../../services/upload_service.dart';
import '../../api/client.dart';

class WriteDiaryScreen extends ConsumerStatefulWidget {
  final bool isCapsule;
  final bool isPrivateOnly;
  const WriteDiaryScreen({super.key, this.isCapsule = false, this.isPrivateOnly = false});

  @override
  ConsumerState<WriteDiaryScreen> createState() => _WriteDiaryScreenState();
}

class _WriteDiaryScreenState extends ConsumerState<WriteDiaryScreen> {
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String? _mood;
  bool _isPublic = true; // 公开日记默认开启
  bool _isAnalyzing = false;
  String? _aiMessage;
  String? _aiSummary;
  bool _isSaving = false;
  final List<String> _imageUrls = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagsCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_contentCtrl.text.trim().isEmpty) return;
    setState(() => _isAnalyzing = true);
    try {
      final data = await ApiClient().post('/api/analyze',
          body: {'content': _contentCtrl.text}, auth: false);
      setState(() {
        _aiMessage = data['ai_message'];
        _aiSummary = data['ai_summary'];
        if (data['tags'] != null) {
          final tags = data['tags'];
          final tagStr = tags is List ? tags.join(',') : tags.toString();
          if (_tagsCtrl.text.isEmpty) {
            _tagsCtrl.text = tagStr;
          }
        }
        if (_mood == null && data['mood'] != null) {
          _mood = data['mood'];
        }
        _isAnalyzing = false;
      });
    } catch (_) {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 80, limit: 9);
    for (final img in images) {
      try {
        final url = await UploadService().uploadImage(img);
        if (url.isNotEmpty) {
          setState(() => _imageUrls.add(url));
        }
      } catch (e) {
        print('UPLOAD ERROR: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_mood == null || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请选择心情并输入内容')));
      return;
    }
    setState(() => _isSaving = true);
    final ok = await ref.read(diaryProvider.notifier).saveDiary(
          mood: _mood!,
          content: _contentCtrl.text.trim(),
          tags: _tagsCtrl.text.trim(),
          isPublic: widget.isPrivateOnly ? false : _isPublic,
          unlockDate: widget.isCapsule ? _dateCtrl.text : null,
          imageUrls: _imageUrls.isNotEmpty ? _imageUrls : null,
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存成功')));
      Navigator.of(context).pop(true);
    }
    setState(() => _isSaving = false);
  }

  String _getPrompt() {
    final idx =
        DateTime.now().millisecondsSinceEpoch % AppConfig.writingPrompts.length;
    return AppConfig.writingPrompts[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.isCapsule ? '时光胶囊' : '写日记'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood selector
            Text('心情', style: AppTheme.bodyText),
            const SizedBox(height: 10),
            MoodSelector(
                selectedMood: _mood,
                onChanged: (m) => setState(() => _mood = m)),
            const SizedBox(height: 20),
            // Content
            TextField(
              controller: _contentCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: _getPrompt(),
                hintStyle: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            // Tags
            TextField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                hintText: '标签 (逗号分隔)',
              ),
            ),
            const SizedBox(height: 16),
            // Public switch
            if (!widget.isCapsule && !widget.isPrivateOnly)
              SwitchListTile(
                title: const Text('公开发布', style: TextStyle(fontSize: 14)),
                subtitle:
                    const Text('发布到发现广场', style: TextStyle(fontSize: 12)),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                activeColor: AppTheme.accent,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            // Capsule date picker
            if (widget.isCapsule)
              TextField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: '选择解锁日期',
                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().add(const Duration(days: 1)),
                    firstDate:
                        DateTime.now().add(const Duration(days: 1)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() {
                      _dateCtrl.text =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
            const SizedBox(height: 16),
            // AI Analyze button
            _isAnalyzing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('正在分析...',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _analyze,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI 分析'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                    ),
                  ),
            // AI Result
            if (_aiMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🐰', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_aiMessage!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.purple[700],
                                  height: 1.5)),
                          if (_aiSummary != null) ...[
                            const SizedBox(height: 6),
                            Text(_aiSummary!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.purple[400])),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Images
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._imageUrls.asMap().entries.map((e) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXs),
                        child: Image.network(
                            e.value.startsWith('http')
                                ? e.value
                                : '${ApiClient().baseUrl}${e.value}',
                            width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _imageUrls.removeAt(e.key)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_imageUrls.length < 9)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXs),
                        border: Border.all(
                            color: Colors.grey[200]!,
                            style: BorderStyle.solid),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined,
                          color: AppTheme.textMuted, size: 28),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
