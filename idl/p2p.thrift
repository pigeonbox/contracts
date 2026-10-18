// p2p.thrift — P2P 设备直传管理端 API（2026-10-14 对称节点 spec §7/§8）。
// 全部端点挂 /admin 组（AdminMiddleware）；数据面=supervisor spawn p2pc 子进程，
// 本 API 只做任务编排，不代理文件流量。
namespace go p2p

// ---- 任务模型 ----
struct P2pTask {
    1: string id           (api.body = "id")
    2: string kind         (api.body = "kind")      // send | recv
    3: string state        (api.body = "state")     // waiting|running|retrying|done|failed|canceled|expired
    4: string code         (api.body = "code")      // send 任务配对口令/配对码（recv 为输入码;配对模式下 4 位码,重铸即更新）
    5: list<string> paths  (api.body = "paths")     // send=发送源路径 recv=收件相对路径
    6: i64    bytes_done   (api.body = "bytes_done")
    7: string error        (api.body = "error")
    8: string created_at   (api.body = "created_at")
    9: string finished_at  (api.body = "finished_at")
    10: i32 attempts       (api.body = "attempts")  // 自动续传环已重试次数(0=首发)
    11: i64   bytes_total  (api.body = "bytes_total") // 传输总字节(0=未知;p2pc 进度行回填,前端画进度条)
    12: bool  pair_pending (api.body = "pair_pending") // 配对码:有待裁决敲门请求(2026-10-18)
    13: string pair_from    (api.body = "pair_from")    // 配对码:敲门方 node_id
    14: string pair_name    (api.body = "pair_name")    // 配对码:敲门方显示名(接受门展示)
}

// ---- 状态 ----
struct AdminP2pStatusData {
    1: bool   available     (api.body = "available")     // p2pc 二进制探测到
    2: string binary_path   (api.body = "binary_path")
    3: bool   enabled       (api.body = "enabled")       // 配置开关（p2p.direct.enabled）
    4: string registry_url  (api.body = "registry_url")  // 生效注册中心（含缺省回填）
    5: string recv_dir      (api.body = "recv_dir")
    6: i64    inbox_used    (api.body = "inbox_used")
    7: i64    inbox_quota   (api.body = "inbox_quota")
    8: bool   deploy_allowed(api.body = "deploy_allowed") // standalone 才允许
}
struct AdminP2pStatusReq {}
struct AdminP2pStatusResp {
    1: required i32  code    (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pStatusData data (api.body = "data")
}

// ---- 任务列表 ----
struct AdminP2pTasksReq {}
struct AdminP2pTasksData {
    1: list<P2pTask> tasks (api.body = "tasks")
}
struct AdminP2pTasksResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pTasksData data (api.body = "data")
}

// ---- 任务日志（2026-10-16 深度易用化:失败诊断免登服务器;p2pc 行级环 256 行）----
struct AdminP2pTaskLogReq {
    1: required string task_id (api.path = "task_id")
}
struct AdminP2pTaskLogData {
    1: list<string> lines (api.body = "lines") // 时间正序;环满为最近 256 行
}
struct AdminP2pTaskLogResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pTaskLogData data (api.body = "data")
}

// ---- 发起发送 ----
struct AdminP2pSendReq {
    1: list<string> paths (api.body = "paths") // 服务器本地路径,须命中 send_roots 白名单
    2: optional string invite_to   (api.body = "invite_to")   // 发送后向该名录对端投递密封邀请(node_id;2026-10-14 在线名录)
    3: optional string invite_note (api.body = "invite_note") // 邀请附言
    4: optional bool pair          (api.body = "pair")        // 配对码模式(2026-10-18):亮 4 位定时码,敲码请求经 approve 裁决
}
struct AdminP2pTaskData {
    1: P2pTask task (api.body = "task")
}
struct AdminP2pSendResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pTaskData data (api.body = "data")
}

// ---- 浏览器文件直发（2026-10-15:p2pcweb 体验融入管理台）----
// 管理员从浏览器选文件,经 multipart 上传落服务器临时区后立即编排 p2pc send。
// 上传临时区自带发送授权(文件是本端点刚写入的,等效白名单,不查 send_roots,
// 防 admin 令牌失窃借此读服务器既有文件);任务终态自动清理临时文件。
// 文件经 multipart/form-data 上传(字段名 files,兼容 file;1-20 项),
// 总量受 p2p.direct.max_task_bytes 单任务配额闸。
struct AdminP2pUploadSendReq {
    1: optional string invite_to   (api.query = "invite_to")   // 同 /admin/p2p/send:发送后密封投递邀请
    2: optional string invite_note (api.query = "invite_note") // 邀请附言
}
struct AdminP2pUploadSendResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pTaskData data (api.body = "data")
}

// ---- 发起接收 ----
struct AdminP2pRecvReq {
    1: string code (api.body = "code") // 12 位连字符口令,大小写不敏感
}
struct AdminP2pRecvResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pTaskData data (api.body = "data")
}

// ---- 取消 ----
struct AdminP2pCancelReq {
    1: string task_id (api.body = "task_id")
}
struct AdminP2pCancelResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
}

// ---- 配对码裁决（2026-10-18）----
// 亮码任务的接受门:pair_request 待裁决时,管理员接受/拒绝敲门请求。
// 转发到 p2px Approve → 子进程 stdin 单行协议;拒绝即烧码并自动重铸新码。
struct AdminP2pPairApproveReq {
    1: required string task_id (api.path = "task_id")
    2: required bool   accept  (api.body = "accept")
}
struct AdminP2pPairApproveData {
    1: P2pTask task (api.body = "task")
}
struct AdminP2pPairApproveResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pPairApproveData data (api.body = "data")
}

