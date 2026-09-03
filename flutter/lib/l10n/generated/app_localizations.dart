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
