// ==================== 公开面路由（只在**公开副本**注册） ====================
//
// ## 为什么单独一个域
//
// core 的部署模式过滤是**按 hz 生成的路由组**挑选的
// （core/bootstrap/deployment.go 的 registerGeneratedRoutes）⇒ 一个 IDL 域 =
// 一个生成组 = **整组**注册/不注册 ⇒ 域归属直接决定「这条路由在哪些副本上存在」。
//
// 这批路由在 2026-10-26 之前是 bootstrap/routes_custom.go 里的**手写注册**，
// 且都写在 `if config.ServesPublicPlane() {` 内 ⇒ **只在公开副本注册**
// （admin 副本上没有它们 ⇒ 照旧 404）。
//
// ⇒ 放进本域 ⇒ 生成为一个**只在 public 面注册**的组 ⇒ 可见性与收敛前
//   **逐条一致**。⚠️ 若放进 common/share 等「两面都注册」的域，admin 副本会
//   凭空多出这些端点（部署面被放大 ⇒ 安全回归）。
//
// 本域承载：多文件直传/绑定（P0 多文件）、取件元信息、服务器本地文件导入、
// 联邦口令解析。

namespace go publicapi

struct ShareMetadataReq {
    1: required string code (api.path = "code"),
}
struct ShareMetadataData {
    1: required string code         (api.body = "code"),
    2: required string type         (api.body = "type"),        // text | file
    3: optional string name         (api.body = "name"),        // 仅 file 分享
    4: required i64    size         (api.body = "size"),
    5: required bool   has_password (api.body = "has_password"),
    6: optional string expired_at   (api.body = "expired_at"),  // RFC3339
    7: required i32    expired_count (api.body = "expired_count"), // -1 无限 / 0 耗尽 / >0 剩余
    8: required i32    used_count   (api.body = "used_count"),
    9: required bool   encrypted    (api.body = "encrypted"),
    10: required i64   file_count   (api.body = "file_count"),
    11: required string created_at  (api.body = "created_at"),  // RFC3339
    // 口令型 E2E 标志（2026-11-01，core#30）：true = 取件需「口令」解锁 wrapped_key。
    // ⚠️ 只给标志、**不给 wrapped_key 本体**（本体只随 GetShare 详情下发）；
    // 「缺字段 ≠ false」：老后端不下发 ⇒ 前端按未知处理，不得据此隐藏口令输入。
    12: optional bool  has_wrapped_key (api.body = "has_wrapped_key"),
}
struct ShareMetadataResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: required ShareMetadataData data   (api.body = "data"),
}
struct UserSharesImportLocalReq {
    1: required string path         (api.body = "path"),
    2: optional i32    expire_value (api.body = "expire_value"),
    3: optional string expire_style (api.body = "expire_style"),
    4: optional bool   require_auth (api.body = "require_auth"),
    5: optional string password     (api.body = "password"),
    6: optional string custom_code  (api.body = "custom_code"),
}
struct UserSharesImportLocalData {
    1: required string code      (api.body = "code"),
    2: required string share_url (api.body = "share_url"),
}
struct UserSharesImportLocalResp {
    1: required i32                    code    (api.body = "code"),
    2: required string                 message (api.body = "message"),
    3: required UserSharesImportLocalData data  (api.body = "data"),
}
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
struct MultiShareDirectReq {
    1: optional i32    expire_value (api.form = "expire_value"),
    2: optional string expire_style (api.form = "expire_style"),
    3: optional bool   require_auth (api.form = "require_auth"),
    4: optional string password     (api.form = "password"),
    5: optional bool   encrypted    (api.form = "encrypted"),
    6: optional string custom_code  (api.form = "custom_code"),
    7: optional string note         (api.form = "note"),
    // 口令型 E2E 包装密钥（2026-11-02，core#30）：多文件直传的全部子文件共用一把内容密钥，
    // 语义/格式同 ShareTextReq.wrapped_key（服务端零知识：只存只发）
    8: optional string wrapped_key  (api.form = "wrapped_key"),
}
struct MultiShareBindReq {
    1: optional i32    expire_value (api.body = "expire_value"),
    2: optional string expire_style (api.body = "expire_style"),
    3: optional bool   require_auth (api.body = "require_auth"),
    4: optional string password     (api.body = "password"),
    5: optional bool   encrypted    (api.body = "encrypted"),
    6: optional string custom_code  (api.body = "custom_code"),
    7: optional string note         (api.body = "note"),
    // 口令型 E2E 包装密钥（2026-11-02，core#30）：语义/格式同 ShareTextReq.wrapped_key
    8: optional string wrapped_key  (api.body = "wrapped_key"),
    9: required list<MultiShareBindEntry> entries (api.body = "entries"),
}
struct MultiShareData {
    1: required string code        (api.body = "code"),
    2: required string url         (api.body = "url"),
    3: required string share_url   (api.body = "share_url"),
    4: required i32    file_count  (api.body = "file_count"),
    5: optional string pickup_code (api.body = "pickup_code"),
}
struct MultiShareDirectResp {
    1: required i32          code    (api.body = "code"),
    2: required string       message (api.body = "message"),
    3: required MultiShareData data   (api.body = "data"),
}
struct MultiShareBindResp {
    1: required i32          code    (api.body = "code"),
    2: required string       message (api.body = "message"),
    3: required MultiShareData data   (api.body = "data"),
}

