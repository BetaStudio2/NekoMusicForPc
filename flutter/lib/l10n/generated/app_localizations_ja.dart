// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Neko歌姬计划';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneral => '通用喵';

  @override
  String get settingsLanguage => '交流语言喵~';

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
  String get playerIdleTitle => '耳朵好寂寞喵，还没在唱歌呢...';

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
  String get prevTrack => '前一首的说~';

  @override
  String get nextTrack => '下一首的说~';

  @override
  String get navHome => '温暖的家喵~';

  @override
  String get navFavorites => '最最最喜欢的喵！';

  @override
  String get navRecents => '刚才路过的声音喵~';

  @override
  String get navDownloads => '下载小仓库喵~';

  @override
  String get actionRefresh => '让世界焕然一新喵~';

  @override
  String get homeRecPlaylists => '为您挑选的礼物喵~';

  @override
  String get homeEmptyPlaylists => '暂无推荐歌单';

  @override
  String get homeHot => '火热音乐喵~';

  @override
  String get homeLatest => '新鲜出炉喵~';

  @override
  String homeCountSongs(Object count) {
    return '$count 首';
  }

  @override
  String get homeDailyTitle => '今日推荐喵~';

  @override
  String get homeDailySubtitle => '按你的收藏口味挑出来的喵~';

  @override
  String get appLogoShort => 'Neko歌姬';

  @override
  String get appFooter => 'Neko歌姬计划';

  @override
  String get localPlaylists => '咱的私藏歌单喵~';

  @override
  String get emptyLocalPlaylists => '暂无本地歌单';

  @override
  String get newLocalPlaylist => '新建本地歌单';

  @override
  String get myPlaylists => '咱的私人领地喵~';

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
  String get rename => '换个称呼喵~';

  @override
  String get deletePlaylist => '悄悄丢掉喵~';

  @override
  String get renamePlaylistTitle => '变身改名术喵！';

  @override
  String get inputName => '歌单名称';

  @override
  String get cancel => '才、才不要了喵~';

  @override
  String get confirm => '决定就是你啦喵！';

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
  String get close => '消失掉喵~';

  @override
  String get back => '退回刚才的地方喵~';

  @override
  String get favorite => '心动收藏喵！';

  @override
  String get download => '下载喵';

  @override
  String get addToPlaylist => '加入歌单';

  @override
  String get addToPlaylistFailed => '加入歌单失败';

  @override
  String get noLyrics => '暂无歌词';

  @override
  String get queueTitle => '播放队列喵~';

  @override
  String get collapseQueue => '收起队列';

  @override
  String get clearQueue => '清空队列';

  @override
  String get queueEmpty => '队列空空的，快去加歌喵~';

  @override
  String get queueEmptyHint => '队列空空的，快去加歌喵~';

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
  String get search => '搜寻宝藏喵~';

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
  String get searchStartHint => '想听什么歌呢？跟人家说嘛喵~...';

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
  String get myFavorites => '我最喜欢的音乐喵~';

  @override
  String get loginHintFavorites => '登录后显示云端收藏';

  @override
  String get emptyFavorites => '暂无收藏';

  @override
  String get emptyRecents => '这里还没有留下过声音喵~';

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
  String get playAll => '全员集合，开始合唱喵！';

  @override
  String get noActiveDownloads => '现在没有在搬的歌喵~';

  @override
  String get queuing => '排队中喵';

  @override
  String get cancelDownload => '取消下载喵';

  @override
  String get emptyDownloads => '还没有搬完的歌喵~ 去歌曲列表里点下载吧喵~';

  @override
  String get play => '让节奏响起来喵~';

  @override
  String get openContainingFolder => '打开所在文件夹';

  @override
  String get login => '指挥官，欢迎回来喵！';

  @override
  String get register => '加入 Neko 家族喵~';

  @override
  String get username => '用户名';

  @override
  String get email => '联络暗号(邮箱)喵~';

  @override
  String get password => '秘密护盾(密码)喵~';

  @override
  String get emailCode => '邮箱验证码';

  @override
  String get sendCode => '发送验证码';

  @override
  String get verifyCode => '验证码';

  @override
  String get forgotPasswordQ => '忘记密码？';

  @override
  String get loggingIn => '登录中…';

  @override
  String get registering => '注册中…';

  @override
  String get sliderFirst => '请先完成滑块验证';

  @override
  String get needUsernameEmail => '请先填写用户名和邮箱';

  @override
  String get codeSent => '验证码已发送，请查收邮箱';

  @override
  String get codeSendFailed => '验证码发送失败';

  @override
  String get registerFailed => '注册失败';

  @override
  String get sliderLoadFailed => '滑块验证加载失败';

  @override
  String get sliderVerifyFailed => '滑块验证失败，请重试';

  @override
  String get sliderPassed => '✓ 滑块验证通过';

  @override
  String get sliderHint => '请拖动滑块完成验证';

  @override
  String get captchaLoadFailed => '验证码图片加载失败，请点击右侧刷新重试';

  @override
  String get emailInvalid => '请输入有效邮箱';

  @override
  String get sendFailed => '发送失败';

  @override
  String get resetFormHint => '请填写邮箱、验证码和新密码（至少 6 位）';

  @override
  String get passwordReset => '密码已重置，请使用新密码登录';

  @override
  String get resetFailed => '重置失败';

  @override
  String get forgotPwdTitle => '忘记密码';

  @override
  String get newPassword => '新密码';

  @override
  String get submitting => '提交中…';

  @override
  String get resetPassword => '重置密码';

  @override
  String get changePwdHint => '请填写旧密码与新密码（至少 6 位）';

  @override
  String get pwdMismatch => '两次输入的新密码不一致';

  @override
  String get pwdChanged => '密码修改成功';

  @override
  String get changeFailed => '修改失败';

  @override
  String get changePassword => '修改密码';

  @override
  String get oldPassword => '旧密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get confirmChange => '确认修改';

  @override
  String get account => '账户';

  @override
  String get signedIn => '已登录';

  @override
  String get signOut => '要离开了喵？人家会想你的喵...';

  @override
  String get enterPlaylistId => '请输入歌单 ID';

  @override
  String get noImportableTracks => '歌单里没有可导入的曲目';

  @override
  String get enterNewPlaylistName => '请输入新建歌单名称';

  @override
  String get importSearching => '正在批量搜索匹配歌曲…';

  @override
  String importSearchFailed(Object error) {
    return '批量搜索失败：$error';
  }

  @override
  String get noMatchSongs => '没有匹配到可导入的歌曲';

  @override
  String get creatingPlaylist => '正在创建歌单…';

  @override
  String get createPlaylistFailed => '新建歌单失败';

  @override
  String importingToFavoritesN(Object n) {
    return '正在加入收藏（$n 首）…';
  }

  @override
  String importingToPlaylistN(Object n) {
    return '正在加入歌单（$n 首）…';
  }

  @override
  String favoritedDoneN(Object done, Object success) {
    return '已收藏 $done 首（匹配 $success 首）';
  }

  @override
  String addFailed(Object error) {
    return '添加失败：$error';
  }

  @override
  String addedDoneN(Object added, Object success) {
    return '成功添加 $added 首（匹配 $success 首）';
  }

  @override
  String get importPlaylist => '导入歌单';

  @override
  String get neteaseName => '网易云';

  @override
  String get qqName => 'QQ 音乐';

  @override
  String get neteasePlaylistId => '网易云歌单 ID';

  @override
  String get qqDisstid => 'QQ 歌单 disstid';

  @override
  String get fetch => '获取';

  @override
  String playlistPrefix(Object name) {
    return '歌单：$name';
  }

  @override
  String importCountN(Object n) {
    return '共 $n 首（最多导入前 60 首）';
  }

  @override
  String get importTo => '导入到：';

  @override
  String get newPlaylist => '新建歌单';

  @override
  String get newPlaylistName => '新建歌单名称';

  @override
  String get startImport => '开始导入';

  @override
  String get loadFailed => '加载失败';

  @override
  String monthsN(Object months) {
    return '$months 个月';
  }

  @override
  String daysN(Object days) {
    return '$days 天';
  }

  @override
  String get createOrderFailed => '创建订单失败';

  @override
  String get vipCenter => '会员中心';

  @override
  String vipUntil(Object date) {
    return '会员至 $date';
  }

  @override
  String get vipMember => 'VIP 会员';

  @override
  String get noPlans => '暂无可用套餐';

  @override
  String get choosePlan => '选择套餐';

  @override
  String get payMethod => '支付方式';

  @override
  String get alipay => '支付宝';

  @override
  String get wechatPay => '微信支付';

  @override
  String get creatingOrder => '创建订单中…';

  @override
  String get activateNow => '立即开通';

  @override
  String get qrHint => '选择套餐并创建订单后展示付款二维码';

  @override
  String get scanToPay => '请使用手机扫码完成支付';

  @override
  String get payInfoMissing => '支付信息缺失';

  @override
  String get qrLoadFailed => '二维码加载失败';

  @override
  String get copyLinkHint => '请点击复制链接';

  @override
  String get copyPayLink => '复制支付链接';

  @override
  String get payLinkCopied => '支付链接已复制';

  @override
  String scanPayN(Object method) {
    return '扫码支付（$method）';
  }

  @override
  String get removeFailed => '移除失败';

  @override
  String deletePlaylistConfirm(Object name) {
    return '确定删除歌单「$name」吗？此操作不可恢复。';
  }

  @override
  String get deleteAction => '悄悄丢掉喵~';

  @override
  String get playlistEmpty => '播放列表空空的，快去加歌喵~';

  @override
  String get removeFromPlaylist => '从歌单移除';

  @override
  String songsCountFull(Object n) {
    return '$n 首歌曲';
  }

  @override
  String get unfavoritePlaylist => '不喜欢收藏了喵...';

  @override
  String get favoritePlaylist => '心动收藏喵！';

  @override
  String get artistNoSongs => '暂无该歌手歌曲';

  @override
  String addedToN(Object name) {
    return '已添加到「$name」';
  }

  @override
  String get addFailedDupe => '添加失败（歌曲可能已在歌单中）';

  @override
  String get enterPlaylistName => '请输入歌单名称';

  @override
  String get createAndAdd => '新建并添加';

  @override
  String get noPlaylistsCreateHint => '暂无歌单，可先新建';

  @override
  String get downloadCancelled => '下载取消啦喵~';

  @override
  String downloadFailedN(Object msg) {
    return '下载失败：$msg';
  }

  @override
  String downloadSavedToN(Object path) {
    return '已保存到 $path';
  }

  @override
  String get downloadQueued => '开始帮你搬歌啦喵~';

  @override
  String get removeFavorite => '不喜欢了喵...';

  @override
  String get more => '更多';

  @override
  String get emptyData => '空荡荡的，什么都没有喵... 呜喵...';

  @override
  String get localToCloudUnsupported => '本地音乐暂不支持添加到云端歌单';

  @override
  String get needLoginAdd => '添加到歌单需要先登录';

  @override
  String get artistNotFound => '未找到该歌手';

  @override
  String get settingsLanguageNya => '喵语中文喵';

  @override
  String get settingsBrandGlyph => 'Logo 用字形渲染';

  @override
  String get settingsBrandGlyphHint => '固定品牌色，随主题不变（默认关）';
}
