import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../core/core_controller.dart';

/// 登录对话框：登录 / 注册 两个 Tab。
/// 注册流程对齐原版：滑块验证 → 发送邮箱验证码 → 注册。
Future<void> showLoginDialog(BuildContext context) async {
  final core = CoreScope.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LoginDialog(core: core),
  );
}

/// 忘记密码对话框：邮箱 → 发送重置验证码 → 重置密码。
Future<void> showForgotPasswordDialog(BuildContext context) async {
  final core = CoreScope.of(context);
  await showDialog<void>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(core: core),
  );
}

/// 修改密码对话框（需已登录）。
Future<void> showChangePasswordDialog(BuildContext context) async {
  final core = CoreScope.of(context);
  await showDialog<void>(
    context: context,
    builder: (_) => _ChangePasswordDialog(core: core),
  );
}

// ── 登录 / 注册 ─────────────────────────────────────────────────────

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({required this.core});

  final CoreController core;

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  bool _registerMode = false;
  String? _error;
  bool _busy = false;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _captchaPassToken;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _login() {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.core.login(_username.text.trim(), _password.text,
        onDone: (ok) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          Navigator.of(context).pop();
        } else {
          _error = widget.core.error;
        }
      });
    });
  }

  void _sendCode() {
    final pass = _captchaPassToken;
    final email = _email.text.trim();
    final username = _username.text.trim();
    if (pass == null || pass.isEmpty) {
      setState(() => _error = '请先完成滑块验证');
      return;
    }
    if (email.isEmpty || !email.contains('@') || username.isEmpty) {
      setState(() => _error = '请先填写用户名和邮箱');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.core.sendVerification(email, username, pass, onDone: (ok, msg) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          _error = null;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('验证码已发送，请查收邮箱'),
            duration: Duration(seconds: 2),
          ));
        } else {
          _error = msg.isEmpty ? '验证码发送失败' : msg;
        }
      });
    });
  }

  void _register() {
    if (_username.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _email.text.trim().isEmpty ||
        _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.core.register(
        _username.text.trim(), _password.text, _email.text.trim(),
        _code.text.trim(), onDone: (ok, msg) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          Navigator.of(context).pop();
        } else {
          _error = msg.isEmpty ? '注册失败' : msg;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBgSurface,
      title: Text(_registerMode ? '注册' : '登录'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab 切换
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('登录')),
                  ButtonSegment(value: true, label: Text('注册')),
                ],
                selected: {_registerMode},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() {
                          _registerMode = s.first;
                          _error = null;
                        }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) =>
                    _registerMode ? _sendCode() : _login(),
              ),
              const SizedBox(height: 12),
              if (_registerMode) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _registerMode ? '密码' : '密码',
                  isDense: true,
                  filled: true,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _registerMode ? null : _login(),
              ),
              const SizedBox(height: 12),
              if (_registerMode) ...[
                _SliderCaptchaField(
                  core: widget.core,
                  onPassed: (token) {
                    _captchaPassToken = token;
                    setState(() => _error = null);
                  },
                  onError: (msg) => setState(() => _error = msg),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: '邮箱验证码',
                          isDense: true,
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimary.withValues(alpha: 0.15),
                        foregroundColor: kPrimary,
                      ),
                      onPressed: _busy ? null : _sendCode,
                      child: const Text('发送验证码'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kPrimary),
                  onPressed: _busy ? null : _register,
                  child: Text(_busy ? '注册中…' : '注册'),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => showForgotPasswordDialog(context),
                      child: const Text('忘记密码？',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text('$_error',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (!_registerMode)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            onPressed: _busy ? null : _login,
            child: Text(_busy ? '登录中…' : '登录'),
          ),
      ],
    );
  }
}

// ── 滑块验证码（对齐原版 SliderCaptchaDialog） ────────────────────────

class _SliderCaptchaField extends StatefulWidget {
  const _SliderCaptchaField({
    required this.core,
    required this.onPassed,
    required this.onError,
  });

  final CoreController core;
  final ValueChanged<String> onPassed;
  final ValueChanged<String> onError;

  @override
  State<_SliderCaptchaField> createState() => _SliderCaptchaFieldState();
}