// MultiShareBindEntry multi-bind 的一个条目（分片会话 或 已直传对象，二选一）。
struct MultiShareBindEntry {
    1: optional string upload_id  (api.body = "upload_id"),
    2: optional string object_key (api.body = "object_key"),
    3: required string file_name  (api.body = "file_name"),
}

// ==================== 跨站投递（联邦前台化，2026-11-01） ====================
//
// 形态（设计稿：docs/specs/2026-11-01-federation-frontend-delivery-design.md）：
//
//	访客 ──① 在本站（A 柜）填「对方柜 URL」+ 选文件
//	        A 柜 ──② 校验目标 ∈ 管理员登记的「可投递对端」
//	        A 柜 ──③ 带共享口令调对方柜（B 柜）铸投递槽位
//	        A 柜 ──④ 把文件转发到 B 柜的 /api/v1/request/:token/upload
//	                B 柜落库 ⇒ **B 柜的 share 域铸 6 位取件码**
//	        A 柜 ──⑤ 把 B 的 6 位码回给访客（访客转告取件人）
//	取件人 ──⑥ 在 **B 柜** 用 6 位码取件
//
// 关键语义：
//
//	· **取件码由对方柜铸** ⇒ 码空间天然是对方的（取件人站在对方柜取件）
//	  ⇒ 不需要跨柜共享码空间，也不需要「A 柜铸、B 柜认」的额外协议。
//	· 信任模型 = **口令 bearer**（同现有联邦的「口令即权限」手工交接级）；
//	  口令由**双方管理员事先登记**（双向登记才允许投递）。
//	· 出站目标 URL **只来自管理员登记的对端**，不是访客任意输入
//	  ⇒ SSRF 面从「任意 URL」收窄到「admin 配的 URL」；
//	  私网对端（自托管常态）按**对端粒度**放行，不动全局 SSRF 开关。
//
// ==================== 对方柜侧：铸投递槽位 ====================

struct FederationDeliverySlotReq {
    1: optional string from_name (api.body = "from_name")  // 发起柜展示名
    2: optional string note      (api.body = "note")       // 留言
    3: optional string title     (api.body = "title")      // 投递链接标题
}
struct FederationDeliverySlotData {
    1: required string token (api.body = "token")  // 寄件码 token（投递链接令牌）
}
struct FederationDeliverySlotResp {
    1: required i32                        code    (api.body = "code")
    2: required string                     message (api.body = "message")
    3: optional FederationDeliverySlotData data    (api.body = "data")
}

// ==================== 发起柜侧：访客跨站投递 ====================

struct FederationDeliverReq {
    // 对方柜基址（URL 口径；须命中本站登记的「可投递对端」，否则拒绝）
    1: required string target_url (api.body = "target_url")
    2: optional string title      (api.body = "title")
    3: optional string note       (api.body = "note")
    // 文件通过 multipart/form-data 上传（字段名 files，兼容 file；1-100 项），
    // 文件本体不入契约，handler 手工取（同 MultiShareDirect 形态）。
}
struct FederationDeliverData {
    1: required i32    file_count   (api.body = "file_count")
    // 对方柜铸的 6 位取件码（**在对方柜使用**；本站不铸码，只透传）
    2: optional string pickup_code (api.body = "pickup_code")
    3: optional string target_url  (api.body = "target_url")
}
struct FederationDeliverResp {
    1: required i32                    code    (api.body = "code")
    2: required string                 message (api.body = "message")
    3: optional FederationDeliverData data    (api.body = "data")
}

// ==================== 服务定义 ====================

service PublicApiService {
    // ShareMetadata 取件元数据（不扣次数、不要密码；取件页渲染用）
    ShareMetadataResp ShareMetadata(1: ShareMetadataReq req) (api.get = "/share/metadata/:code")
    // UserSharesImportLocal 服务器本地文件导入为分享（NAS 免上传场景）
    UserSharesImportLocalResp UserSharesImportLocal(1: UserSharesImportLocalReq req) (api.post = "/api/v1/user/shares/import-local")
    // FederationResolve 口令联邦解析（前端录码本站未命中时查联邦；只做发现，不代理流量）
    FederationResolveResp FederationResolve(1: FederationResolveReq req) (api.get = "/api/v1/federation/resolve")
        // MultiShareDirect 多文件直传建分享（multipart；文件本体不入契约，handler 手工取）
    MultiShareDirectResp MultiShareDirect(1: MultiShareDirectReq req) (api.post = "/api/v1/share/multi-direct")
    // MultiShareBind 多文件绑定建分享（分片会话 / 已直传对象）
    MultiShareBindResp MultiShareBind(1: MultiShareBindReq req) (api.post = "/api/v1/share/multi-bind")
    // FederationDeliverySlot 为对面柜铸一个访客投递槽位（公开面；口令 bearer 授权）
    FederationDeliverySlotResp FederationDeliverySlot(1: FederationDeliverySlotReq req) (api.post = "/api/v1/federation/delivery-slot")
    // FederationDeliver 访客跨站投递：转发到已登记对端，返回对方柜铸的取件码
    // （multipart；文件本体不入契约，handler 手工取）
    FederationDeliverResp FederationDeliver(1: FederationDeliverReq req) (api.post = "/api/v1/federation/deliver")
}
