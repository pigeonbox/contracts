// p2p.thrift — P2P 联邦管理端 API（2026-10-22 Wave B'：设备直传面整体拆除）。
//
// 2026-10-22 两应用分拆终态落地：设备直传（p2pc / p2pcweb）已拆为独立应用
// **PigeonBeam（信鸽直传）**，Box 侧不再编排直传。因此直传的 9 个管理端点
// （status / tasks / tasks/:id/log / send / send/upload / recv / cancel /
// tasks/:id/approve / publish）连同任务模型（P2pTask 等）**整体退役**。
//
// 本文件此后**只描述联邦面**：跨站口令路由、邀请信箱、在线名录。
// 直传用户请到 PigeonBeam 客户端完成（Box 侧不再有直传 UX）；
// NAS 随包内嵌的 Beam 客户端可经 Box 的邀请信箱 API 取走信封。
namespace go p2p

// ---- 邀请信封（跨站推送的凭证与状态机）----
// 邀请 = 口令 bearer（与手工交接同信任级）；公开收件端点无鉴权（口令即权限），
// 归 download 限流桶；收件箱 TTL 10 分钟。
struct InviteInfo {
    1: string id          (api.body = "id")
    2: string code        (api.body = "code")
    3: string from_name   (api.body = "from_name")
    4: string note        (api.body = "note")
    5: string received_at (api.body = "received_at")
    6: i64    expires_in  (api.body = "expires_in")
}

// ---- 公开收件（实例间递送口令）----
struct PostP2PInviteReq {
    1: string code      (api.body = "code")
    2: string from_name (api.body = "from_name")
    3: string note      (api.body = "note")
}
struct PostP2PInviteResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
}

// ---- 待收邀请箱 ----
struct AdminP2pInvitesReq {}
struct AdminP2pInvitesData {
    1: list<InviteInfo> invites (api.body = "invites")
}
struct AdminP2pInvitesResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pInvitesData data (api.body = "data")
}

// ---- 认领邀请（2026-10-22 解耦：纯信封，**不再 spawn 直传运行时**）----
// Wave B' 前本端点第二步会 spawn p2pc 子进程接收入站文件（那正是「联邦」
// 与「直传」在运行期焊死的地方：联邦端点的实现住在直传包里）。Box 侧拆除
// 直传编排后，接受邀请退化为**纯信封动作**：出箱 + 留痕 + 返回信封。
// 实际的文件接收由 PigeonBeam 客户端完成（NAS 随包内嵌的 Beam 可经本
// API 取走信封）。
struct AdminP2pInviteAcceptReq {
    1: string invite_id (api.body = "invite_id")
}
struct AdminP2pInviteAcceptData {
    1: InviteInfo invite (api.body = "invite")
}
struct AdminP2pInviteAcceptResp {
    1: required i32 code    (api.body = "code")
    2: required string message (api.body = "message")
    3: AdminP2pInviteAcceptData data (api.body = "data")
}

// ---- 向对端投递邀请（免口令交接）----
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

// ---- 在线名录（p2pd 名录透传，零敏感）----
// 仅 discoverable opt-in 节点；无口令/房间信息。对端选择器消费。
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
// ==================== 联邦解析代理（2026-10-26 自 customHandler 收敛进 IDL） ====================
//
// ⚠️ 未命中时**只有** available 一个字段（其余 optional 不输出）⇒ 与收敛前一致。

struct FederationResolveReq {
    1: required string code (api.query = "code"),
}

struct FederationResolveData {
    1: required bool   available  (api.body = "available"),
    2: optional string url        (api.body = "url"),
    3: optional string node_id    (api.body = "node_id"),
    4: optional string name       (api.body = "name"),
    5: optional i64    expires_at (api.body = "expires_at"),
}

struct FederationResolveResp {
    1: required i32                  code    (api.body = "code"),
    2: required string               message (api.body = "message"),
    3: required FederationResolveData data   (api.body = "data"),
}

service P2PPublicService {
    PostP2PInviteResp PostP2PInvite(1: PostP2PInviteReq req) (api.post = "/api/v1/p2p/invite")

    // ==================== 自 customHandler 收敛进 IDL（2026-10-26） ====================

    // FederationResolve 口令联邦解析（前端录码本站未命中时查联邦；只做发现，不代理流量）
    FederationResolveResp FederationResolve(1: FederationResolveReq req) (api.get = "/api/v1/federation/resolve")

}

// 管理端联邦面（全部挂 /admin 组，AdminMiddleware；操作留审计）
service AdminP2PService {
    AdminP2pInvitesResp AdminP2pInvites(1: AdminP2pInvitesReq req)      (api.get  = "/admin/p2p/invites")
    AdminP2pInviteAcceptResp AdminP2pInviteAccept(1: AdminP2pInviteAcceptReq req) (api.post = "/admin/p2p/invites/accept")
    AdminP2pInvitePushResp AdminP2pInvitePush(1: AdminP2pInvitePushReq req)   (api.post = "/admin/p2p/invite-push")
    AdminP2pDirectoryResp AdminP2pDirectory(1: AdminP2pDirectoryReq req)      (api.get  = "/admin/p2p/directory")
}
