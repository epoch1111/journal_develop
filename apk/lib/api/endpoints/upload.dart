import 'dart:io' show File;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../client.dart';

/// 判断是否为有效 JPEG：SOI marker FF D8
bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

/// 判断是否为 PNG：PNG signature 89 50 4E 47
bool _isPng(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x89 && bytes[1] == 0x50 &&
    bytes[2] == 0x4E && bytes[3] == 0x47;

/// 判断是否需要转换：已经是 JPEG 则跳过重新编码。
/// image_picker 的 imageQuality:80 已经压缩过了，
/// 再次 encodeJpg(quality:80) 会导致双重压缩质量严重下降。
/// 只有 PNG/HEIC/WEBP 等才需要转换。
bool _needsJpegConversion(Uint8List bytes) {
  if (_isJpeg(bytes)) return false;
  if (_isPng(bytes)) return true;
  // 其他格式（HEIC/WEBP/GIF 等）都需要转换
  return true;
}

/// Web 端用 canvas.drawImage + toBlob('image/jpeg', 0.8) 统一压缩。
/// APK：HEIC/PNG/WEBP → 解码 → encodeJpg(quality:80)。
/// JPEG → 跳过重新编码，直接使用原始字节（避免双重压缩）。
Future<Uint8List> _convertToJpeg(Uint8List bytes, {int quality = 80}) async {
  if (!_needsJpegConversion(bytes)) {
    return bytes; // 已经是 JPEG，直接用，跳过重新编码
  }
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

class UploadEndpoints {
  final ApiClient _client = ApiClient();

  /// 参考 Web 端 api.js uploadImage():
  /// 1. image_picker imageQuality:80 已做了一次压缩
  /// 2. 已是 JPEG → 直接上传（不重复编码）
  /// 3. 非 JPEG（HEIC/PNG/WEBP）→ 解码 + encodeJpg(quality:80)
  Future<Map<String, dynamic>> uploadImage(XFile file) async {
    final rawBytes = await file.readAsBytes();
    final bytes = Uint8List.fromList(rawBytes);

    // JPEG 不重复编码；其他格式转换
    final jpegBytes = await _convertToJpeg(bytes, quality: 80);

    // 写临时 .jpg 文件
    final tmpDir = await getTemporaryDirectory();
    final tmpPath = '${tmpDir.path}/echo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tmpFile = File(tmpPath);
    try {
      await tmpFile.writeAsBytes(jpegBytes);

      // 上传（固定 JPEG 格式）
      return await _client.uploadFile('/api/upload', tmpPath,
          filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
          mime: 'image/jpeg');
    } finally {
      try { if (await tmpFile.exists()) await tmpFile.delete(); } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> uploadAvatar(XFile file) async {
    final rawBytes = await file.readAsBytes();
    final bytes = Uint8List.fromList(rawBytes);
    final jpegBytes = await _convertToJpeg(bytes, quality: 85);
    final tmpDir = await getTemporaryDirectory();
    final tmpPath = '${tmpDir.path}/echo_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tmpFile = File(tmpPath);
    try {
      await tmpFile.writeAsBytes(jpegBytes);
      return await _client.uploadFile('/api/profile/avatar', tmpPath,
          filename: 'avatar.jpg', mime: 'image/jpeg');
    } finally {
      try { if (await tmpFile.exists()) await tmpFile.delete(); } catch (_) {}
    }
  }
}
