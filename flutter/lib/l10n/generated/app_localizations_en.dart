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
  String get appLogoShort => 'NekoMusic';

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

  @override
  String get login => 'Sign in';

  @override
  String get register => 'Sign up';

  @override
  String get username => 'Username';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get emailCode => 'Email code';

  @override
  String get sendCode => 'Send code';

  @override
  String get verifyCode => 'Verification code';

  @override
  String get forgotPasswordQ => 'Forgot password?';

  @override
  String get loggingIn => 'Signing in…';

  @override
  String get registering => 'Signing up…';

  @override
  String get sliderFirst => 'Complete the slider captcha first';

  @override
  String get needUsernameEmail => 'Enter username and email first';

  @override
  String get codeSent => 'Verification code sent — check your email';

  @override
  String get codeSendFailed => 'Failed to send code';

  @override
  String get registerFailed => 'Sign-up failed';

  @override
  String get sliderLoadFailed => 'Failed to load slider captcha';

  @override
  String get sliderVerifyFailed => 'Slider captcha failed, try again';

  @override
  String get sliderPassed => 'Slider captcha passed';

  @override
  String get sliderHint => 'Drag the slider to verify';

  @override
  String get captchaLoadFailed =>
      'Failed to load captcha image — click refresh to retry';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get sendFailed => 'Send failed';

  @override
  String get resetFormHint =>
      'Enter email, code and new password (min 6 characters)';

  @override
  String get passwordReset => 'Password reset — sign in with the new one';

  @override
  String get resetFailed => 'Reset failed';

  @override
  String get forgotPwdTitle => 'Forgot password';

  @override
  String get newPassword => 'New password';

  @override
  String get submitting => 'Submitting…';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get changePwdHint => 'Enter old and new password (min 6 characters)';

  @override
  String get pwdMismatch => 'New passwords do not match';

  @override
  String get pwdChanged => 'Password changed';

  @override
  String get changeFailed => 'Change failed';

  @override
  String get changePassword => 'Change password';

  @override
  String get oldPassword => 'Old password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get confirmChange => 'Confirm change';

  @override
  String get account => 'Account';

  @override
  String get signedIn => 'Signed in';

  @override
  String get signOut => 'Sign out';

  @override
  String get enterPlaylistId => 'Enter playlist ID';

  @override
  String get noImportableTracks => 'No importable tracks in this playlist';

  @override
  String get enterNewPlaylistName => 'Enter a name for the new playlist';

  @override
  String get importSearching => 'Matching songs…';

  @override
  String importSearchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get noMatchSongs => 'No matching songs to import';

  @override
  String get creatingPlaylist => 'Creating playlist…';

  @override
  String get createPlaylistFailed => 'Failed to create playlist';

  @override
  String importingToFavoritesN(Object n) {
    return 'Adding to favorites ($n songs)…';
  }

  @override
  String importingToPlaylistN(Object n) {
    return 'Adding to playlist ($n songs)…';
  }

  @override
  String favoritedDoneN(Object done, Object success) {
    return 'Favorited $done songs (matched $success)';
  }

  @override
  String addFailed(Object error) {
    return 'Add failed: $error';
  }

  @override
  String addedDoneN(Object added, Object success) {
    return 'Added $added songs (matched $success)';
  }

  @override
  String get importPlaylist => 'Import playlist';

  @override
  String get neteaseName => 'NetEase';

  @override
  String get qqName => 'QQ Music';

  @override
  String get neteasePlaylistId => 'NetEase playlist ID';

  @override
  String get qqDisstid => 'QQ playlist disstid';

  @override
  String get fetch => 'Fetch';

  @override
  String playlistPrefix(Object name) {
    return 'Playlist: $name';
  }

  @override
  String importCountN(Object n) {
    return '$n songs (imports the first 60)';
  }

  @override
  String get importTo => 'Import to:';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get newPlaylistName => 'New playlist name';

  @override
  String get startImport => 'Start import';

  @override
  String get loadFailed => 'Load failed';

  @override
  String monthsN(Object months) {
    return '$months months';
  }

  @override
  String daysN(Object days) {
    return '$days days';
  }

  @override
  String get createOrderFailed => 'Failed to create order';

  @override
  String get vipCenter => 'VIP center';

  @override
  String vipUntil(Object date) {
    return 'VIP until $date';
  }

  @override
  String get vipMember => 'VIP member';

  @override
  String get noPlans => 'No plans available';

  @override
  String get choosePlan => 'Choose a plan';

  @override
  String get payMethod => 'Payment method';

  @override
  String get alipay => 'Alipay';

  @override
  String get wechatPay => 'WeChat Pay';

  @override
  String get creatingOrder => 'Creating order…';

  @override
  String get activateNow => 'Activate now';

  @override
  String get qrHint => 'Pick a plan and create an order to view the QR code';

  @override
  String get scanToPay => 'Scan with your phone to complete payment';

  @override
  String get payInfoMissing => 'Payment info missing';

  @override
  String get qrLoadFailed => 'Failed to load QR code';

  @override
  String get copyLinkHint => 'Click to copy the link';

  @override
  String get copyPayLink => 'Copy payment link';

  @override
  String get payLinkCopied => 'Payment link copied';

  @override
  String scanPayN(Object method) {
    return 'Scan to pay ($method)';
  }

  @override
  String get removeFailed => 'Remove failed';

  @override
  String deletePlaylistConfirm(Object name) {
    return 'Delete playlist \"$name\"? This cannot be undone.';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get playlistEmpty => 'This playlist is empty';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String songsCountFull(Object n) {
    return '$n songs';
  }

  @override
  String get unfavoritePlaylist => 'Unfavorite playlist';

  @override
  String get favoritePlaylist => 'Favorite playlist';

  @override
  String get artistNoSongs => 'No songs by this artist yet';

  @override
  String addedToN(Object name) {
    return 'Added to \"$name\"';
  }

  @override
  String get addFailedDupe =>
      'Add failed (song may already be in the playlist)';

  @override
  String get enterPlaylistName => 'Enter a playlist name';

  @override
  String get createAndAdd => 'Create & add';

  @override
  String get noPlaylistsCreateHint => 'No playlists — create one first';

  @override
  String get downloadCancelled => 'Download cancelled';

  @override
  String downloadFailedN(Object msg) {
    return 'Download failed: $msg';
  }

  @override
  String downloadSavedToN(Object path) {
    return 'Saved to $path';
  }

  @override
  String get downloadQueued => 'Added to download queue';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get more => 'More';

  @override
  String get emptyData => 'No data';

  @override
  String get localToCloudUnsupported =>
      'Local music can\'t be added to cloud playlists';

  @override
  String get needLoginAdd => 'Sign in to add to playlists';

  @override
  String get artistNotFound => 'Artist not found';

  @override
  String get settingsLanguageNya => 'Meow Chinese';
}
