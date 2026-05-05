import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();
  String _avatar = '🐰';
  bool _saving = false;
  bool _uploading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nicknameCtrl.text = user.nickname;
      _bioCtrl.text = user.bio;
      _interestsCtrl.text = user.interests;
      _avatar = user.avatar;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _interestsCtrl.dispose();
    super.dispose();
  }

  bool get _isImageUrl {
    return _avatar.startsWith('/uploads/') ||
        _avatar.startsWith('http://') ||
        _avatar.startsWith('https://');
  }

  Future<void> _pickAndUploadAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 400,
    );
    if (image == null) return;

    setState(() => _uploading = true);
    try {
      final url = await UploadService().uploadAvatar(image.path);
      if (url.isNotEmpty) {
        setState(() {
          _avatar = url;
          _uploading = false;
        });
      }
    } catch (_) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，请重试')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nicknameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不能为空')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ProfileService().updateProfile(
        nickname: _nicknameCtrl.text.trim(),
        avatar: _avatar,
        bio: _bioCtrl.text.trim(),
        interests: _interestsCtrl.text.trim(),
      );
      await ref.read(authProvider.notifier).fetchCurrentUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.accent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar preview + upload
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
              child: Column(
                children: [
                  const Text('头像',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  // Preview
                  if (_uploading)
                    const SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: UserAvatar(avatar: _avatar, size: 80),
                    ),
                  const SizedBox(height: 10),
                  // Upload button
                  TextButton.icon(
                    onPressed: _pickAndUploadAvatar,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('上传照片',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Default avatar grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('默认头像',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: AppConfig.avatarPool.map((a) {
                      final selected = a == _avatar && !_isImageUrl;
                      return GestureDetector(
                        onTap: () => setState(() => _avatar = a),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.accentLight
                                : Colors.grey[50],
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.accent
                                  : Colors.grey[100]!,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child:
                              Text(a, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Nickname
            _buildField('昵称', _nicknameCtrl, hint: '你的昵称'),
            const SizedBox(height: 16),
            // Bio
            _buildField('个人简介', _bioCtrl, maxLines: 3, hint: '介绍一下自己'),
            const SizedBox(height: 16),
            // Interests
            _buildField('兴趣标签 (逗号分隔)', _interestsCtrl, hint: '日记,生活,小确幸'),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
