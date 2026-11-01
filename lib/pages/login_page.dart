import 'package:flutter/material.dart';

import '../api/netease_api.dart';
import '../app/app.dart';
import '../state/account_controller.dart';
import '../theme/app_theme.dart';

/// Cookie 登录。扫码、手机号登录待开发。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final account = AccountScope.read(context);
    try {
      final profile = await account.login(_input.text);
      if (!mounted) return;
      AppScope.toast('已登录：${profile.nickname}');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = AccountScope.of(context).busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Cookie 登录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '在电脑浏览器登录 music.163.com，打开开发者工具，复制请求头里的 Cookie 粘贴到下面。'
            '至少需要包含 MUSIC_U。',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cookie 只保存在本机，用来以你的账号请求网易云接口。请勿分享给他人。',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            minLines: 4,
            maxLines: 8,
            enabled: !busy,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'MUSIC_U=…; __csrf=…',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              minimumSize: const Size.fromHeight(48),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('验证并登录'),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Icon(Icons.qr_code_rounded, size: 18, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text('扫码登录、手机号登录：待开发', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 需要登录的页面在未登录时显示的占位。
class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => LoginPage.open(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
            ),
            child: const Text('Cookie 登录'),
          ),
        ],
      ),
    );
  }
}
