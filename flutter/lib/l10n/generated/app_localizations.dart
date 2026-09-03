import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Neko歌姬计划'**
  String get appName;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGeneral;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言 / Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsDarkTheme.
  ///
  /// In zh, this message translates to:
  /// **'深色主题'**
  String get settingsDarkTheme;

  /// No description provided for @settingsDarkThemeHint.
  ///
  /// In zh, this message translates to:
  /// **'切换应用配色，写入 ~/.nekomusic/settings.json'**
  String get settingsDarkThemeHint;

  /// No description provided for @settingsBackdropCustomize.
  ///
  /// In zh, this message translates to:
  /// **'背景个性化'**
  String get settingsBackdropCustomize;

  /// No description provided for @settingsBackdropHint.
  ///
  /// In zh, this message translates to:
  /// **'默认主题背景 / 纯色 / 自定义图片'**
  String get settingsBackdropHint;

  /// No description provided for @settingsBackdropFollowTheme.
  ///
  /// In zh, this message translates to:
  /// **'跟随主题'**
  String get settingsBackdropFollowTheme;

  /// No description provided for @settingsBackdropSolid.
  ///
  /// In zh, this message translates to:
  /// **'纯色'**
  String get settingsBackdropSolid;

  /// No description provided for @settingsBackdropImage.
  ///
  /// In zh, this message translates to:
  /// **'自定义图片'**
  String get settingsBackdropImage;

  /// No description provided for @settingsBackdropColor.
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get settingsBackdropColor;

  /// No description provided for @settingsBackdropImageTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景图片'**
  String get settingsBackdropImageTitle;

  /// No description provided for @settingsBackdropNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get settingsBackdropNotSet;

  /// No description provided for @settingsBackdropRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get settingsBackdropRemove;

  /// No description provided for @settingsShortcuts.
  ///
  /// In zh, this message translates to:
  /// **'快捷键'**
  String get settingsShortcuts;

  /// No description provided for @settingsShortcutPlayPause.
  ///
  /// In zh, this message translates to:
  /// **'播放 / 暂停'**
  String get settingsShortcutPlayPause;

  /// No description provided for @settingsShortcutNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get settingsShortcutNext;

  /// No description provided for @settingsShortcutPrev.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get settingsShortcutPrev;

  /// No description provided for @settingsShortcutHint.
  ///
  /// In zh, this message translates to:
  /// **'快捷键在应用获得焦点时生效；如需更改按键组合请前往原版桌面端设置。'**
  String get settingsShortcutHint;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @settingsAppSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'高品质无损云音乐播放器'**
  String get settingsAppSubtitle;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @settingsGithubRepo.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库'**
  String get settingsGithubRepo;

  /// No description provided for @settingsGithubCopied.
  ///
  /// In zh, this message translates to:
  /// **'仓库链接已复制'**
  String get settingsGithubCopied;

  /// No description provided for @settingsCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsCheckUpdate;

  /// No description provided for @settingsUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本 1.0.0'**
  String get settingsUpToDate;

  /// No description provided for @settingsBackdropColorPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择背景颜色'**
  String get settingsBackdropColorPickerTitle;

  /// No description provided for @settingsBackdropImagePathTitle.
  ///
  /// In zh, this message translates to:
  /// **'背景图片路径'**
  String get settingsBackdropImagePathTitle;

  /// No description provided for @settingsBackdropImageFormatHint.
  ///
  /// In zh, this message translates to:
  /// **'支持 png / jpg / webp 图片文件'**
  String get settingsBackdropImageFormatHint;

  /// No description provided for @settingsCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get settingsCancel;

  /// No description provided for @settingsApply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get settingsApply;

  /// No description provided for @settingsFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'文件不存在'**
  String get settingsFileNotFound;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索音乐 / 歌单 / 歌手'**
  String get searchHint;

  /// No description provided for @settingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTooltip;

  /// No description provided for @engineErrorPrefix.
  ///
  /// In zh, this message translates to:
  /// **'播放引擎异常：'**
  String get engineErrorPrefix;

  /// No description provided for @playerIdleTitle.
  ///
  /// In zh, this message translates to:
  /// **'未在播放'**
  String get playerIdleTitle;

  /// No description provided for @playModeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'播放模式'**
  String get playModeTooltip;

  /// No description provided for @playModeList.
  ///
  /// In zh, this message translates to:
  /// **'顺序播放'**
  String get playModeList;

  /// No description provided for @playModeLoop.
  ///
  /// In zh, this message translates to:
  /// **'列表循环'**
  String get playModeLoop;

  /// No description provided for @playModeSingle.
  ///
  /// In zh, this message translates to:
  /// **'单曲循环'**
  String get playModeSingle;

  /// No description provided for @playModeRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get playModeRandom;

  /// No description provided for @prevTrack.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get prevTrack;

  /// No description provided for @nextTrack.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get nextTrack;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我喜欢的'**
  String get navFavorites;

  /// No description provided for @navRecents.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get navRecents;

  /// No description provided for @navDownloads.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get navDownloads;

  /// No description provided for @actionRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get actionRefresh;

  /// No description provided for @homeRecPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'推荐歌单'**
  String get homeRecPlaylists;

  /// No description provided for @homeEmptyPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无推荐歌单'**
  String get homeEmptyPlaylists;

  /// No description provided for @homeHot.
  ///
  /// In zh, this message translates to:
  /// **'热门音乐'**
  String get homeHot;

  /// No description provided for @homeLatest.
  ///
  /// In zh, this message translates to:
  /// **'最新音乐'**
  String get homeLatest;

  /// No description provided for @homeCountSongs.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String homeCountSongs(Object count);

  /// No description provided for @homeDailyTitle.
  ///
  /// In zh, this message translates to:
  /// **'每日推荐'**
  String get homeDailyTitle;

  /// No description provided for @homeDailySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据你的音乐口味 · 每日更新'**
  String get homeDailySubtitle;

  /// No description provided for @appLogoShort.
  ///
  /// In zh, this message translates to:
  /// **'Neko歌姬'**
  String get appLogoShort;

  /// No description provided for @appFooter.
  ///
  /// In zh, this message translates to:
  /// **'Neko歌姬计划'**
  String get appFooter;

  /// No description provided for @localPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'本地歌单'**
  String get localPlaylists;

  /// No description provided for @emptyLocalPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无本地歌单'**
  String get emptyLocalPlaylists;

  /// No description provided for @newLocalPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'新建本地歌单'**
  String get newLocalPlaylist;

  /// No description provided for @myPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'我的歌单'**
  String get myPlaylists;

  /// No description provided for @emptyMyPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌单，点下方创建'**
  String get emptyMyPlaylists;

  /// No description provided for @createPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'创建歌单'**
  String get createPlaylist;

  /// No description provided for @importNeteasePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'导入网易云歌单'**
  String get importNeteasePlaylist;

  /// No description provided for @importQqPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'导入 QQ 歌单'**
  String get importQqPlaylist;

  /// No description provided for @favPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'收藏的歌单'**
  String get favPlaylists;

  /// No description provided for @emptyFavPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏的歌单'**
  String get emptyFavPlaylists;

  /// No description provided for @deviceSync.
  ///
  /// In zh, this message translates to:
  /// **'设备同步'**
  String get deviceSync;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @deletePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'删除歌单'**
  String get deletePlaylist;

  /// No description provided for @renamePlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名歌单'**
  String get renamePlaylistTitle;

  /// No description provided for @inputName.
  ///
  /// In zh, this message translates to:
  /// **'歌单名称'**
  String get inputName;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @needLoginImport.
  ///
  /// In zh, this message translates to:
  /// **'导入歌单需要先登录'**
  String get needLoginImport;

  /// No description provided for @needLoginCreateCloud.
  ///
  /// In zh, this message translates to:
  /// **'创建云端歌单需要先登录'**
  String get needLoginCreateCloud;

  /// No description provided for @playlistCountSongs.
  ///
  /// In zh, this message translates to:
  /// **'{n} 首'**
  String playlistCountSongs(Object n);

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorite;

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @addToPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'加入歌单'**
  String get addToPlaylist;

  /// No description provided for @addToPlaylistFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入歌单失败'**
  String get addToPlaylistFailed;

  /// No description provided for @noLyrics.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get noLyrics;

  /// No description provided for @queueTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get queueTitle;

  /// No description provided for @collapseQueue.
  ///
  /// In zh, this message translates to:
  /// **'收起队列'**
  String get collapseQueue;

  /// No description provided for @clearQueue.
  ///
  /// In zh, this message translates to:
  /// **'清空队列'**
  String get clearQueue;

  /// No description provided for @queueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'队列为空'**
  String get queueEmpty;

  /// No description provided for @queueEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'从列表中添加歌曲开始播放'**
  String get queueEmptyHint;

  /// No description provided for @playModeColon.
  ///
  /// In zh, this message translates to:
  /// **'播放模式：'**
  String get playModeColon;

  /// No description provided for @needLogin.
  ///
  /// In zh, this message translates to:
  /// **'需登录'**
  String get needLogin;

  /// No description provided for @lanEmpty.
  ///
  /// In zh, this message translates to:
  /// **'局域网内暂无其他设备'**
  String get lanEmpty;

  /// No description provided for @lanLoginHint.
  ///
  /// In zh, this message translates to:
  /// **'登录后自动发现同账号设备'**
  String get lanLoginHint;

  /// No description provided for @lanRemotePlaying.
  ///
  /// In zh, this message translates to:
  /// **'远端播放中'**
  String get lanRemotePlaying;

  /// No description provided for @lanRemoteQueue.
  ///
  /// In zh, this message translates to:
  /// **'远端队列'**
  String get lanRemoteQueue;

  /// No description provided for @lanTakeover.
  ///
  /// In zh, this message translates to:
  /// **'接管并播放'**
  String get lanTakeover;

  /// No description provided for @lanNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放 #{id}'**
  String lanNowPlaying(Object id);

  /// No description provided for @lanEmptyTag.
  ///
  /// In zh, this message translates to:
  /// **'空'**
  String get lanEmptyTag;

  /// No description provided for @remoteQueueSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首 · {title}'**
  String remoteQueueSubtitle(Object count, Object title);

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @searchTotalSongs.
  ///
  /// In zh, this message translates to:
  /// **'找到 {total} 首'**
  String searchTotalSongs(Object total);

  /// No description provided for @tabSongs.
  ///
  /// In zh, this message translates to:
  /// **'单曲'**
  String get tabSongs;

  /// No description provided for @tabPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get tabPlaylists;

  /// No description provided for @tabArtists.
  ///
  /// In zh, this message translates to:
  /// **'歌手'**
  String get tabArtists;

  /// No description provided for @searchStartHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键字开始搜索'**
  String get searchStartHint;

  /// No description provided for @searchNoSongs.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关歌曲'**
  String get searchNoSongs;

  /// No description provided for @searchNoPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关歌单'**
  String get searchNoPlaylists;

  /// No description provided for @searchNoArtists.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关歌手'**
  String get searchNoArtists;

  /// No description provided for @unknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知歌手'**
  String get unknownArtist;

  /// No description provided for @songCountN.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌'**
  String songCountN(Object count);

  /// No description provided for @viewArtist.
  ///
  /// In zh, this message translates to:
  /// **'查看歌手'**
  String get viewArtist;

  /// No description provided for @shuffleAgain.
  ///
  /// In zh, this message translates to:
  /// **'换一批'**
  String get shuffleAgain;

  /// No description provided for @dailyShuffleHint.
  ///
  /// In zh, this message translates to:
  /// **'点击「换一批」获取每日推荐'**
  String get dailyShuffleHint;

  /// No description provided for @myFavorites.
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get myFavorites;

  /// No description provided for @loginHintFavorites.
  ///
  /// In zh, this message translates to:
  /// **'登录后显示云端收藏'**
  String get loginHintFavorites;

  /// No description provided for @emptyFavorites.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get emptyFavorites;

  /// No description provided for @emptyRecents.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放记录'**
  String get emptyRecents;

  /// No description provided for @downloadsActiveN.
  ///
  /// In zh, this message translates to:
  /// **'正在下载 {n}'**
  String downloadsActiveN(Object n);

  /// No description provided for @downloadsDoneN.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {n}'**
  String downloadsDoneN(Object n);

  /// No description provided for @cancelAllDownloads.
  ///
  /// In zh, this message translates to:
  /// **'全部取消'**
  String get cancelAllDownloads;

  /// No description provided for @playAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get playAll;

  /// No description provided for @noActiveDownloads.
  ///
  /// In zh, this message translates to:
  /// **'没有进行中的下载'**
  String get noActiveDownloads;

  /// No description provided for @queuing.
  ///
  /// In zh, this message translates to:
  /// **'排队中…'**
  String get queuing;

  /// No description provided for @cancelDownload.
  ///
  /// In zh, this message translates to:
  /// **'取消下载'**
  String get cancelDownload;

  /// No description provided for @emptyDownloads.
  ///
  /// In zh, this message translates to:
  /// **'暂无已下载的音乐'**
  String get emptyDownloads;

  /// No description provided for @play.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// No description provided for @openContainingFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开所在文件夹'**
  String get openContainingFolder;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @register.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get register;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get email;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @emailCode.
  ///
  /// In zh, this message translates to:
  /// **'邮箱验证码'**
  String get emailCode;

  /// No description provided for @sendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get sendCode;

  /// No description provided for @verifyCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get verifyCode;

  /// No description provided for @forgotPasswordQ.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get forgotPasswordQ;

  /// No description provided for @loggingIn.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get loggingIn;

  /// No description provided for @registering.
  ///
  /// In zh, this message translates to:
  /// **'注册中…'**
  String get registering;

  /// No description provided for @sliderFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先完成滑块验证'**
  String get sliderFirst;

  /// No description provided for @needUsernameEmail.
  ///
  /// In zh, this message translates to:
  /// **'请先填写用户名和邮箱'**
  String get needUsernameEmail;

  /// No description provided for @codeSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送，请查收邮箱'**
  String get codeSent;

  /// No description provided for @codeSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证码发送失败'**
  String get codeSendFailed;

  /// No description provided for @registerFailed.
  ///
  /// In zh, this message translates to:
  /// **'注册失败'**
  String get registerFailed;

  /// No description provided for @sliderLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'滑块验证加载失败'**
  String get sliderLoadFailed;

  /// No description provided for @sliderVerifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'滑块验证失败，请重试'**
  String get sliderVerifyFailed;

  /// No description provided for @sliderPassed.
  ///
  /// In zh, this message translates to:
  /// **'✓ 滑块验证通过'**
  String get sliderPassed;

  /// No description provided for @sliderHint.
  ///
  /// In zh, this message translates to:
  /// **'请拖动滑块完成验证'**
  String get sliderHint;

  /// No description provided for @captchaLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证码图片加载失败，请点击右侧刷新重试'**
  String get captchaLoadFailed;

  /// No description provided for @emailInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效邮箱'**
  String get emailInvalid;

  /// No description provided for @sendFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送失败'**
  String get sendFailed;

  /// No description provided for @resetFormHint.
  ///
  /// In zh, this message translates to:
  /// **'请填写邮箱、验证码和新密码（至少 6 位）'**
  String get resetFormHint;

  /// No description provided for @passwordReset.
  ///
  /// In zh, this message translates to:
  /// **'密码已重置，请使用新密码登录'**
  String get passwordReset;

  /// No description provided for @resetFailed.
  ///
  /// In zh, this message translates to:
  /// **'重置失败'**
  String get resetFailed;

  /// No description provided for @forgotPwdTitle.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码'**
  String get forgotPwdTitle;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @submitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中…'**
  String get submitting;

  /// No description provided for @resetPassword.
  ///
  /// In zh, this message translates to:
  /// **'重置密码'**
  String get resetPassword;

  /// No description provided for @changePwdHint.
  ///
  /// In zh, this message translates to:
  /// **'请填写旧密码与新密码（至少 6 位）'**
  String get changePwdHint;

  /// No description provided for @pwdMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get pwdMismatch;

  /// No description provided for @pwdChanged.
  ///
  /// In zh, this message translates to:
  /// **'密码修改成功'**
  String get pwdChanged;

  /// No description provided for @changeFailed.
  ///
  /// In zh, this message translates to:
  /// **'修改失败'**
  String get changeFailed;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @oldPassword.
  ///
  /// In zh, this message translates to:
  /// **'旧密码'**
  String get oldPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPassword;

  /// No description provided for @confirmChange.
  ///
  /// In zh, this message translates to:
  /// **'确认修改'**
  String get confirmChange;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get account;

  /// No description provided for @signedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get signedIn;

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get signOut;

  /// No description provided for @enterPlaylistId.
  ///
  /// In zh, this message translates to:
  /// **'请输入歌单 ID'**
  String get enterPlaylistId;

  /// No description provided for @noImportableTracks.
  ///
  /// In zh, this message translates to:
  /// **'歌单里没有可导入的曲目'**
  String get noImportableTracks;

  /// No description provided for @enterNewPlaylistName.
  ///
  /// In zh, this message translates to:
  /// **'请输入新建歌单名称'**
  String get enterNewPlaylistName;

  /// No description provided for @importSearching.
  ///
  /// In zh, this message translates to:
  /// **'正在批量搜索匹配歌曲…'**
  String get importSearching;

  /// No description provided for @importSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'批量搜索失败：{error}'**
  String importSearchFailed(Object error);

  /// No description provided for @noMatchSongs.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配到可导入的歌曲'**
  String get noMatchSongs;

  /// No description provided for @creatingPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'正在创建歌单…'**
  String get creatingPlaylist;

  /// No description provided for @createPlaylistFailed.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单失败'**
  String get createPlaylistFailed;

  /// No description provided for @importingToFavoritesN.
  ///
  /// In zh, this message translates to:
  /// **'正在加入收藏（{n} 首）…'**
  String importingToFavoritesN(Object n);

  /// No description provided for @importingToPlaylistN.
  ///
  /// In zh, this message translates to:
  /// **'正在加入歌单（{n} 首）…'**
  String importingToPlaylistN(Object n);

  /// No description provided for @favoritedDoneN.
  ///
  /// In zh, this message translates to:
  /// **'已收藏 {done} 首（匹配 {success} 首）'**
  String favoritedDoneN(Object done, Object success);

  /// No description provided for @addFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加失败：{error}'**
  String addFailed(Object error);

  /// No description provided for @addedDoneN.
  ///
  /// In zh, this message translates to:
  /// **'成功添加 {added} 首（匹配 {success} 首）'**
  String addedDoneN(Object added, Object success);

  /// No description provided for @importPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'导入歌单'**
  String get importPlaylist;

  /// No description provided for @neteaseName.
  ///
  /// In zh, this message translates to:
  /// **'网易云'**
  String get neteaseName;

  /// No description provided for @qqName.
  ///
  /// In zh, this message translates to:
  /// **'QQ 音乐'**
  String get qqName;

  /// No description provided for @neteasePlaylistId.
  ///
  /// In zh, this message translates to:
  /// **'网易云歌单 ID'**
  String get neteasePlaylistId;

  /// No description provided for @qqDisstid.
  ///
  /// In zh, this message translates to:
  /// **'QQ 歌单 disstid'**
  String get qqDisstid;

  /// No description provided for @fetch.
  ///
  /// In zh, this message translates to:
  /// **'获取'**
  String get fetch;

  /// No description provided for @playlistPrefix.
  ///
  /// In zh, this message translates to:
  /// **'歌单：{name}'**
  String playlistPrefix(Object name);

  /// No description provided for @importCountN.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 首（最多导入前 60 首）'**
  String importCountN(Object n);

  /// No description provided for @importTo.
  ///
  /// In zh, this message translates to:
  /// **'导入到：'**
  String get importTo;

  /// No description provided for @newPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单'**
  String get newPlaylist;

  /// No description provided for @newPlaylistName.
  ///
  /// In zh, this message translates to:
  /// **'新建歌单名称'**
  String get newPlaylistName;

  /// No description provided for @startImport.
  ///
  /// In zh, this message translates to:
  /// **'开始导入'**
  String get startImport;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @monthsN.
  ///
  /// In zh, this message translates to:
  /// **'{months} 个月'**
  String monthsN(Object months);

  /// No description provided for @daysN.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天'**
  String daysN(Object days);

  /// No description provided for @createOrderFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建订单失败'**
  String get createOrderFailed;

  /// No description provided for @vipCenter.
  ///
  /// In zh, this message translates to:
  /// **'会员中心'**
  String get vipCenter;

  /// No description provided for @vipUntil.
  ///
  /// In zh, this message translates to:
  /// **'会员至 {date}'**
  String vipUntil(Object date);

  /// No description provided for @vipMember.
  ///
  /// In zh, this message translates to:
  /// **'VIP 会员'**
  String get vipMember;

  /// No description provided for @noPlans.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用套餐'**
  String get noPlans;

  /// No description provided for @choosePlan.
  ///
  /// In zh, this message translates to:
  /// **'选择套餐'**
  String get choosePlan;

  /// No description provided for @payMethod.
  ///
  /// In zh, this message translates to:
  /// **'支付方式'**
  String get payMethod;

  /// No description provided for @alipay.
  ///
  /// In zh, this message translates to:
  /// **'支付宝'**
  String get alipay;

  /// No description provided for @wechatPay.
  ///
  /// In zh, this message translates to:
  /// **'微信支付'**
  String get wechatPay;

  /// No description provided for @creatingOrder.
  ///
  /// In zh, this message translates to:
  /// **'创建订单中…'**
  String get creatingOrder;

  /// No description provided for @activateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即开通'**
  String get activateNow;

  /// No description provided for @qrHint.
  ///
  /// In zh, this message translates to:
  /// **'选择套餐并创建订单后展示付款二维码'**
  String get qrHint;

  /// No description provided for @scanToPay.
  ///
  /// In zh, this message translates to:
  /// **'请使用手机扫码完成支付'**
  String get scanToPay;

  /// No description provided for @payInfoMissing.
  ///
  /// In zh, this message translates to:
  /// **'支付信息缺失'**
  String get payInfoMissing;

  /// No description provided for @qrLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'二维码加载失败'**
  String get qrLoadFailed;

  /// No description provided for @copyLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'请点击复制链接'**
  String get copyLinkHint;

  /// No description provided for @copyPayLink.
  ///
  /// In zh, this message translates to:
  /// **'复制支付链接'**
  String get copyPayLink;

  /// No description provided for @payLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'支付链接已复制'**
  String get payLinkCopied;

  /// No description provided for @scanPayN.
  ///
  /// In zh, this message translates to:
  /// **'扫码支付（{method}）'**
  String scanPayN(Object method);

  /// No description provided for @removeFailed.
  ///
  /// In zh, this message translates to:
  /// **'移除失败'**
  String get removeFailed;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除歌单「{name}」吗？此操作不可恢复。'**
  String deletePlaylistConfirm(Object name);

  /// No description provided for @deleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteAction;

  /// No description provided for @playlistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'歌单暂无内容'**
  String get playlistEmpty;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'从歌单移除'**
  String get removeFromPlaylist;

  /// No description provided for @songsCountFull.
  ///
  /// In zh, this message translates to:
  /// **'{n} 首歌曲'**
  String songsCountFull(Object n);

  /// No description provided for @unfavoritePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏歌单'**
  String get unfavoritePlaylist;

  /// No description provided for @favoritePlaylist.
  ///
  /// In zh, this message translates to:
  /// **'收藏歌单'**
  String get favoritePlaylist;

  /// No description provided for @artistNoSongs.
  ///
  /// In zh, this message translates to:
  /// **'暂无该歌手歌曲'**
  String get artistNoSongs;

  /// No description provided for @addedToN.
  ///
  /// In zh, this message translates to:
  /// **'已添加到「{name}」'**
  String addedToN(Object name);

  /// No description provided for @addFailedDupe.
  ///
  /// In zh, this message translates to:
  /// **'添加失败（歌曲可能已在歌单中）'**
  String get addFailedDupe;

  /// No description provided for @enterPlaylistName.
  ///
  /// In zh, this message translates to:
  /// **'请输入歌单名称'**
  String get enterPlaylistName;

  /// No description provided for @createAndAdd.
  ///
  /// In zh, this message translates to:
  /// **'新建并添加'**
  String get createAndAdd;

  /// No description provided for @noPlaylistsCreateHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌单，可先新建'**
  String get noPlaylistsCreateHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
