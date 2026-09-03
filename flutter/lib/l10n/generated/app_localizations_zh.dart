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

  @override
  String get appLogoShort => 'Neko歌姬';

  @override
  String get appFooter => 'Neko歌姬计划';

  @override
  String get localPlaylists => '本地歌单';

  @override
  String get emptyLocalPlaylists => '暂无本地歌单';

  @override
  String get newLocalPlaylist => '新建本地歌单';

  @override
  String get myPlaylists => '我的歌单';

  @override
  String get emptyMyPlaylists => '暂无歌单，点下方创建';

  @override
  String get createPlaylist => '创建歌单';

  @override
  String get importNeteasePlaylist => '导入网易云歌单';

  @override
  String get importQqPlaylist => '导入 QQ 歌单';

  @override
  String get favPlaylists => '收藏的歌单';

  @override
  String get emptyFavPlaylists => '暂无收藏的歌单';

  @override
  String get deviceSync => '设备同步';

  @override
  String get rename => '重命名';

  @override
  String get deletePlaylist => '删除歌单';

  @override
  String get renamePlaylistTitle => '重命名歌单';

  @override
  String get inputName => '歌单名称';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get create => '创建';

  @override
  String get needLoginImport => '导入歌单需要先登录';

  @override
  String get needLoginCreateCloud => '创建云端歌单需要先登录';

  @override
  String playlistCountSongs(Object n) {
    return '$n 首';
  }

  @override
  String get close => '关闭';

  @override
  String get back => '返回';

  @override
  String get favorite => '收藏';

  @override
  String get download => '下载';

  @override
  String get addToPlaylist => '加入歌单';

  @override
  String get addToPlaylistFailed => '加入歌单失败';

  @override
  String get noLyrics => '暂无歌词';

  @override
  String get queueTitle => '播放队列';

  @override
  String get collapseQueue => '收起队列';

  @override
  String get clearQueue => '清空队列';

  @override
  String get queueEmpty => '队列为空';

  @override
  String get queueEmptyHint => '从列表中添加歌曲开始播放';

  @override
  String get playModeColon => '播放模式：';

  @override
  String get needLogin => '需登录';

  @override
  String get lanEmpty => '局域网内暂无其他设备';

  @override
  String get lanLoginHint => '登录后自动发现同账号设备';

  @override
  String get lanRemotePlaying => '远端播放中';

  @override
  String get lanRemoteQueue => '远端队列';

  @override
  String get lanTakeover => '接管并播放';

  @override
  String lanNowPlaying(Object id) {
    return '正在播放 #$id';
  }

  @override
  String get lanEmptyTag => '空';

  @override
  String remoteQueueSubtitle(Object count, Object title) {
    return '$count 首 · $title';
  }

  @override
  String get search => '搜索';

  @override
  String searchTotalSongs(Object total) {
    return '找到 $total 首';
  }

  @override
  String get tabSongs => '单曲';

  @override
  String get tabPlaylists => '歌单';

  @override
  String get tabArtists => '歌手';

  @override
  String get searchStartHint => '输入关键字开始搜索';

  @override
  String get searchNoSongs => '未找到相关歌曲';

  @override
  String get searchNoPlaylists => '未找到相关歌单';

  @override
  String get searchNoArtists => '未找到相关歌手';

  @override
  String get unknownArtist => '未知歌手';

  @override
  String songCountN(Object count) {
    return '$count 首歌';
  }

  @override
  String get viewArtist => '查看歌手';

  @override
  String get shuffleAgain => '换一批';

  @override
  String get dailyShuffleHint => '点击「换一批」获取每日推荐';

  @override
  String get myFavorites => '我的收藏';

  @override
  String get loginHintFavorites => '登录后显示云端收藏';

  @override
  String get emptyFavorites => '暂无收藏';

  @override
  String get emptyRecents => '暂无播放记录';

  @override
  String downloadsActiveN(Object n) {
    return '正在下载 $n';
  }

  @override
  String downloadsDoneN(Object n) {
    return '已完成 $n';
  }

  @override
  String get cancelAllDownloads => '全部取消';

  @override
  String get playAll => '播放全部';

  @override
  String get noActiveDownloads => '没有进行中的下载';

  @override
  String get queuing => '排队中…';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get emptyDownloads => '暂无已下载的音乐';

  @override
  String get play => '播放';

  @override
  String get openContainingFolder => '打开所在文件夹';
}
