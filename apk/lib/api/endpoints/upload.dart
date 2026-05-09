import '../client.dart';

class UploadEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    return await _client.uploadFile('/api/upload', filePath);
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    return await _client.uploadFile('/api/profile/avatar', filePath);
  }
}
