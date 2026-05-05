import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';

class ServerConfigScreen extends ConsumerStatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen> {
  final _urlCtrl = TextEditingController();
  bool _testing = false;
  String? _testResult;
  bool _isHttps = false;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    final url = ApiClient().baseUrl;
    _urlCtrl.text = url;
    _isHttps = url.startsWith('https://');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlCtrl.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _testResult = 'fail: 地址必须以 http:// 或 https:// 开头');
      return;
    }
    setState(() { _testing = true; _testResult = null; });
    try {
      await ApiClient().setBaseUrl(url);
      final data = await ApiClient().get('/api/auth/me', auth: false);
      setState(() { _testing = false; _testResult = 'error: ${data['detail']}'; });
      return;
    } on AuthException {
      setState(() { _testing = false; _testResult = 'ok'; });
      return;
    } catch (e) {
      setState(() { _testing = false; _testResult = 'fail: 无法连接服务器\n$e'; });
      return;
    }
  }

  Future<void> _saveAndGo() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await ApiClient().setBaseUrl(url);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _fillLan() {
    setState(() {
      _urlCtrl.text = 'http://192.168.1.100:8000';
      _isHttps = false;
    });
  }

  void _fillNgrok() {
    setState(() {
      _urlCtrl.text = 'https://xxxx.ngrok-free.app';
      _isHttps = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOk = _testResult == 'ok';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const Text('🐰', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              Text('连接服务器',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800])),
              const SizedBox(height: 4),
              Text('支持局域网 / 公网 / 内网穿透',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              const SizedBox(height: 28),

              // Quick preset buttons
              Row(
                children: [
                  _presetBtn('🏠 局域网', _fillLan),
                  const SizedBox(width: 8),
                  _presetBtn('🚇 Ngrok', _fillNgrok),
                ],
              ),
              const SizedBox(height: 16),

              // URL input
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.100:8000',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey[300]),
                  prefixIcon: Icon(
                    _isHttps ? Icons.lock_outline : Icons.dns_outlined,
                    color: Colors.grey[500],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
                onChanged: (v) {
                  setState(() {
                    _isHttps = v.startsWith('https://');
                  });
                },
              ),
              const SizedBox(height: 16),

              // Test + Save buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: isOk ? Colors.green : Colors.grey[300]!),
                      ),
                      child: _testing
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isOk ? '✓ 连接成功' : '测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveAndGo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('开始使用'),
                    ),
                  ),
                ],
              ),

              // Test result
              if (_testResult != null && _testResult != 'ok') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_testResult!,
                      style: TextStyle(fontSize: 12, color: Colors.red[700])),
                ),
              ],
              const SizedBox(height: 24),

              // Help section
              GestureDetector(
                onTap: () => setState(() => _showHelp = !_showHelp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _showHelp
                            ? Icons.keyboard_arrow_up
                            : Icons.help_outline,
                        size: 18,
                        color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(_showHelp ? '收起说明' : '如何配置？',
                        style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              ),
              if (_showHelp) ...[
                const SizedBox(height: 16),
                _helpCard('🏠 局域网（同一 WiFi）',
                    '电脑 Win+R → cmd → ipconfig → 找到 IPv4 地址\n'
                    '输入: http://你的IP:8000\n'
                    '例如: http://192.168.1.100:8000\n'
                    '手机必须连接同一个 WiFi'),
                const SizedBox(height: 10),
                _helpCard('🚇 Ngrok（公网穿透，无需公网IP）',
                    '1. 下载 ngrok (ngrok.com)\n'
                    '2. 命令行运行: ngrok http 8000\n'
                    '3. 复制生成的公网地址\n'
                    '例如: https://xxxx.ngrok-free.app\n'
                    '全球任意网络都能访问'),
                const SizedBox(height: 10),
                _helpCard('📡 Frp（国内更稳定）',
                    '需要一台有公网 IP 的云服务器做中转\n'
                    '配置 frpc.ini 将 8000 端口映射出去\n'
                    '输入: http://你的服务器IP:映射端口'),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetBtn(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  Widget _helpCard(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700])),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[600],
                  height: 1.6)),
        ],
      ),
    );
  }
}
