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
}
struct MultiShareBindReq {
    1: optional i32    expire_value (api.body = "expire_value"),
    2: optional string expire_style (api.body = "expire_style"),
    3: optional bool   require_auth (api.body = "require_auth"),
    4: optional string password     (api.body = "password"),
    5: optional bool   encrypted    (api.body = "encrypted"),
    6: optional string custom_code  (api.body = "custom_code"),
    7: optional string note         (api.body = "note"),
    8: required list<MultiShareBindEntry> entries (api.body = "entries"),
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
}