class _SliderCaptchaFieldState extends State<_SliderCaptchaField> {
  Map<String, dynamic>? _data;
  double _offset = 0;
  bool _verifying = false;
  bool _passed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _data = null;
      _offset = 0;
      _passed = false;
    });
    widget.core.sliderChallenge(onDone: (ok, data, msg) {
      if (!mounted) return;
      if (!ok || data == null) {
        widget.onError(msg.isEmpty ? '滑块验证加载失败' : msg);
        return;
      }
      setState(() => _data = data);
    });
  }

  void _verify() {
    final data = _data;
    if (data == null || _verifying) return;
    final token = data['captchaToken']?.toString() ?? '';
    if (token.isEmpty) return;
    setState(() => _verifying = true);
    widget.core.sliderVerify(token, _offset.round(), onDone: (ok, pass, msg) {
      if (!mounted) return;
      setState(() => _verifying = false);
      if (ok && pass.isNotEmpty) {
        setState(() => _passed = true);
        widget.onPassed(pass);
      } else {
        widget.onError(msg.isEmpty ? '滑块验证失败，请重试' : msg);
        _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final bgW = (data?['bgWidth'] as num?)?.toDouble() ?? 300.0;
    final bgH = (data?['bgHeight'] as num?)?.toDouble() ?? 180.0;
    final pieceW = (data?['sliderWidth'] as num?)?.toDouble() ?? 52.0;
    final pieceH = (data?['sliderHeight'] as num?)?.toDouble() ?? 52.0;
    final puzzleY = (data?['puzzleY'] as num?)?.toDouble() ?? 60.0;

    Uint8List? bgBytes;
    Uint8List? pieceBytes;
    if (data != null) {
      bgBytes = _decodeDataUrl(data['bgImage']?.toString());
      pieceBytes = _decodeDataUrl(data['sliderImage']?.toString());
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBgMid,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _passed ? '✓ 滑块验证通过' : '请拖动滑块完成验证',
            style: TextStyle(
                fontSize: 12,
                color: _passed ? const Color(0xFF4CAF50) : kTextSecondary),
          ),
          const SizedBox(height: 8),
          if (data != null && (bgBytes == null || pieceBytes == null))
            // 数据已返回但图片解码失败：给出明确提示（避免空白卡住流程）
            Row(
              children: [
                Expanded(
                  child: Text('验证码图片加载失败，请点击右侧刷新重试',
                      style: TextStyle(
                          fontSize: 12, color: const Color(0xFFFF8A80))),
                ),
              ],
            ),
          if (bgBytes != null && pieceBytes != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final bg = bgBytes!;
                final piece = pieceBytes!;
                final scale = constraints.maxWidth / bgW;
                final scaledBgH = bgH * scale;
                final maxOffset = bgW - pieceW;
                return Column(
                  children: [
                    SizedBox(
                      height: scaledBgH,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(bg,
                                  fit: BoxFit.fill,
                                  gaplessPlayback: true),
                            ),
                          ),
                          if (!_passed)
                            Positioned(
                              left: _offset * scale,
                              top: puzzleY * scale,
                              width: pieceW * scale,
                              height: pieceH * scale,
                              child: Image.memory(piece,
                                  fit: BoxFit.fill, gaplessPlayback: true),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.keyboard_arrow_right_rounded,
                            size: 16, color: kTextMuted),
                        Expanded(
                          child: Slider(
                            value: _passed
                                ? maxOffset
                                : _offset.clamp(0.0, maxOffset),
                            max: maxOffset,
                            activeColor: kPrimary,
                            onChanged: _passed || _verifying
                                ? null
                                : (v) => setState(() => _offset = v),
                            onChangeEnd: (_) => _verify(),
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新',
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _verifying ? null : _load,
                        ),
                      ],
                    ),
                  ],
                );
              },
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
    );
  }

  static Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

// ── 忘记密码 ────────────────────────────────────────────────────────

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.core});

  final CoreController core;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  String? _error;
  bool _busy = false;
  int _countdown = 0;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _sendCode() {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '请输入有效邮箱');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.core.sendResetCode(email, onDone: (ok, msg) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          _startCountdown();
        } else {
          _error = msg.isEmpty ? '发送失败' : msg;
        }
      });
    });
  }

  void _startCountdown() {
    _countdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  void _reset() {
    if (_email.text.trim().isEmpty ||
        _code.text.trim().isEmpty ||
        _newPassword.text.length < 6) {
      setState(() => _error = '请填写邮箱、验证码和新密码（至少 6 位）');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.core.resetPassword(
        _email.text.trim(), _code.text.trim(), _newPassword.text,
        onDone: (ok, msg) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('密码已重置，请使用新密码登录'),
            duration: Duration(seconds: 2),
          ));
        } else {
          _error = msg.isEmpty ? '重置失败' : msg;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBgSurface,
      title: const Text('忘记密码'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '邮箱',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary.withValues(alpha: 0.15),
                    foregroundColor: kPrimary,
                  ),
                  onPressed: _busy || _countdown > 0 ? null : _sendCode,
                  child: Text(_countdown > 0 ? '$_countdown s' : '发送验证码'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密码',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('$_error',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kPrimary),
          onPressed: _busy ? null : _reset,
          child: Text(_busy ? '提交中…' : '重置密码'),
        ),
      ],
    );
  }
}

// ── 修改密码 ────────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.core});

  final CoreController core;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_old.text.isEmpty || _new.text.length < 6) {
      setState(() => _error = '请填写旧密码与新密码（至少 6 位）');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = '两次输入的新密码不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.core.changePassword(_old.text, _new.text, onDone: (ok, msg) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('密码修改成功'),
            duration: Duration(seconds: 2),
          ));
        } else {
          _error = msg.isEmpty ? '修改失败' : msg;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBgSurface,
      title: const Text('修改密码'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _old,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '旧密码',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密码',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认新密码',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('$_error',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kPrimary),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '提交中…' : '确认修改'),
        ),
      ],
    );
  }
}

/// 用户菜单：显示登录态，未登录弹登录框，已登录可改密/退出。
class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final core = CoreScope.of(context);
    return PopupMenuButton<String>(
      tooltip: '账户',
      icon: Icon(
        core.isLoggedIn ? Icons.account_circle : Icons.account_circle_outlined,
        color: core.isLoggedIn ? kPrimary : kTextSecondary,
      ),
      onSelected: (v) {
        switch (v) {
          case 'changePassword':
            showChangePasswordDialog(context);
          case 'logout':
            core.logout();
        }
      },
      itemBuilder: (context) => core.isLoggedIn
          ? [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  (core.userInfo?['username'] ?? core.userInfo?['nickname'] ?? '已登录')
                      .toString(),
                  style: TextStyle(color: kTextSecondary),
                ),
              ),
              const PopupMenuItem(
                  value: 'changePassword', child: Text('修改密码')),
              const PopupMenuItem(value: 'logout', child: Text('退出登录')),
            ]
          : [
              PopupMenuItem(
                value: 'login',
                child: const Text('登录'),
                onTap: () => showLoginDialog(context),
              ),
            ],
    );
  }
}
