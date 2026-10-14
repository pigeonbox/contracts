// p2p.thrift — P2P 设备直传管理端 API（2026-10-14 对称节点 spec §7/§8）。
// 全部端点挂 /admin 组（AdminMiddleware）；数据面=supervisor spawn p2pc 子进程，
// 本 API 只做任务编排，不代理文件流量。
namespace go p2p

// ---- 任务模型 ----
struct P2pTask {
    1: string id           (api.body = "id")
    2: string kind         (api.body = "kind")      // send | recv
    3: string state        (api.body = "state")     // waiting|running|done|failed|canceled|expired
    4: string code         (api.body = "code")      // send 任务配对口令（recv 为输入码）
    5: list<string> paths  (api.body = "paths")     // send=发送源路径 recv=收件相对路径
    6: i64    bytes_done   (api.body = "bytes_done")
    7: string error        (api.body = "error")
    8: string created_at   (api.body = "created_at")
    9: string finished_at  (api.body = "finished_at")
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

// ---- 发起发送 ----
struct AdminP2pSendReq {
    1: list<string> paths (api.body = "paths") // 服务器本地路径,须命中 send_roots 白名单
}
struct AdminP2pTaskData {
    1: P2pTask task (api.body = "task")
}
struct AdminP2pSendResp {
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

// 公开收件端点(限流桶=download;实例间递送口令)
service P2PPublicService {
    PostP2PInviteResp PostP2PInvite(1: PostP2PInviteReq req) (api.post = "/api/v1/p2p/invite")
}

service AdminP2PService {
    AdminP2pStatusResp  AdminP2pStatus (1: AdminP2pStatusReq req)   (api.get  = "/admin/p2p/status")
    AdminP2pTasksResp   AdminP2pTasks  (1: AdminP2pTasksReq req)    (api.get  = "/admin/p2p/tasks")
    AdminP2pSendResp    AdminP2pSend   (1: AdminP2pSendReq req)     (api.post = "/admin/p2p/send")
    AdminP2pRecvResp    AdminP2pRecv   (1: AdminP2pRecvReq req)     (api.post = "/admin/p2p/recv")
    AdminP2pCancelResp  AdminP2pCancel (1: AdminP2pCancelReq req)   (api.post = "/admin/p2p/cancel")
    AdminP2pPublishResp AdminP2pPublish(1: AdminP2pPublishReq req)  (api.post = "/admin/p2p/publish")
    AdminP2pInvitesResp AdminP2pInvites(1: AdminP2pInvitesReq req)      (api.get  = "/admin/p2p/invites")
    AdminP2pInviteAcceptResp AdminP2pInviteAccept(1: AdminP2pInviteAcceptReq req) (api.post = "/admin/p2p/invites/accept")
    AdminP2pInvitePushResp AdminP2pInvitePush(1: AdminP2pInvitePushReq req)   (api.post = "/admin/p2p/invite-push")
}
