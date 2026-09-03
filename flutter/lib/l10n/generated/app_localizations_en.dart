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

  @override
  String get appLogoShort => 'Neko';

  @override
  String get appFooter => 'Neko歌姬计划';

  @override
  String get localPlaylists => 'Local playlists';

  @override
  String get emptyLocalPlaylists => 'No local playlists';

  @override
  String get newLocalPlaylist => 'New local playlist';

  @override
  String get myPlaylists => 'My playlists';

  @override
  String get emptyMyPlaylists => 'No playlists — create one below';

  @override
  String get createPlaylist => 'Create playlist';

  @override
  String get importNeteasePlaylist => 'Import NetEase playlist';

  @override
  String get importQqPlaylist => 'Import QQ playlist';

  @override
  String get favPlaylists => 'Favorite playlists';

  @override
  String get emptyFavPlaylists => 'No favorite playlists';

  @override
  String get deviceSync => 'Device sync';

  @override
  String get rename => 'Rename';

  @override
  String get deletePlaylist => 'Delete playlist';

  @override
  String get renamePlaylistTitle => 'Rename playlist';

  @override
  String get inputName => 'Playlist name';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get create => 'Create';

  @override
  String get needLoginImport => 'Sign in to import playlists';

  @override
  String get needLoginCreateCloud => 'Sign in to create cloud playlists';

  @override
  String playlistCountSongs(Object n) {
    return '$n songs';
  }

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get favorite => 'Favorite';

  @override
  String get download => 'Download';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get addToPlaylistFailed => 'Failed to add to playlist';

  @override
  String get noLyrics => 'No lyrics yet';

  @override
  String get queueTitle => 'Play queue';

  @override
  String get collapseQueue => 'Collapse queue';

  @override
  String get clearQueue => 'Clear queue';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get queueEmptyHint => 'Add songs from a list to start playing';

  @override
  String get playModeColon => 'Play mode: ';

  @override
  String get needLogin => 'Sign in required';

  @override
  String get lanEmpty => 'No other devices on this network';

  @override
  String get lanLoginHint => 'Sign in to auto-discover devices on your account';

  @override
  String get lanRemotePlaying => 'Playing remotely';

  @override
  String get lanRemoteQueue => 'Remote queue';

  @override
  String get lanTakeover => 'Take over & play';

  @override
  String lanNowPlaying(Object id) {
    return 'Playing #$id';
  }

  @override
  String get lanEmptyTag => 'Empty';

  @override
  String remoteQueueSubtitle(Object count, Object title) {
    return '$count songs · $title';
  }

  @override
  String get search => 'Search';

  @override
  String searchTotalSongs(Object total) {
    return 'Found $total songs';
  }

  @override
  String get tabSongs => 'Songs';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get tabArtists => 'Artists';

  @override
  String get searchStartHint => 'Type keywords to search';

  @override
  String get searchNoSongs => 'No matching songs';

  @override
  String get searchNoPlaylists => 'No matching playlists';

  @override
  String get searchNoArtists => 'No matching artists';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String songCountN(Object count) {
    return '$count songs';
  }

  @override
  String get viewArtist => 'View artist';

  @override
  String get shuffleAgain => 'Shuffle';

  @override
  String get dailyShuffleHint => 'Tap Shuffle to get today\'s picks';

  @override
  String get myFavorites => 'My favorites';

  @override
  String get loginHintFavorites => 'Sign in to view cloud favorites';

  @override
  String get emptyFavorites => 'No favorites';

  @override
  String get emptyRecents => 'No play history';

  @override
  String downloadsActiveN(Object n) {
    return 'Downloading $n';
  }

  @override
  String downloadsDoneN(Object n) {
    return 'Done $n';
  }

  @override
  String get cancelAllDownloads => 'Cancel all';

  @override
  String get playAll => 'Play all';

  @override
  String get noActiveDownloads => 'No active downloads';

  @override
  String get queuing => 'Queued…';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get emptyDownloads => 'No downloaded music';

  @override
  String get play => 'Play';

  @override
  String get openContainingFolder => 'Open containing folder';
}
