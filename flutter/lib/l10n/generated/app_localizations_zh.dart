// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Neko歌姬计划';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsLanguage => '语言 / Language';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsDarkTheme => '深色主题';

  @override
  String get settingsDarkThemeHint => '切换应用配色，写入 ~/.nekomusic/settings.json';

  @override
  String get settingsBackdropCustomize => '背景个性化';

  @override
  String get settingsBackdropHint => '默认主题背景 / 纯色 / 自定义图片';

  @override
  String get settingsBackdropFollowTheme => '跟随主题';

  @override
  String get settingsBackdropSolid => '纯色';

  @override
  String get settingsBackdropImage => '自定义图片';

  @override
  String get settingsBackdropColor => '背景颜色';

  @override
  String get settingsBackdropImageTitle => '背景图片';

  @override
  String get settingsBackdropNotSet => '未设置';

  @override
  String get settingsBackdropRemove => '移除';

  @override
  String get settingsShortcuts => '快捷键';

  @override
  String get settingsShortcutPlayPause => '播放 / 暂停';

  @override
  String get settingsShortcutNext => '下一首';

  @override
  String get settingsShortcutPrev => '上一首';

  @override
  String get settingsShortcutHint => '快捷键在应用获得焦点时生效；如需更改按键组合请前往原版桌面端设置。';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAppSubtitle => '高品质无损云音乐播放器';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsGithubRepo => 'GitHub 仓库';

  @override
  String get settingsGithubCopied => '仓库链接已复制';

  @override
  String get settingsCheckUpdate => '检查更新';

  @override
  String get settingsUpToDate => '当前已是最新版本 1.0.0';

  @override
  String get settingsBackdropColorPickerTitle => '选择背景颜色';

  @override
  String get settingsBackdropImagePathTitle => '背景图片路径';

  @override
  String get settingsBackdropImageFormatHint => '支持 png / jpg / webp 图片文件';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsApply => '应用';

  @override
  String get settingsFileNotFound => '文件不存在';

  @override
  String get searchHint => '搜索音乐 / 歌单 / 歌手';

  @override
  String get settingsTooltip => '设置';

  @override
  String get engineErrorPrefix => '播放引擎异常：';

  @override
  String get playerIdleTitle => '未在播放';

  @override
  String get playModeTooltip => '播放模式';

  @override
  String get playModeList => '顺序播放';

  @override
  String get playModeLoop => '列表循环';

  @override
  String get playModeSingle => '单曲循环';

  @override
  String get playModeRandom => '随机播放';

  @override
  String get prevTrack => '上一首';

  @override
  String get nextTrack => '下一首';

  @override
  String get navHome => '首页';

  @override
  String get navFavorites => '我喜欢的';

  @override
  String get navRecents => '最近播放';

  @override
  String get navDownloads => '下载管理';

  @override
  String get actionRefresh => '刷新';

  @override
  String get homeRecPlaylists => '推荐歌单';

  @override
  String get homeEmptyPlaylists => '暂无推荐歌单';

  @override
  String get homeHot => '热门音乐';

  @override
  String get homeLatest => '最新音乐';

  @override
  String homeCountSongs(Object count) {
    return '$count 首';
  }

  @override
  String get homeDailyTitle => '每日推荐';

  @override
  String get homeDailySubtitle => '根据你的音乐口味 · 每日更新';
}
