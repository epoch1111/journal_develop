import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

const int _currentVersionCode = 1;

class UpdateInfo {
  final String version;
  final int versionCode;
  final String changelog;
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.changelog,
    required this.hasUpdate,
  });
}

class UpdateService {
  final Dio _dio = Dio();

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final data = await ApiClient().get('/api/app/version', auth: false);
      final serverVersionCode = data['version_code'] as int? ?? 1;
      final hasUpdate = serverVersionCode > _currentVersionCode;
      return UpdateInfo(
        version: data['version'] as String? ?? '1.0.0',
        versionCode: serverVersionCode,
        changelog: data['changelog'] as String? ?? '',
        hasUpdate: hasUpdate,
      );
    } catch (_) {
      return UpdateInfo(version: '1.0.0', versionCode: 1, changelog: '', hasUpdate: false);
    }
  }

  Future<String> downloadApk({
    void Function(double progress)? onProgress,
  }) async {
    final dir = Directory('/storage/emulated/0/Download');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final savePath = '${dir.path}/echo_journal_update.apk';

    try {
      final files =
          dir.listSync().where((f) => f.path.endsWith('echo_journal_update.apk'));
      for (final f in files) {
        File(f.path).deleteSync();
      }
    } catch (_) {}

    final url = '${ApiClient().baseUrl}/api/app/download';
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return savePath;
  }

  Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
  }

  Future<bool> shouldAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt('last_update_check') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneDay = 24 * 60 * 60 * 1000;
    if (now - lastCheck < oneDay) return false;
    await prefs.setInt('last_update_check', now);
    return true;
  }

  Future<void> resetAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_update_check');
  }
}
