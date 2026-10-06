import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../services/alert_service.dart';
import '../services/push_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig initialConfig;
  final ValueChanged<AppConfig> onSave;

  const SettingsScreen({
    super.key,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _topN;
  late double _minVolume;
  late Set<double> _alertThresholds;
  late Set<String> _blacklist;
  late bool _telegramEnabled;
  late TextEditingController _telegramTokenController;
  late TextEditingController _telegramChatIdController;
  bool _isSendingTest = false;

  bool _isWebPushSupported = false;
  bool _isWebPushSubscribed = false;
  bool _isWebPushLoading = false;
  bool _isWebPushTesting = false;

  final TextEditingController _addTokenController = TextEditingController();
  final TextEditingController _customThresholdController = TextEditingController();

  static const List<double> presetThresholds = [
    5.0,
    10.0,
    15.0,
    20.0,
    25.0,
    30.0,
    40.0,
    50.0,
    100.0,
  ];

  @override
  void initState() {
    super.initState();
    _topN = widget.initialConfig.topN;
    _minVolume = widget.initialConfig.minQuoteVolume;
    _alertThresholds = Set<double>.from(widget.initialConfig.alertThresholds);
    if (_alertThresholds.isEmpty) {
      _alertThresholds.addAll([15.0, 20.0]);
    }
    _blacklist = Set<String>.from(widget.initialConfig.blacklistBaseAssets);
    _telegramEnabled = widget.initialConfig.telegramEnabled;
    _telegramTokenController = TextEditingController(text: widget.initialConfig.telegramBotToken);
    _telegramChatIdController = TextEditingController(text: widget.initialConfig.telegramChatId);
    _checkWebPushStatus();
  }

  Future<void> _checkWebPushStatus() async {
    final supported = await PushNotificationService.isSupported();
    if (!mounted) return;
    setState(() {
      _isWebPushSupported = supported;
    });
    if (supported) {
      final subscribed = await PushNotificationService.isSubscribed();
      if (!mounted) return;
      setState(() {
        _isWebPushSubscribed = subscribed;
      });
    }
  }

  Future<void> _toggleWebPush(bool enable) async {
    setState(() => _isWebPushLoading = true);
    try {
      if (enable) {
        final res = await PushNotificationService.subscribe();
        final success = res['success'] == true;
        if (mounted) {
          setState(() {
            _isWebPushSubscribed = success;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: success ? const Color(0xFF238636) : const Color(0xFFDA3633),
              content: Text(
                success
                    ? '🔔 Đã bật thông báo trực tiếp trên iPhone thành công!'
                    : '❌ Không thể bật thông báo: ${res['error'] ?? 'Lỗi không xác định'}',
              ),
            ),
          );
        }
      } else {
        await PushNotificationService.unsubscribe();
        if (mounted) {
          setState(() {
            _isWebPushSubscribed = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF21262D),
              content: Text('Đã tắt thông báo đẩy trên thiết bị này.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isWebPushLoading = false);
      }
    }
  }

  Future<void> _testWebPush() async {
    setState(() => _isWebPushTesting = true);
    try {
      final res = await PushNotificationService.sendTestPush();
      final success = res['success'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF238636) : const Color(0xFFDA3633),
            content: Text(
              success
                  ? '⚡ Đã gửi thông báo thử nghiệm! Hãy kiểm tra màn hình khóa hoặc thanh thông báo iPhone.'
                  : '❌ Gửi thử nghiệm thất bại: ${res['error'] ?? 'Lỗi kết nối máy chủ'}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWebPushTesting = false);
      }
    }
  }

  @override
  void dispose() {
    _addTokenController.dispose();
    _customThresholdController.dispose();
    _telegramTokenController.dispose();
    _telegramChatIdController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.initialConfig.copyWith(
      topN: _topN,
      minQuoteVolume: _minVolume,
      alertGainThresholdPercent: _alertThresholds.isNotEmpty ? _alertThresholds.first : 20.0,
      alertThresholds: (_alertThresholds.toList()..sort()),
      blacklistBaseAssets: _blacklist,
      telegramEnabled: _telegramEnabled,
      telegramBotToken: _telegramTokenController.text.trim(),
      telegramChatId: _telegramChatIdController.text.trim(),
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  Future<void> _testTelegram() async {
    final token = _telegramTokenController.text.trim();
    final chatId = _telegramChatIdController.text.trim();

    if (token.isEmpty || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDA3633),
          content: Text('Vui lòng nhập đầy đủ Bot Token và Chat ID!'),
        ),
      );
      return;
    }

    setState(() => _isSendingTest = true);

    try {
      final success = await AlertService.instance.sendTelegramMessage(
        botToken: token,
        chatId: chatId,
        text: '⚡ *CoinPulse Alert Test* ⚡\n\n'
            '🔔 Đã kết nối thành công Telegram Bot!\n'
            'Mỗi khi có coin vượt ngưỡng tăng trưởng (+15%, +20%...), CoinPulse sẽ tự động bắn cảnh báo vào đây.\n\n'
            '👉 [Mở biểu đồ CoinPulse](https://hoangminh199524-design.github.io/coinpulse/)',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF238636) : const Color(0xFFDA3633),
            content: Text(
              success
                  ? '✅ Đã gửi tin nhắn thử nghiệm thành công! Hãy kiểm tra Telegram.'
                  : '❌ Gửi thất bại! Hãy kiểm tra lại Token hoặc Chat ID.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingTest = false);
      }
    }
  }

  void _toggleThreshold(double val) {
    setState(() {
      if (_alertThresholds.contains(val)) {
        if (_alertThresholds.length > 1) {
          _alertThresholds.remove(val);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF21262D),
              content: Text(
                'Bạn phải chọn ít nhất 1 mốc cảnh báo!',
                style: TextStyle(color: Colors.white),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _alertThresholds.add(val);
      }
    });
  }

  void _addCustomThreshold() {
    final text = _customThresholdController.text.trim();
    final val = double.tryParse(text);
    if (val != null && val > 0 && val <= 1000) {
      setState(() {
        _alertThresholds.add(val);
        _customThresholdController.clear();
      });
    }
  }

  void _addTokenToBlacklist() {
    final token = _addTokenController.text.trim().toUpperCase();
    if (token.isNotEmpty && !_blacklist.contains(token)) {
      setState(() {
        _blacklist.add(token);
        _addTokenController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSelected = _alertThresholds.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A22),
        elevation: 0,
        title: const Text(
          'Cài Đặt',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Cảnh Báo Nhiều Mốc Tăng Trưởng (Multi-Threshold Alert)
          _buildSectionHeader('CẢNH BÁO TĂNG TRƯỞNG (CHỌN NHIỀU MỐC)'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Các mốc đang kích hoạt',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nhấn vào mốc để bật/tắt (chọn được nhiều mốc cùng lúc)',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E676)),
                      ),
                      child: Text(
                        sortedSelected.map((e) => '+${e.toStringAsFixed(e % 1 == 0 ? 0 : 1)}%').join(', '),
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Preset Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetThresholds.map((preset) {
                    final isSelected = _alertThresholds.contains(preset);
                    return GestureDetector(
                      onTap: () => _toggleThreshold(preset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00E676) : const Color(0xFF30363D),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.25),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check, color: Color(0xFF00E676), size: 14),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '+${preset.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF00E676) : const Color(0xFF8B949E),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),
                // Custom milestone input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customThresholdController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Thêm mốc tùy chỉnh (ví dụ: 12 hoặc 35)',
                          hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addCustomThreshold,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Thêm mốc'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  '💡 Khi coin tăng chạm 15% bạn sẽ nhận 1 thông báo; nếu tiếp tục bay chạm 20% app sẽ gửi tiếp thông báo mốc 20%.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
          // 1b. Thông báo trực tiếp trên iPhone (Apple Web Push)
          _buildSectionHeader('THÔNG BÁO TRỰC TIẾP TRÊN IPHONE (APPLE WEB PUSH)'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bật thông báo trên iPhone',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chuông rung & banner màn hình khóa không cần Telegram',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_isWebPushLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                      )
                    else
                      Switch(
                        value: _isWebPushSubscribed,
                        activeThumbColor: const Color(0xFF00E676),
                        onChanged: (val) => _toggleWebPush(val),
                      ),
                  ],
                ),
                if (_isWebPushSubscribed) ...[
                  const Divider(color: Color(0xFF30363D), height: 24),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thiết bị đã sẵn sàng! Khi có coin bay chạm mốc, iPhone sẽ đổ chuông & hiện thông báo.',
                            style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isWebPushTesting ? null : _testWebPush,
                      icon: _isWebPushTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                            )
                          : const Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF00E676)),
                      label: Text(
                        _isWebPushTesting ? 'Đang gửi...' : 'Test chuông & banner trên iPhone',
                        style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E676)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ] else if (!_isWebPushSupported) ...[
                  const Divider(color: Color(0xFF30363D), height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.apple, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Dành riêng cho iPhone (iOS 16.4+):',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Apple chỉ cho phép thông báo khi web được thêm vào Màn hình chính:\n'
                          '1. Mở trang này bằng trình duyệt Safari.\n'
                          '2. Bấm nút Chia sẻ (biểu tượng ⬆️) -> Chọn "Thêm vào MH chính".\n'
                          '3. Mở CoinPulse từ icon ngoài màn hình chính để bật thông báo chuông rung.',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Divider(color: Color(0xFF30363D), height: 20),
                  const Text(
                    '💡 Gạt bật công tắc phía trên để iPhone cấp quyền hiển thị banner và chuông rung khi có biến động.',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 1c. Thông báo Telegram (Cho iPhone & Android)
          _buildSectionHeader('THÔNG BÁO TELEGRAM (CHO IPHONE & BẠN BÈ)'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gửi cảnh báo qua Telegram',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tự động bắn tin nhắn chuông rung sang iPhone khi có coin bay',
                            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _telegramEnabled,
                      activeThumbColor: const Color(0xFF00E676),
                      onChanged: (val) {
                        setState(() {
                          _telegramEnabled = val;
                        });
                      },
                    ),
                  ],
                ),
                if (_telegramEnabled) ...[
                  const Divider(color: Color(0xFF30363D), height: 24),
                  const Text(
                    'Bot Token (từ @BotFather)',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _telegramTokenController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Nhập Bot Token',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chat ID (từ @userinfobot hoặc ID Nhóm)',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _telegramChatIdController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Nhập Chat ID (ví dụ: 6437919028)',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0D1117),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSendingTest ? null : _testTelegram,
                      icon: _isSendingTest
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                            )
                          : const Icon(Icons.send_rounded, size: 16, color: Color(0xFF00E676)),
                      label: Text(
                        _isSendingTest ? 'Đang gửi...' : 'Gửi tin nhắn thử nghiệm',
                        style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00E676)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Ranking Top N Section (5..50)
          _buildSectionHeader('BẢNG XẾP HẠNG (RANKING)'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Số lượng coin hiển thị',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    Text(
                      'Top $_topN',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Slider(
                  value: _topN.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 45,
                  activeColor: const Color(0xFF00E676),
                  inactiveColor: const Color(0xFF30363D),
                  label: '$_topN',
                  onChanged: (val) {
                    setState(() {
                      _topN = val.round();
                    });
                  },
                ),
                const Center(
                  child: Text(
                    'Tối thiểu: 5  •  Mặc định: 10  •  Tối đa: 50',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Minimum Volume Section
          _buildSectionHeader('BỘ LỌC THANH KHOẢN (24H VOLUME)'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Khối lượng tối thiểu',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    Text(
                      '\$${(_minVolume / 1e6).toStringAsFixed(1)}M USDT',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPresetButton(1000000.0, '1M'),
                    _buildPresetButton(3000000.0, '3M'),
                    _buildPresetButton(5000000.0, '5M (Mặc định)'),
                    _buildPresetButton(10000000.0, '10M'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Blacklist Section
          _buildSectionHeader('DANH SÁCH LOẠI TRỪ (STABLECOIN / FIAT)'),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addTokenController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Nhập mã token (ví dụ: USDC, EUR)',
                          hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTokenToBlacklist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Thêm'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _blacklist.map((token) {
                    return Chip(
                      label: Text(
                        token,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: const Color(0xFF21262D),
                      deleteIconColor: const Color(0xFFF85149),
                      onDeleted: () {
                        setState(() {
                          _blacklist.remove(token);
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFF30363D)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Thị Trường
          _buildSectionHeader('THỊ TRƯỜNG (MARKET)'),
          _buildCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cặp giao dịch',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'USDT (Cố định V1)',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(double val, String label) {
    final isSelected = (_minVolume - val).abs() < 1.0;
    return GestureDetector(
      onTap: () {
        setState(() {
          _minVolume = val;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E676) : const Color(0xFF30363D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E676) : const Color(0xFF8B949E),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8B949E),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: child,
    );
  }
}
