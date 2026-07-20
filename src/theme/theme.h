#pragma once

/**
 * @file theme.h
 * @brief NekoMusic 桌面端主题常量（参考 SPlayer 简约布局 + 玫红主色）
 *
 * 玫红强调 + 樱花粉描边 + 薄荷/天蓝焦点环；无 emoji。尺寸与动画集中于此。
 */

#include <QColor>

namespace Theme
{

    // ─── 主色：玫红（与 Android Color.kt RoseRed / LightRose 一致）────────
    constexpr const char *kLavender = "#F05E7A";   // 主强调（沿用旧名以免全工程改名）
    constexpr const char *kLavenderLt = "#FF879D";
    constexpr const char *kLavenderDk = "#D84B63";

    // ─── 辅色：樱花粉（玻璃描边 / 弱高亮）────────────────────────────
    constexpr const char *kSakura = "#F2B2BF";
    constexpr const char *kSakuraLt = "#F7CDD6";
    constexpr const char *kSakuraDk = "#D98E9F";

    // ─── 点缀：薄荷绿（焦点 / 侧栏选中条）────────────────────────────
    constexpr const char *kMint = "#7D9CA4";
    constexpr const char *kMintLt = "#9FB5BC";
    constexpr const char *kMintDk = "#5F7A81";

    // ─── 背景（SPlayer 式中性深灰 + surface 容器）────────────────────
    constexpr const char *kBgDeep = "#101217";
    constexpr const char *kBgMid = "#161A21";
    constexpr const char *kBgSurface = "#1C212A";

    // ─── 文字 ────────────────────────────────────────────────────────
    constexpr const char *kTextMain = "#F4F6FF";
    constexpr const char *kTextSub = "rgba(244, 246, 255, 168)";
    constexpr const char *kTextMuted = "rgba(244, 246, 255, 105)";

    // ─── 毛玻璃（基于新 surface）────────────────────────────────────
    constexpr const char *kGlassBg = "rgba(28, 31, 38, 232)";
    constexpr const char *kGlassSidebar = "rgba(22, 25, 31, 242)";
    constexpr const char *kGlassPlayer = "rgba(22, 25, 31, 246)";
    constexpr const char *kGlassOverlay = "rgba(16, 18, 23, 220)";

    // ─── 边框（樱花粉半透明，呼应 Android GlassSurface 描边）──────────
    constexpr const char *kBorderGlass = "rgba(242, 178, 191, 48)";
    constexpr const char *kBorderFocus = "rgba(240, 94, 122, 120)";

    // ─── 渐变（QSS）──────────────────────────────────────────────────
    constexpr const char *kGradMain = "qlineargradient(x1:0,y1:0,x2:0.28,y2:1,"
                                      "stop:0 #FF879D, stop:1 #D84B63)";
    constexpr const char *kGradSakura = "qlineargradient(x1:0,y1:0,x2:0.3,y2:1,"
                                          "stop:0 #F7CDD6, stop:1 #E6AEBB)";
    constexpr const char *kGradMint = "qlineargradient(x1:0,y1:0,x2:0.3,y2:1,"
                                        "stop:0 #9FB5BC, stop:1 #7D9CA4)";
    constexpr const char *kGradBg = "qlineargradient(x1:0,y1:0,x2:0,y2:1,"
                                    "stop:0 #101217, stop:1 #0B0D11)";

    // ─── 布局尺寸（对齐 SPlayer：侧栏 240 / 顶栏 56 / 底栏 80）────────
    constexpr int kSidebarW = 240;
    constexpr int kTitleBarH = 56;
    /** 底栏可见高度（SPlayer .main-player height: 80px） */
    constexpr int kPlayerBarBodyH = 80;
    /** 进度条向上悬出，叠在内容区底边（SPlayer .player-slider top: -8px） */
    constexpr int kPlayerBarSliderOverhang = 8;
    constexpr int kPlayerBarH = kPlayerBarBodyH;
    constexpr int kCoverSmall = 144;
    constexpr int kCoverRadius = 14;

    // ─── 圆角 ──────────────────────────────────────────────────────
    constexpr int kRSm = 10;
    constexpr int kRMd = 14;
    constexpr int kRLg = 18;
    constexpr int kRXl = 22;

    // ─── 动画 (ms) ─────────────────────────────────────────────────
    constexpr int kAnimFast = 150;
    constexpr int kAnimNormal = 250;
    constexpr int kAnimSlow = 400;
    constexpr int kCarouselMs = 5000;

    constexpr const char *kApiBase = "https://music.cnmsb.xin";

} // namespace Theme
