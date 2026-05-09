import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../config.dart';
import '../../services/treehole_service.dart';
import '../../services/upload_service.dart';

class TreeholeComposeScreen extends StatefulWidget {
  const TreeholeComposeScreen({super.key});

  @override
  State<TreeholeComposeScreen> createState() => _TreeholeComposeScreenState();
}

class _TreeholeComposeScreenState extends State<TreeholeComposeScreen> {
  final _contentCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final _uploadService = UploadService();
  final _treeholeService = TreeholeService();
  String _mood = '😊';
  List<String> _images = [];
  bool _sending = false;
  String? _uploadStatus;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;
    setState(() => _uploadStatus = '上传中...');
    for (final img in images) {
      try {
        final url = await _uploadService.uploadImage(img.path);
        if (mounted) {
          setState(() => _images = [..._images, url]);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _uploadStatus = null);
    }
  }

  void _removeImage(int idx) {
    setState(() => _images.removeAt(idx));
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先写点什么吧～')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _treeholeService.createTreehole(
        mood: _mood,
        content: content,
        imageUrls: _images.isNotEmpty ? _images : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('漂流瓶已投递 ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投递失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('投递漂流瓶'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Mood selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Column(
              children: [
                const Text('此刻心情',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: AppConfig.moodEmojis.map((m) {
                      final isActive = m == _mood;
                      return GestureDetector(
                        onTap: () => setState(() => _mood = m),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isActive
                                ? const Color(0xFFF3E8FF)
                                : Colors.transparent,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.purple.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(m,
                              style: TextStyle(
                                fontSize: 28,
                                color: isActive ? null : Colors.grey[300],
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Content input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '今天发生了什么，把它扔进大海吧…\n你的故事会漂流到另一个陌生人手中。',
                  hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
          ),
          // Image previews
          if (_images.isNotEmpty)
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _images[i],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_outlined,
                            size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _images.isEmpty ? '添加图片' : '继续添加',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_uploadStatus != null) ...[
                  const SizedBox(width: 12),
                  Text(_uploadStatus!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _sending ? null : _submit,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9333EA), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text('匿名投递',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
