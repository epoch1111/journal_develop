import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final bool showIgnore;

  const UpdateDialog({super.key, required this.info, this.showIgnore = true});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final svc = UpdateService();
      final path = await svc.downloadApk(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() => _downloading = false);
        await svc.installApk(path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('发现新版本',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v${widget.info.version}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent)),
            const SizedBox(height: 8),
            if (widget.info.changelog.isNotEmpty) ...[
              const Text('更新内容：',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(widget.info.changelog,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
              const SizedBox(height: 8),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
              ),
            if (_downloading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('正在下载...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 6,
                      backgroundColor: AppTheme.accentLight,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
          ],
        ),
      ),
      actions: [
        if (_downloading)
          null
        else ...[
          if (widget.showIgnore)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ElevatedButton(
            onPressed: _downloading ? null : _download,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('立即更新'),
          ),
        ],
      ].whereType<Widget>().toList(),
    );
  }
}
