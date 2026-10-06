/**
 * @file legaltext.cpp
 * @brief 用户协议 / 隐私政策文案与同意状态实现
 */

#include "legaltext.h"
#include "i18n.h"

#include <QSettings>

namespace
{

    QString s(const char *utf8)
    {
        return QString::fromUtf8(utf8);
    }

    // ─────────────────────────────────────────────────────────────
    //  中文文案（喵语回退到此）
    // ─────────────────────────────────────────────────────────────

    LegalDocument userAgreementZh()
    {
        LegalDocument doc;
        doc.title = s(u8"Neko歌姬计划 PC版 用户协议");
        doc.version = QStringLiteral("v1.0");
        doc.updated = s(u8"2026 年 9 月 29 日");
        doc.intro = s(R"TXT(欢迎使用 Neko歌姬计划 PC版（NekoMusic，以下简称「本软件」或「我们」）。本软件是接入「Neko歌姬计划」开放接口的第三方开源桌面客户端。在使用本软件前，请务必仔细阅读并充分理解本协议的全部内容。

**您开始使用本软件（包括注册、登录、导入歌单、下载、评论、开通会员、开启麦克风或局域网同步等任一功能），即表示您已阅读、理解并同意接受本协议的全部约束。若您不同意本协议的任何内容，请立即停止使用并卸载本软件。**)TXT");

        doc.sections = {
            {s(u8"一、协议主体与适用范围"),
             s(R"TXT(本协议是您与本软件开发者之间就您下载、安装、使用本软件所订立的协议。

本软件为第三方开源客户端，**与各音乐平台及其官方客户端不存在任何关联、合作、授权或代理关系**，项目本身不以营利为目的。

官方网站：https://music.nekocore.cn
源码仓库：https://github.com/FantasyNetworkCN/NekoMusicForPc
后端与 API 文档：https://github.com/FantasyNetworkCN/NekoMusicDocs)TXT")},

            {s(u8"二、开源许可与署名"),
             s(R"TXT(本软件以 **AGPL-3.0** 发布，并附有原作者依据该许可证第 7 条声明的附加条款。遵守许可证条款即可自由使用、学习、修改与再分发，**合规的开源商业使用同样被许可**；本项目不提供脱离 AGPL 义务的闭源商业授权。

您在使用、修改或再分发本软件时，应当一并遵守：
· 保留原有的版权、许可与署名声明；
· 以同一许可证发布您的衍生作品；
· 通过网络向用户提供本软件（含修改版）功能时，向这些用户提供对应的完整源代码；
· 在界面显著位置保留「本程序由 Neko歌姬计划 API 提供技术支持」的署名、本程序仓库链接及 API 文档链接；
· 支持中文与英文并提供清晰的语言切换方式。

**严禁冒名顶替，或移除、遮掩「Neko歌姬计划」品牌标识。** 违反上述义务将导致相应许可授权的自动终止。完整条款以随附的 LICENSE 文件及 GNU 官方页面为准。)TXT")},

            {s(u8"三、账号注册与使用"),
             s(R"TXT(部分功能需注册并登录「Neko歌姬计划」账号后使用。注册需提供昵称、邮箱与密码并通过邮箱验证码校验，也可使用 NekoMusic 手机端扫描二维码登录。

您应保证注册信息真实、准确、合法。**账号仅供本人使用，不得出租、出借、转让、共享或买卖；账号名下发生的一切行为均视为您本人的行为，由您负责。**

请妥善保管账号与登录凭据；在公共或共享设备上使用后请及时退出登录并清理凭据。平台可能对第三方客户端的登录与请求进行风控、限制或封禁，由此产生的账号异常、功能受限等风险由您自行承担。)TXT")},

            {s(u8"四、软件功能与服务"),
             s(R"TXT(本软件提供在线音乐检索、播放、歌词与封面展示、榜单与每日推荐、收藏与歌单管理、歌曲评论、外部歌单导入、音乐下载、本地音乐播放与默认播放器接管、桌面歌词、全局快捷键、麦克风同步、局域网设备同步、分享视频渲染及会员中心等功能。

上述功能的形态、范围与可用性可能因版本迭代、平台接口策略、后端服务能力或法律法规要求而新增、调整、限制或下线，本软件不承诺任何功能永久可用。)TXT")},

            {s(u8"五、会员与付费"),
             s(R"TXT(会员权益、套餐、价格与时长以软件内「会员中心」实时展示为准。

会员订单由后端创建，并跳转至支付宝、微信等第三方支付渠道完成支付。**本软件不收集、不存储您的支付账号、银行卡号、支付密码等支付敏感信息。**

支付成功后会员时长按所选套餐叠加；会员属于虚拟服务，开通后原则上不支持退款，法律另有强制性规定的从其规定。请在常用、安全的网络环境下完成支付，谨防钓鱼与诈骗；**通过非官方渠道进行的交易与本站无关。**)TXT")},

            {s(u8"六、第三方服务与外部歌单导入"),
             s(R"TXT(在线音乐、导入等能力依赖第三方平台与后端服务。使用外部歌单导入时，您提交的歌单链接或 ID 会发送至后端，由后端完成站外内容的匹配、下载与入库。

各在线音乐平台的接口、鉴权与可用性由平台单方决定，可能随时变更、限制或关闭，导致登录失效、功能不可用或数据无法同步。**本软件不对第三方服务的持续可用性、稳定性、合法性与数据完整性作出承诺。**

您应确保对所导入或访问的内容拥有合法权利，并遵守来源平台的服务条款；因您的导入、下载或使用行为引发的争议与责任由您自行承担。)TXT")},

            {s(u8"七、内容来源与版权"),
             s(R"TXT(本软件自身不提供、不存储、不分发任何音乐内容（用户自行上传的内容除外）。音频、歌词、封面等均来自您的本地文件、平台公开接口或您上传的内容，其版权归原权利人及平台所有，**本软件不主张任何所有权**。

您应确保对相关内容拥有合法访问与使用权。使用过程中产生的版权数据（播放链接、歌词、封面等）**仅供个人试听与学习研究，请勿用于商业用途或公开传播，建议在产生后 24 小时内清除**。如需长期欣赏，请通过正版渠道购买或订阅，支持正版音乐。)TXT")},

            {s(u8"八、用户行为规范与禁止事项"),
             s(R"TXT(您在使用本软件时不得从事下列行为：
· 利用本软件从事商业行为、批量抓取、爬取、刷量或转售内容；
· 上传、发布或传播违法、侵权、色情、暴力、恐怖、仇恨、赌博、诈骗或其他违反法律法规与公序良俗的内容（含昵称、头像、歌单名称与描述、评论、上传音频等）；
· 绕过在线平台的技术保护措施、访问控制或服务条款；
· 干扰、攻击、入侵或以其他方式危害本软件、后端服务及第三方平台的正常运行，或利用漏洞谋取不正当利益；
· 冒名顶替、移除或遮掩品牌标识，或误导性地宣称本软件为其原创；
· 将本软件用于任何侵害他人合法权益的用途。

违反上述规范的，我们有权在法律法规允许的范围内删除内容、限制功能、暂停或终止服务，并保留追究法律责任的权利。)TXT")},

            {s(u8"九、用户内容"),
             s(R"TXT(您对本软件中由您产生或上传的内容（昵称、头像、歌单信息、评论、上传音频等）负责，并保证其合法、真实、不侵犯任何第三方的合法权益。

为实现软件功能之目的，您同意我们对该等内容进行必要的存储、展示、同步与审核。对违反法律法规或本协议的内容，我们有权删除或作其他处理。)TXT")},

            {s(u8"十、知识产权"),
             s(R"TXT(本软件的界面设计、程序代码、图标及相关文档的知识产权归开发者或相应权利人所有，您可在开源许可范围内依法使用。

本软件中出现的第三方商标、音乐作品与平台名称，其权利归各自所有者，本软件的使用不代表任何形式的授权或关联。)TXT")},

            {s(u8"十一、免责声明与责任限制"),
             s(R"TXT(本软件按「现状」提供，**不对其适用性、稳定性、准确性或适法性作出任何明示或默示的保证**。

因使用或无法使用本软件，或因在线平台接口变更、账号限制、登录凭据失效、账号被风控或封禁、功能失效、数据丢失、设备故障、网络中断、误操作、不可抗力等产生的任何直接或间接损失，**均由您自行承担**。

在法律允许的最大范围内，开发者不就任何间接、附带、特殊或惩罚性损害向您承担责任。本软件仅用于技术探索与研究；如相关平台认为本软件不妥，可随时联系开发者进行调整或移除。)TXT")},

            {s(u8"十二、协议的变更与终止"),
             s(R"TXT(我们可能随功能迭代、技术架构演进或法律法规变更适时修订本协议。更新后的协议随软件版本或官方仓库发布，并自文首标注的「最近更新」日期起生效。

若您在协议更新后继续使用本软件，即视为您已阅读、理解并同意更新后的协议；若不同意，请停止使用并卸载本软件。您可随时停止使用本软件并自行删除本机数据；我们也可依据法律法规或本协议约定限制、暂停或终止向您提供服务。)TXT")},

            {s(u8"十三、未成年人使用"),
             s(R"TXT(本软件为通用工具类软件，不针对未成年人设计或收集个人信息。若您是未成年人，请在监护人的陪同与指导下阅读本协议，并在取得监护人同意后使用本软件；请合理安排使用时间，避免沉迷，监护人应履行相应的监护职责。)TXT")},

            {s(u8"十四、法律适用与争议解决"),
             s(R"TXT(本协议的解释与争议解决适用中华人民共和国大陆地区法律（不含冲突法规则）。

因本协议产生的争议，双方应友好协商解决；协商不成的，任何一方可向开发者所在地有管辖权的人民法院提起诉讼。本协议部分条款被认定无效或不可执行的，不影响其余条款的效力。)TXT")},

            {s(u8"十五、联系我们"),
             s(R"TXT(如对本协议有任何疑问、意见或申诉，欢迎通过 GitHub 仓库与 Issue 联系我们：
https://github.com/FantasyNetworkCN/NekoMusicForPc

我们将在收到反馈后尽快答复。)TXT")},
        };

        doc.footer = s(u8"本软件仅用于技术探索与研究。如相关平台认为本软件不妥，可随时联系开发者进行调整或移除。");
        return doc;
    }

    LegalDocument privacyPolicyZh()
    {
        LegalDocument doc;
        doc.title = s(u8"Neko歌姬计划 PC版 隐私政策");
        doc.version = QStringLiteral("v1.0");
        doc.updated = s(u8"2026 年 9 月 29 日");
        doc.intro = s(R"TXT(欢迎使用 Neko歌姬计划 PC版（NekoMusic，以下简称「本软件」或「我们」）。我们深知个人信息对您的重要性，并始终致力于保护您的隐私与数据安全。本政策向您说明在您使用本软件的过程中，我们如何处理、存储与保护您的信息，以及您所享有的相关权利。

请务必仔细阅读并充分理解本政策。**一旦您开始使用本软件，即表示您已阅读、理解并同意本政策所述全部内容。**)TXT");

        doc.sections = {
            {s(u8"一、基本原则"),
             s(R"TXT(· 最小必要：仅处理实现基础功能、保障安全及改善体验所必需的数据，不收集与服务无关的个人敏感信息。
· 本地优先：您的偏好配置、本地歌单、播放队列、缓存等默认保存在本机，由您本人掌控。
· 透明可控：本软件不含广告、埋点或用户画像，数据处理方式公开透明，并可随时由您清除。)TXT")},

            {s(u8"二、我们收集与处理的信息"),
             s(R"TXT(**2.1 您主动提供的信息**
· 账号信息：注册时提供的昵称、邮箱、密码以及头像等资料。密码由服务端以加密/哈希方式保存，本软件不会以明文记录您的密码。
· 登录凭据：账号密码登录时由服务端签发的会话 Token，或扫码登录后获得的 Token。
· 外部歌单信息：外部歌单导入时提交的歌单链接或 ID（网易云、QQ 音乐、酷狗、汽水等）。
· 用户内容：您发表的评论、上传的内容，以及昵称、头像、歌单名称与描述等。

**2.2 由服务产生的数据**
· 收藏、歌单、播放与下载记录、评论等业务数据，用于在您的账号下同步与展示。
· 会员订单信息（订单号、套餐、金额、状态与时间），用于会员权益的开通与查询；**支付由第三方支付渠道处理，本软件不接触您的支付账号、银行卡号与支付密码**。

**2.3 本地运行与缓存数据**
· 偏好设置：界面语言、主题、快捷键、窗口背景、桌面歌词开关、登录 Token 等。
· 本地数据库：本地歌单、播放队列、最近播放、下载记录等。
· 缓存数据：在线播放时产生的音频临时缓存、歌词与封面缓存。
· 下载文件：您主动下载的音乐文件及其配套歌词。

**2.4 本地音乐**
播放本地音乐或将本软件设为默认播放器时，软件仅在本机读取音频文件的元数据（曲名、歌手、专辑、封面等）用于展示与播放，**不会将本地音乐文件或元数据上传**。

**2.5 设备与局域网信息**
开启局域网设备同步后，软件会在同一局域网内广播设备名称、平台、IP 地址与播放队列快照，用于设备发现与投送。**该通信仅在本地局域网内进行，不会经由互联网上传。** 您可随时关闭该功能。

**2.6 麦克风同步**
开启麦克风同步后，软件仅在本地将正在播放的音频混入虚拟麦克风设备（Linux 通过 PulseAudio / PipeWire，Windows 通过随附的虚拟声卡驱动），供语音、会议或直播软件选用。**该功能不录音、不采集环境声音，也不上传任何音频数据。** 在 Windows 上安装虚拟声卡驱动可能需要管理员权限。

**2.7 运行日志**
本软件不主动生成持久化的运行日志文件；调试信息仅在进程运行期间输出，不会写入磁盘，也不会自动上传。)TXT")},

            {s(u8"三、信息的使用目的"),
             s(R"TXT(我们仅在以下目的处理上述信息：
· 提供音乐检索、解码、播放、歌词与封面显示等核心功能；
· 在您的账号下同步收藏、歌单、评论与会员权益；
· 在您重新启动软件后恢复个性化配置与播放状态；
· 保障软件在您的设备上安全、稳定地运行；
· 响应您的反馈、咨询与售后需求。

我们**绝不会**将您的数据用于广告推送、用户画像或商业营销，也**绝不会**将其出售或出租给任何第三方。)TXT")},

            {s(u8"四、信息的存储与保存期限"),
             s(R"TXT(**服务端**：您的账号信息与业务数据（收藏、歌单、评论、会员订单等）存储于「Neko歌姬计划」后端服务器（https://music.nekocore.cn）及其数据库，保存至您主动删除、申请注销或相关服务终止。

**本机**：您的本地数据保存在本机以下位置，直至您主动清除或删除：
· 偏好设置：Linux ~/.config/NekoMusic/NekoMusic.conf；Windows 注册表 HKCU\Software\NekoMusic；macOS ~/Library/Preferences。
· 本地数据库：Linux ~/.local/share/NekoMusic/NekoMusic/playlists.db；Windows %LOCALAPPDATA%\NekoMusic\NekoMusic\playlists.db；macOS ~/Library/Application Support/NekoMusic/NekoMusic/playlists.db。
· 音频/封面缓存：Linux /tmp/nekomusic-cache（临时目录，通常位于内存文件系统）；Windows %TEMP%\nekomusic-cache；macOS $TMPDIR/nekomusic-cache。
· 下载文件：系统下载目录下的 NekoMusic 文件夹。

**请注意：卸载可执行文件不一定会自动删除上述数据目录，如需彻底清理请手动删除对应文件或目录。**)TXT")},

            {s(u8"五、信息的共享与第三方"),
             s(R"TXT(· 后端服务：本软件的大部分在线功能需将必要请求发送至「Neko歌姬计划」后端，由其完成检索、流媒体、导入、会员与账号等处理。
· 第三方音乐平台：使用外部歌单导入或访问相关内容时，相关链接、ID 或标识可能被提交至后端并转发至相应平台用于匹配，其数据处理同时受该平台自身条款与隐私政策约束。
· 第三方支付渠道：会员支付由支付宝、微信等支付机构完成，本软件不存储您的支付敏感信息。
· 更新服务：软件会向后端查询版本信息以提供更新，该请求不包含您的个人身份信息。

除法律法规要求、司法机关或行政机关依法要求，或经您明确授权外，我们不会向上述以外的任何第三方提供您的个人信息。)TXT")},

            {s(u8"六、您的权利与数据管理"),
             s(R"TXT(您可以随时在设置中查看与修改偏好与账号资料、修改密码或找回密码；可在软件内清除缓存、最近播放、下载记录与下载文件；可退出登录以清除本机会话 Token，或自行删除本机数据目录以永久销毁本机遗留数据。

如需注销账号或删除服务端数据，可通过下方联系方式与我们联系，我们将在核实身份后依法协助处理。)TXT")},

            {s(u8"七、未成年人隐私保护"),
             s(R"TXT(本软件为通用工具类软件，不针对未成年人收集任何个人信息。若您是未成年人，请在监护人的陪同与指导下阅读本政策，并在取得监护人同意后使用本软件。)TXT")},

            {s(u8"八、隐私政策的更新"),
             s(R"TXT(我们可能随功能迭代、技术架构演进或法律法规变更适时修订本政策。更新后的版本随软件或官方仓库发布，并自文首标注的「最近更新」日期起生效；若您在更新后继续使用本软件，即视为您已阅读、理解并同意更新后的政策。)TXT")},

            {s(u8"九、联系我们"),
             s(R"TXT(如对本政策的内容、您的信息安全或相关事项有任何疑问、意见或申诉，欢迎通过 GitHub 仓库与 Issue 联系我们：
https://github.com/FantasyNetworkCN/NekoMusicForPc

我们将在收到反馈后尽快答复。)TXT")},
        };

        doc.footer = s(u8"本政策最近更新：2026 年 9 月 29 日。");
        return doc;
    }

    // ─────────────────────────────────────────────────────────────
    //  English
    // ─────────────────────────────────────────────────────────────

    LegalDocument userAgreementEn()
    {
        LegalDocument doc;
        doc.title = s("Neko Music for PC — User Agreement");
        doc.version = QStringLiteral("v1.0");
        doc.updated = s("September 29, 2026");
        doc.intro = s(R"TXT(Welcome to Neko Music for PC (NekoMusic, "the Software"). The Software is a third-party open-source desktop client that connects to the open API of the "Neko Music Project". Please read and fully understand this Agreement before using the Software.

**By starting to use the Software (including registration, login, importing playlists, downloading, commenting, purchasing membership, enabling microphone or LAN sync, or any other feature), you confirm that you have read, understood and agreed to be bound by this Agreement. If you do not agree with any part of it, please stop using and uninstall the Software immediately.**)TXT");

        doc.sections = {
            {s("1. Parties and Scope"),
             s(R"TXT(This Agreement is entered into between you and the developer of the Software regarding your download, installation and use of the Software.

The Software is a third-party open-source client and **has no affiliation, partnership, authorization or agency relationship with any music platform or its official client**. The project itself is non-commercial.

Official website: https://music.nekocore.cn
Source repository: https://github.com/FantasyNetworkCN/NekoMusicForPc
Backend & API docs: https://github.com/FantasyNetworkCN/NekoMusicDocs)TXT")},

            {s("2. Open-Source License and Attribution"),
             s(R"TXT(The Software is released under **AGPL-3.0** with additional terms asserted by the author under Section 7 of that license. Subject to the license terms, you may freely use, study, modify and redistribute the Software, and **compliant open-source commercial use is likewise permitted**. No closed-source commercial license exempting AGPL obligations is offered.

When using, modifying or redistributing the Software you must also:
· retain the original copyright, license and attribution notices;
· release your derivative works under the same license;
· if you provide the Software (including modified versions) over a network, provide the corresponding complete source code to those users;
· keep, prominently in the UI, the attribution "Powered by Neko Music API", a link to this program's repository, and the API documentation link;
· support both Chinese and English with a clear language switch.

**Impersonation, or removing or obscuring the "Neko Music Project" branding, is strictly prohibited.** Any violation automatically terminates the relevant license grant. The full terms are governed by the bundled LICENSE file and the official GNU page.)TXT")},

            {s("3. Account Registration and Use"),
             s(R"TXT(Some features require a registered and logged-in "Neko Music Project" account. Registration requires a nickname, email and password, verified by an email code; you may also log in by scanning a QR code with the NekoMusic mobile app.

You must provide true, accurate and lawful registration information. **The account is for your own use only and may not be rented, lent, transferred, shared or traded; all activities under the account are deemed yours and are your responsibility.**

Keep your account and credentials safe, and log out and clear credentials after using public or shared devices. Platforms may apply risk control, restrictions or bans to third-party client logins and requests; any resulting account anomalies or limited features are at your own risk.)TXT")},

            {s("4. Features and Services"),
             s(R"TXT(The Software provides online music search, playback, lyrics and cover display, rankings and daily recommendations, favorites and playlist management, comments, external playlist import, music download, local music playback and default-player takeover, desktop lyrics, global shortcuts, microphone sync, LAN device sync, share-video rendering and a membership center.

The form, scope and availability of these features may be added, adjusted, restricted or discontinued due to version iterations, platform policies, backend capabilities or legal requirements. No feature is guaranteed to be permanently available.)TXT")},

            {s("5. Membership and Payment"),
             s(R"TXT(Membership benefits, plans, prices and durations are subject to the real-time display in the in-app "Membership Center".

Membership orders are created by the backend and completed via third-party payment channels such as Alipay or WeChat Pay. **The Software does not collect or store your payment account, bank card number or payment password.**

After a successful payment, membership duration is stacked according to the selected plan; membership is a virtual service and is generally non-refundable once activated, except as mandatorily required by law. Please pay over a trusted network and beware of phishing and fraud; **transactions made through unofficial channels are unrelated to this site.**)TXT")},

            {s("6. Third-Party Services and External Playlist Import"),
             s(R"TXT(Online music and import capabilities rely on third-party platforms and backend services. When you use external playlist import, the playlist link or ID you submit is sent to the backend, which performs matching, downloading and storing of external content.

The interfaces, authentication and availability of each online music platform are decided unilaterally by the platform and may change, be restricted or shut down at any time, causing login failure, unavailable features or unsynchronized data. **The Software makes no commitment regarding the continuous availability, stability, legality or data integrity of third-party services.**

You must ensure you hold lawful rights to the content you import or access and comply with the source platform's terms of service; any disputes or liabilities arising from your import, download or use are your own.)TXT")},

            {s("7. Content Sources and Copyright"),
             s(R"TXT(The Software itself does not provide, store or distribute any music content (except content uploaded by users themselves). Audio, lyrics, covers and the like come from your local files, public platform interfaces or your own uploads, and their copyright belongs to the original rights holders and platforms. **The Software claims no ownership.**

You must ensure you hold lawful access and usage rights to the relevant content. Copyright data generated during use (playback links, lyrics, covers, etc.) is **for your personal listening and study only; do not use it commercially or distribute it publicly, and it is recommended to clear it within 24 hours**. For long-term enjoyment, please purchase or subscribe through legitimate channels to support genuine music.)TXT")},

            {s("8. User Conduct and Prohibitions"),
             s(R"TXT(You must not engage in any of the following:
· using the Software for commercial activities, bulk scraping, crawling, traffic manipulation or reselling content;
· uploading, posting or spreading unlawful, infringing, pornographic, violent, terroristic, hateful, gambling, fraudulent or otherwise illegal or unethical content (including nicknames, avatars, playlist names and descriptions, comments and uploaded audio);
· circumventing the technical protection measures, access controls or terms of service of online platforms;
· interfering with, attacking, intruding into or otherwise harming the normal operation of the Software, the backend services or third-party platforms, or exploiting vulnerabilities for improper gain;
· impersonation, or removing or obscuring branding, or misleadingly claiming the Software as your own original work;
· using the Software for any purpose that infringes the lawful rights of others.

If you violate the above, we may, within the scope permitted by law, remove content, restrict features, suspend or terminate services, and reserve the right to pursue legal liability.)TXT")},

            {s("9. User Content"),
             s(R"TXT(You are responsible for content you create or upload in the Software (nickname, avatar, playlist information, comments, uploaded audio, etc.) and warrant that it is lawful, truthful and does not infringe any third party's rights.

For the purpose of providing the features, you agree that we may perform necessary storage, display, synchronization and moderation of such content. We may delete or otherwise handle content that violates laws or this Agreement.)TXT")},

            {s("10. Intellectual Property"),
             s(R"TXT(The intellectual property in the Software's UI design, program code, icons and related documents belongs to the developer or the respective rights holders; you may use them lawfully within the open-source license.

Third-party trademarks, musical works and platform names appearing in the Software belong to their respective owners; use of the Software does not imply any authorization or affiliation.)TXT")},

            {s("11. Disclaimer and Limitation of Liability"),
             s(R"TXT(The Software is provided "as is" and **makes no express or implied warranty as to its applicability, stability, accuracy or legality**.

Any direct or indirect loss arising from the use or inability to use the Software, or from platform interface changes, account restrictions, invalid credentials, risk control or bans, feature failures, data loss, device failures, network interruptions, misoperation or force majeure, **is borne by you**.

To the maximum extent permitted by law, the developer is not liable for any indirect, incidental, special or punitive damages. The Software is intended for technical exploration and research only; if a relevant platform deems it inappropriate, the developer may be contacted to adjust or remove it at any time.)TXT")},

            {s("12. Changes and Termination"),
             s(R"TXT(We may revise this Agreement as features iterate, the architecture evolves or laws change. The updated Agreement is released with a software version or in the official repository and takes effect from the "Last updated" date shown at the top.

If you continue to use the Software after an update, you are deemed to have read, understood and agreed to the updated Agreement; if you disagree, please stop using and uninstall the Software. You may stop using the Software at any time and delete local data yourself; we may also restrict, suspend or terminate services in accordance with law or this Agreement.)TXT")},

            {s("13. Minors"),
             s(R"TXT(The Software is a general-purpose tool and is not designed for, nor does it collect personal information from, minors. If you are a minor, please read this Agreement with the accompaniment and guidance of a guardian and use the Software after obtaining the guardian's consent; please manage your time reasonably, avoid addiction, and guardians should fulfill their supervisory duties.)TXT")},

            {s("14. Governing Law and Dispute Resolution"),
             s(R"TXT(The interpretation of this Agreement and the resolution of disputes are governed by the laws of mainland China (excluding conflict-of-law rules).

Disputes arising from this Agreement shall be resolved through friendly negotiation; if negotiation fails, either party may bring a lawsuit before a competent people's court where the developer is located. If any provision is held invalid or unenforceable, the validity of the remaining provisions is unaffected.)TXT")},

            {s("15. Contact Us"),
             s(R"TXT(If you have any questions, comments or complaints about this Agreement, please contact us via our GitHub repository and Issues:
https://github.com/FantasyNetworkCN/NekoMusicForPc

We will respond as soon as possible after receiving your feedback.)TXT")},
        };

        doc.footer = s("The Software is intended for technical exploration and research only. If a relevant platform deems it inappropriate, the developer may be contacted to adjust or remove it at any time.");
        return doc;
    }

    LegalDocument privacyPolicyEn()
    {
        LegalDocument doc;
        doc.title = s("Neko Music for PC — Privacy Policy");
        doc.version = QStringLiteral("v1.0");
        doc.updated = s("September 29, 2026");
        doc.intro = s(R"TXT(Welcome to Neko Music for PC (NekoMusic, "the Software"). We understand the importance of your personal information and are committed to protecting your privacy and data security. This Policy explains how we process, store and protect your information during your use of the Software, and the rights you have.

Please read and fully understand this Policy. **Once you start using the Software, you are deemed to have read, understood and agreed to all of its contents.**)TXT");

        doc.sections = {
            {s("1. Basic Principles"),
             s(R"TXT(· Data minimization: we process only the data necessary to provide basic features, ensure security and improve experience, and do not collect sensitive personal information unrelated to the service.
· Local first: your preferences, local playlists, play queue and caches are stored on your device by default and are under your control.
· Transparency and control: the Software contains no ads, tracking or user profiling; data practices are transparent and can be cleared by you at any time.)TXT")},

            {s("2. Information We Collect and Process"),
             s(R"TXT(**2.1 Information you provide**
· Account information: the nickname, email, password and avatar profile you provide when registering. Passwords are stored encrypted/hashed on the server; the Software never records your password in plain text.
· Login credentials: the session token issued by the server on password login, or the token obtained via QR login.
· External playlist information: the playlist link or ID you submit for external import (NetEase, QQ Music, Kugou, Qishui, etc.).
· User content: comments you post, content you upload, and your nickname, avatar, playlist names and descriptions.

**2.2 Data generated by the service**
· Business data such as favorites, playlists, playback and download records and comments, used for synchronization and display under your account.
· Membership order information (order number, plan, amount, status and time) for activating and querying membership benefits. **Payment is handled by third-party payment channels; the Software does not touch your payment account, bank card number or payment password.**

**2.3 Local runtime and cache data**
· Preferences: UI language, theme, shortcuts, window backdrop, desktop lyrics toggle, login token, etc.
· Local database: local playlists, play queue, recent plays, download records, etc.
· Caches: temporary audio caches generated during online playback, and lyrics/cover caches.
· Downloaded files: music files you download and their accompanying lyrics.

**2.4 Local music**
When playing local music or setting the Software as the default player, it reads audio file metadata (title, artist, album, cover, etc.) on your device for display and playback only, and **does not upload local music files or their metadata**.

**2.5 Device and LAN information**
When you enable LAN device sync, the Software broadcasts the device name, platform, IP address and play-queue snapshot within the same LAN for discovery and casting. **This communication occurs only within the local network and is not uploaded over the internet.** You can turn it off at any time.

**2.6 Microphone sync**
When you enable microphone sync, the Software mixes the audio being played into a virtual microphone device locally (via PulseAudio / PipeWire on Linux; via a bundled virtual sound card driver on Windows) for voice, meeting or streaming apps to select. **This feature does not record, does not capture ambient sound and does not upload any audio data.** Installing the virtual sound card driver on Windows may require administrator privileges.

**2.7 Logs**
The Software does not proactively generate persistent log files; debug information is output only while the process is running, is not written to disk, and is not uploaded automatically.)TXT")},

            {s("3. Purposes of Use"),
             s(R"TXT(We process the above information only for the following purposes:
· to provide core features such as music search, decoding, playback, lyrics and cover display;
· to synchronize favorites, playlists, comments and membership benefits under your account;
· to restore your personalized configuration and playback state after a restart;
· to keep the Software running safely and stably on your device;
· to respond to your feedback, inquiries and support needs.

We will **never** use your data for advertising, user profiling or commercial marketing, and will **never** sell or rent it to any third party.)TXT")},

            {s("4. Storage and Retention"),
             s(R"TXT(**Server side**: your account information and business data (favorites, playlists, comments, membership orders, etc.) are stored on the "Neko Music Project" backend server (https://music.nekocore.cn) and its database, until you delete them, request account cancellation, or the relevant service terminates.

**On your device**: your local data is stored in the following locations until you clear or delete it:
· Preferences: Linux ~/.config/NekoMusic/NekoMusic.conf; Windows registry HKCU\Software\NekoMusic; macOS ~/Library/Preferences.
· Local database: Linux ~/.local/share/NekoMusic/NekoMusic/playlists.db; Windows %LOCALAPPDATA%\NekoMusic\NekoMusic\playlists.db; macOS ~/Library/Application Support/NekoMusic/NekoMusic/playlists.db.
· Audio/cover caches: Linux /tmp/nekomusic-cache (a temporary directory, usually on a memory filesystem); Windows %TEMP%\nekomusic-cache; macOS $TMPDIR/nekomusic-cache.
· Downloaded files: the NekoMusic folder under your system Downloads directory.

**Please note: uninstalling the executable may not automatically delete the above data directories; delete them manually for a complete cleanup.**)TXT")},

            {s("5. Sharing and Third Parties"),
             s(R"TXT(· Backend services: most online features send necessary requests to the "Neko Music Project" backend, which handles search, streaming, import, membership and account processing.
· Third-party music platforms: when using external playlist import or accessing related content, the relevant links, IDs or identifiers may be submitted to the backend and forwarded to the corresponding platform for matching; their processing is also subject to that platform's own terms and privacy policy.
· Third-party payment channels: membership payments are handled by institutions such as Alipay or WeChat Pay; the Software does not store your sensitive payment information.
· Update service: the Software queries the backend for version information to provide updates; this request contains no personally identifiable information.

Except as required by laws and regulations, by judicial or administrative authorities in accordance with law, or with your explicit authorization, we will not provide your personal information to any third party other than those above.)TXT")},

            {s("6. Your Rights and Data Management"),
             s(R"TXT(You may at any time view and modify your preferences and account profile, change your password or recover it; you may clear caches, recent plays, download records and downloaded files within the Software; you may log out to clear the local session token, or delete the local data directory yourself to permanently destroy local residual data.

To cancel your account or delete server-side data, please contact us via the details below; we will assist in accordance with law after verifying your identity.)TXT")},

            {s("7. Minors' Privacy"),
             s(R"TXT(The Software is a general-purpose tool and does not collect any personal information from minors. If you are a minor, please read this Policy with the accompaniment and guidance of a guardian and use the Software after obtaining the guardian's consent.)TXT")},

            {s("8. Updates to This Policy"),
             s(R"TXT(We may revise this Policy as features iterate, the architecture evolves or laws change. The updated version is released with the Software or in the official repository and takes effect from the "Last updated" date shown at the top; if you continue to use the Software after an update, you are deemed to have read, understood and agreed to the updated Policy.)TXT")},

            {s("9. Contact Us"),
             s(R"TXT(If you have any questions, comments or complaints about this Policy, your information security or related matters, please contact the developer via our GitHub repository and Issues:
https://github.com/FantasyNetworkCN/NekoMusicForPc

We will respond as soon as possible after receiving your feedback.)TXT")},
        };

        doc.footer = s("This Policy was last updated on September 29, 2026.");
        return doc;
    }

} // namespace

namespace Legal
{

    LegalDocument userAgreement()
    {
        return I18n::instance().language() == I18n::EnUS ? userAgreementEn() : userAgreementZh();
    }

    LegalDocument privacyPolicy()
    {
        return I18n::instance().language() == I18n::EnUS ? privacyPolicyEn() : privacyPolicyZh();
    }

    bool hasAcceptedConsent()
    {
        QSettings settings;
        return settings.value(QStringLiteral("legal/consentVersion")).toString() == QString::fromLatin1(kVersion);
    }

    void acceptConsent()
    {
        QSettings settings;
        settings.setValue(QStringLiteral("legal/consentVersion"), QString::fromLatin1(kVersion));
    }

} // namespace Legal
