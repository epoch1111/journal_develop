import 'api_client.dart';

class UploadService {
  final ApiClient _client = ApiClient();

  Future<String> uploadImage(String filePath) async {
    final data = await _client.uploadFile('/api/upload', filePath);
    return data['url'] ?? '';
  }

  Future<String> uploadAvatar(String filePath) async {
    final data = await _client.uploadFile('/api/profile/avatar', filePath);
    return data['avatar'] ?? '';
  }
}
