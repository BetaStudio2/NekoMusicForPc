// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Neko Project';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsDarkTheme => 'Dark theme';

  @override
  String get settingsDarkThemeHint =>
      'Switch app palette, saved to ~/.nekomusic/settings.json';

  @override
  String get settingsBackdropCustomize => 'Backdrop';

  @override
  String get settingsBackdropHint =>
      'Theme default / Solid color / Custom image';

  @override
  String get settingsBackdropFollowTheme => 'Follow theme';

  @override
  String get settingsBackdropSolid => 'Solid color';

  @override
  String get settingsBackdropImage => 'Custom image';

  @override
  String get settingsBackdropColor => 'Backdrop color';

  @override
  String get settingsBackdropImageTitle => 'Backdrop image';

  @override
  String get settingsBackdropNotSet => 'Not set';

  @override
  String get settingsBackdropRemove => 'Remove';

  @override
  String get settingsShortcuts => 'Shortcuts';

  @override
  String get settingsShortcutPlayPause => 'Play / Pause';

  @override
  String get settingsShortcutNext => 'Next track';

  @override
  String get settingsShortcutPrev => 'Previous track';

  @override
  String get settingsShortcutHint =>
      'Shortcuts take effect while the app has focus. To rebind, use the original desktop build.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAppSubtitle => 'High-quality lossless cloud music player';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsGithubRepo => 'GitHub repository';

  @override
  String get settingsGithubCopied => 'Repository link copied';

  @override
  String get settingsCheckUpdate => 'Check for updates';

  @override
  String get settingsUpToDate => 'You are on the latest version 1.0.0';

  @override
  String get settingsBackdropColorPickerTitle => 'Pick backdrop color';

  @override
  String get settingsBackdropImagePathTitle => 'Backdrop image path';

  @override
  String get settingsBackdropImageFormatHint =>
      'Supports png / jpg / webp image files';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsApply => 'Apply';

  @override
  String get settingsFileNotFound => 'File not found';

  @override
  String get searchHint => 'Search music / playlists / artists';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get engineErrorPrefix => 'Playback engine error: ';

  @override
  String get playerIdleTitle => 'Not playing';

  @override
  String get playModeTooltip => 'Play mode';

  @override
  String get playModeList => 'In order';

  @override
  String get playModeLoop => 'Repeat list';

  @override
  String get playModeSingle => 'Repeat one';

  @override
  String get playModeRandom => 'Shuffle';

  @override
  String get prevTrack => 'Previous';

  @override
  String get nextTrack => 'Next';

  @override
  String get navHome => 'Home';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navRecents => 'Recents';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get homeRecPlaylists => 'Recommended playlists';

  @override
  String get homeEmptyPlaylists => 'No recommended playlists yet';

  @override
  String get homeHot => 'Trending';

  @override
  String get homeLatest => 'Latest music';

  @override
  String homeCountSongs(Object count) {
    return '$count songs';
  }

  @override
  String get homeDailyTitle => 'Daily picks';

  @override
  String get homeDailySubtitle => 'Updated daily to your taste';
}
