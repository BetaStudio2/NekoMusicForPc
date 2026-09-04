import 'neko_icons.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../core/core_controller.dart';
import '../l10n/generated/app_localizations.dart';

/// 会员中心：左侧套餐列表，右侧扫码支付。
/// 数据流：vipPricing() → 选套餐/支付方式 → vipPayCreate() → 展示二维码。
class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  AppLocalizations get _l10n => AppLocalizations.of(context);
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _creating = false;
  String? _error;
  int? _selectedPlanId;
  String _payType = 'alipay';
  bool _isVip = false;
  String _vipExpiresAt = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final core = CoreScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    core.vipPricing(onDone: (ok, items, msg) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (ok) {
          _plans = items;
          if (_plans.isNotEmpty && _selectedPlanId == null) {
            _selectedPlanId = (_plans.first['id'] as num).toInt();
          }
        } else {
          _error = msg.isEmpty ? _l10n.loadFailed : msg;
        }
      });
    });
    core.vipSyncStatus(onDone: (ok, isVip, expires) {
      if (!mounted) return;
      setState(() {
        _isVip = ok && isVip;
        _vipExpiresAt = ok ? expires : '';
      });
    });
  }

  String _formatPlanLabel(Map<String, dynamic> p) {
    final months = (p['months'] as num?)?.toInt() ?? 0;
    final days = (p['days'] as num?)?.toInt() ?? 0;
    final name = p['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    if (months > 0) return _l10n.monthsN(months);
    if (days > 0) return _l10n.daysN(days);
    return 'VIP';
  }

  void _createOrder() {
    final id = _selectedPlanId;
    if (id == null) return;
    final core = CoreScope.of(context);
    setState(() {
      _creating = true;
      _order = null;
      _error = null;
    });
    core.vipPayCreate(id, payType: _payType, onDone: (ok, order, msg) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        if (ok && order != null) {
          _order = order;
        } else {
          _error = msg.isEmpty ? _l10n.createOrderFailed : msg;
        }
      });
    });
  }

  /// 二维码：优先用订单 img 字段（QR 图片 URL），否则用在线 QR API 编码文本。
  String? _qrUrl() {
    const apiBase = 'https://music.cnmsb.xin';
    final order = _order;
    if (order == null) return null;
    final img = order['img']?.toString();
    if (img != null && img.isNotEmpty) {
      return img.startsWith('http') ? img : '$apiBase$img';
    }
    final text = (order['qrcode'] ?? order['payurl'] ?? order['payurl2'])
        ?.toString();
    if (text == null || text.isEmpty) return null;
    return 'https://api.qrserver.com/v1/create-qr-code/'
        '?size=220x220&data=${Uri.encodeComponent(text)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgSurface,
      appBar: AppBar(
        backgroundColor: kBgSurface,
        title: Text(_l10n.vipCenter),
        centerTitle: false,
        actions: [
          if (_isVip)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  avatar: const Icon(NekoIcons.VipBadge,
                      color: Color(0xFFFFB300), size: 18),
                  label: Text(
                    _vipExpiresAt.isNotEmpty
                        ? _l10n.vipUntil(_vipExpiresAt)
                        : _l10n.vipMember,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: const Color(0x33FFB300),
                  side: BorderSide.none,
                ),
              ),
            )
          else
            IconButton(
              tooltip: _l10n.actionRefresh,
              icon: const Icon(NekoIcons.Refresh),
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? Center(
                  child: Text(
                    _error ?? _l10n.noPlans,
                    style: TextStyle(color: kTextSecondary),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左：hero + 套餐选择条
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _heroCard(),
                            const SizedBox(height: 22),
                            Text(_l10n.choosePlan,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final p in _plans) ...[
                                    _buildPlanMini(p),
                                    const SizedBox(width: 10),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      // 右：结账面板（所选套餐/价格 + 支付方式 + 开通 + 扫码）
                      SizedBox(
                        width: 360,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: kBgMid,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(_l10n.payMethod,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: _buildPayType(
                                              'alipay', _l10n.alipay)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildPayType(
                                              'wxpay', _l10n.wechatPay)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: kPrimary,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size.fromHeight(46)),
                                    onPressed:
                                        _creating ? null : _createOrder,
                                    icon: _creating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2))
                                        : const Icon(NekoIcons.Payment),
                                    label: Text(_creating
                                        ? _l10n.creatingOrder
                                        : _l10n.activateNow),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 10),
                                    Text('$_error',
                                        style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12)),
                                  ],
                                  const SizedBox(height: 14),
                                  Divider(height: 1, color: kDivider),
                                  const SizedBox(height: 14),
                                  _buildCheckoutPlan(),
                                  if (_order == null)
                                    Column(
                                      children: [
                                        Icon(NekoIcons.QrCode,
                                            size: 48,
                                            color: kTextMuted),
                                        const SizedBox(height: 10),
                                        Text(_l10n.qrHint,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: kTextSecondary,
                                                fontSize: 12)),
                                      ],
                                    )
                                  else ...[
                                    Text(
                                      _l10n.scanPayN(_payType == 'alipay'
                                          ? _l10n.alipay
                                          : _l10n.wechatPay),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: kTextSecondary),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildQr(),
                                    const SizedBox(height: 8),
                                    Text(
                                      _l10n.scanToPay,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12, color: kTextMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// 顶部 VIP hero（克制深色卡片：标题 + 状态副标题）
  Widget _heroCard() {
    final t = ThemeController.instance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: kBgDeep.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          const Icon(NekoIcons.VipBadge,
              size: 30, color: Color(0xFFFFB300)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_l10n.vipMember,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  _isVip && _vipExpiresAt.isNotEmpty
                      ? _l10n.vipUntil(_vipExpiresAt)
                      : t.t('开通后畅享高品质音乐', 'Unlock high-quality music'),
                  style: TextStyle(
                      fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 套餐迷你卡（对齐 Qt plan strip）
  /// 结账面板中的所选套餐摘要
  Widget _buildCheckoutPlan() {
    final sel = _plans.where((p) =>
        (p['id'] as num).toInt() == _selectedPlanId);
    if (sel.isEmpty) return const SizedBox.shrink();
    final p = sel.first;
    final price = (p['priceYuan'] as num?)?.toDouble() ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_formatPlanLabel(p),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(
          '¥${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9800)),
        ),
      ],
    );
  }

  Widget _buildPlanMini(Map<String, dynamic> p) {
    final id = (p['id'] as num).toInt();
    final price = (p['priceYuan'] as num?)?.toDouble() ?? 0;
    final selected = _selectedPlanId == id;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedPlanId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 116,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.10) : kBgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? kPrimary : kDivider, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatPlanLabel(p),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? kPrimary : kTextPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> p) {
    final id = (p['id'] as num).toInt();
    final price = (p['priceYuan'] as num?)?.toDouble() ?? 0;
    final selected = _selectedPlanId == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedPlanId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? kPrimary.withValues(alpha: 0.12) : kBgMid,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kPrimary : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? NekoIcons.Radio
                    : NekoIcons.RadioBlank,
                size: 18,
                color: selected ? kPrimary : kTextMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatPlanLabel(p),
                  style: TextStyle(
                      fontSize: 14,
                      color: selected ? kPrimary : kTextPrimary),
                ),
              ),
              Text(
                '¥${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF9800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayType(String value, String label) {
    final selected = _payType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _payType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kPrimary.withValues(alpha: 0.12) : kBgMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? kPrimary : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, color: selected ? kPrimary : kTextSecondary)),
      ),
    );
  }

  Widget _buildQr() {
    final url = _qrUrl();
    if (url == null) {
      return Text(_l10n.payInfoMissing,
          style: TextStyle(color: kTextMuted, fontSize: 13));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 220,
        height: 220,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 220,
            height: 220,
            color: kBgMid,
            child: const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        },
        errorBuilder: (context, error, stack) {
          // 本地生成兜底二维码
          final text = (_order?['qrcode'] ?? _order?['payurl'])
              ?.toString();
          if (text != null && text.isNotEmpty) {
            return _buildFallbackQr(text);
          }
          return Container(
            width: 220,
            height: 220,
            color: kBgMid,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(NekoIcons.QrCode, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(_l10n.qrLoadFailed,
                    style: TextStyle(color: kTextMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_l10n.copyLinkHint, style: TextStyle(color: kTextMuted, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 无依赖的简单 QR 生成：渲染伪二维码 + 复制链接按钮（避免引入外部包）
  Widget _buildFallbackQr(String text) {
    return Column(
      children: [
        CustomPaint(
          size: const Size.square(140),
          painter: _PseudoQrPainter(text.hashCode),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(NekoIcons.Link, size: 14),
          label: Text(_l10n.copyPayLink, style: const TextStyle(fontSize: 12)),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_l10n.payLinkCopied), duration: const Duration(seconds: 1)));
            }
          },
        ),
      ],
    );
  }
}

/// 简单伪二维码（仅兜底展示，不代表真实内容）
class _PseudoQrPainter extends CustomPainter {
  const _PseudoQrPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    const n = 21;
    final cell = size.width / n;
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final v = (seed + x * 31 + y * 17 + x * y * 7) % 100;
        if (v < 45) {
          canvas.drawRect(
              Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
    // 三个定位角
    void finder(int fx, int fy) {
      canvas.drawRect(
          Rect.fromLTWH(fx * cell, fy * cell, 7 * cell, 7 * cell), paint);
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH((fx + 1) * cell, (fy + 1) * cell, 5 * cell, 5 * cell), paint);
      paint.color = Colors.black;
      canvas.drawRect(
          Rect.fromLTWH((fx + 2) * cell, (fy + 2) * cell, 3 * cell, 3 * cell), paint);
    }

    finder(0, 0);
    finder(n - 7, 0);
    finder(0, n - 7);
  }

  @override
  bool shouldRepaint(covariant _PseudoQrPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
