import 'package:image_picker/image_picker.dart';
import '../api/endpoints/upload.dart';
import '../api/client.dart';

class UploadService {
  final UploadEndpoints _ep = UploadEndpoints();

  Future<String> uploadImage(XFile file) async {
    final data = await _ep.uploadImage(file);
    final url = data['url'] ?? '';
    // 返回完整 URL，避免拼接错误
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiClient().baseUrl}$url';
  }

  Future<String> uploadAvatar(XFile file) async {
    final data = await _ep.uploadAvatar(file);
    final url = data['avatar'] ?? '';
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiClient().baseUrl}$url';
  }
}