// ---- 收件发布为分享（复用 share.ImportLocalFile 铸链,配额/审核同权） ----
struct AdminP2pPublishReq {
    1: string task_id      (api.body = "task_id")
    2: i64    expire_value (api.body = "expire_value")
    3: string expire_style (api.body = "expire_style") // day|hour|minute|count|forever
    4: bool   require_auth (api.body = "require_auth")
    5: string password     (api.body = "password")
    6: string custom_code  (api.body = "custom_code")
}
struct AdminP2pPublishData {
    1: list<string> share_codes (api.body = "share_codes") // 每文件一个分享
}
struct AdminP2pPublishResp {
    1: required i32 code (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pPublishData data (api.body = "data")
}

// ---- P3 实例间推送邀请(免口令交接;spec §14) ----
// 邀请=口令 bearer(与手工交接同信任级);公开收件端点无鉴权(口令即权限),
// 归 download 限流桶;收件箱 TTL 10 分钟(=p2pc 配对窗口)。
struct InviteInfo {
    1: string id          (api.body = "id")
    2: string code        (api.body = "code")
    3: string from_name   (api.body = "from_name")
    4: string note        (api.body = "note")
    5: string received_at (api.body = "received_at")
    6: i64    expires_in  (api.body = "expires_in")
}

struct PostP2PInviteReq {
    1: string code      (api.body = "code")
    2: string from_name (api.body = "from_name")
    3: string note      (api.body = "note")
}
struct PostP2PInviteResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
}

struct AdminP2pInvitesReq {}
struct AdminP2pInvitesData {
    1: list<InviteInfo> invites (api.body = "invites")
}
struct AdminP2pInvitesResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pInvitesData data (api.body = "data")
}

struct AdminP2pInviteAcceptReq {
    1: string invite_id (api.body = "invite_id")
}
struct AdminP2pInviteAcceptResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pTaskData data (api.body = "data")
}

struct AdminP2pInvitePushReq {
    1: string code       (api.body = "code")
    2: string target_url (api.body = "target_url")
    3: string from_name  (api.body = "from_name")
    4: string note       (api.body = "note")
}
struct AdminP2pInvitePushResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
}

// ---- 在线名录(2026-10-14 邀请信箱配套):p2pd 名录透传,零敏感 ----
// 仅 discoverable opt-in 节点;无口令/房间信息。对端选择器(发送卡下拉)消费。
struct P2pDirectoryPeer {
    1: string node_id      (api.body = "node_id")
    2: string name         (api.body = "name")
    3: string url          (api.body = "url")           // 对外基址(NAT 后可为空)
    4: string box_pub      (api.body = "box_pub")       // X25519 密封公钥 hex
    5: i64    online_since (api.body = "online_since")  // 租约起始 unix 秒
}
struct AdminP2pDirectoryReq {}
struct AdminP2pDirectoryData {
    1: list<P2pDirectoryPeer> peers (api.body = "peers")
}
struct AdminP2pDirectoryResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pDirectoryData data (api.body = "data")
}

// 公开收件端点(限流桶=download;实例间递送口令)
service P2PPublicService {
    PostP2PInviteResp PostP2PInvite(1: PostP2PInviteReq req) (api.post = "/api/v1/p2p/invite")
}

service AdminP2PService {
    AdminP2pStatusResp  AdminP2pStatus (1: AdminP2pStatusReq req)   (api.get  = "/admin/p2p/status")
    AdminP2pTasksResp   AdminP2pTasks  (1: AdminP2pTasksReq req)    (api.get  = "/admin/p2p/tasks")
    AdminP2pTaskLogResp AdminP2pTaskLog(1: AdminP2pTaskLogReq req)   (api.get  = "/admin/p2p/tasks/:task_id/log")
    AdminP2pSendResp    AdminP2pSend   (1: AdminP2pSendReq req)     (api.post = "/admin/p2p/send")
    AdminP2pUploadSendResp AdminP2pUploadSend(1: AdminP2pUploadSendReq req) (api.post = "/admin/p2p/send/upload")
    AdminP2pRecvResp    AdminP2pRecv   (1: AdminP2pRecvReq req)     (api.post = "/admin/p2p/recv")
    AdminP2pCancelResp  AdminP2pCancel (1: AdminP2pCancelReq req)   (api.post = "/admin/p2p/cancel")
    AdminP2pPairApproveResp AdminP2pPairApprove(1: AdminP2pPairApproveReq req) (api.post = "/admin/p2p/tasks/:task_id/approve")
    AdminP2pPublishResp AdminP2pPublish(1: AdminP2pPublishReq req)  (api.post = "/admin/p2p/publish")
    AdminP2pInvitesResp AdminP2pInvites(1: AdminP2pInvitesReq req)      (api.get  = "/admin/p2p/invites")
    AdminP2pInviteAcceptResp AdminP2pInviteAccept(1: AdminP2pInviteAcceptReq req) (api.post = "/admin/p2p/invites/accept")
    AdminP2pInvitePushResp AdminP2pInvitePush(1: AdminP2pInvitePushReq req)   (api.post = "/admin/p2p/invite-push")
    AdminP2pDirectoryResp AdminP2pDirectory(1: AdminP2pDirectoryReq req)      (api.get  = "/admin/p2p/directory")
}
