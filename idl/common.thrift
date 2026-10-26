// =====================================================================
// common.thrift — 通用服务（index/ping）
// =====================================================================
// 迁移自: idl/common.proto
// 迁移日期: 2026-07-27
// 字段 1:1 保留 proto 编号（API 兼容）
// =====================================================================
// 注意：健康检查 /health 统一由 health.thrift 的 HealthService 提供
// （/health、/ready、/live、/version、/ping）。本服务历史上也注册过
// /health，与 health.thrift 重复，会导致 Hertz 启动 panic
// （"handlers are already registered for path '/health'"），故移除。
// 本服务仅保留首页 Index (/) 与 Ping (/api/v1/ping)。

namespace go common

// ==================== 通用响应 ====================

struct EmptyReq {
}

// HealthResp 健康状态响应
struct HealthResp {
    1: required string status (api.body = "status"),
}

// IndexResp 服务基本信息
struct IndexResp {
    1: required string name    (api.body = "name"),
    2: required string version (api.body = "version"),
    3: required string status  (api.body = "status"),
}

// PingResp Ping 响应
struct PingResp {
    1: required string message (api.body = "message"),
}

// ==================== 网页端通用面（2026-10-26 自 customHandler 收敛进 IDL） ====================
//
// ⚠️ **为什么这批路由放在 common 域**：core 的部署模式过滤是**按 hz 生成的路由组**
// 挑选的（core/bootstrap/deployment.go 的 registerGeneratedRoutes）⇒ 一个 IDL 域 =
// 一个生成组 = 整组注册/不注册。
//   · genshare 只在 public 副本注册 ⇒ 「匿名上传面」（multi-direct/multi-bind）留在
//     share.thrift ⇒ **仅公开面**，与收敛前一致；
//   · gencommon 在 public 与 admin **两面都注册** ⇒ 会话/元信息/公告/联邦/本地导入
//     这批「各副本都要有」的路由放这里 ⇒ **两面都在**，与收敛前一致。
// ⇒ 迁移不改变任何一条路由的副本可见性（这批路由原先是 bootstrap/routes_custom.go
//    里的无条件注册）。

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
struct UserRefreshData {
    1: required string token (api.body = "token"),
}
struct UserRefreshResp {
    1: required i32           code    (api.body = "code"),
    2: required string        message (api.body = "message"),
    3: required UserRefreshData data   (api.body = "data"),
}
struct UserLogoutResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}
struct UserCheckAuthData {
    1: required i64    id       (api.body = "id"),
    2: required string username (api.body = "username"),
    3: required string role     (api.body = "role"),
}
struct UserCheckAuthResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: required UserCheckAuthData data  (api.body = "data"),
}
struct UserAPIKeysRevokeAllData {
    1: required i64 revoked (api.body = "revoked"),
}
struct UserAPIKeysRevokeAllResp {
    1: required i32                     code    (api.body = "code"),
    2: required string                  message (api.body = "message"),
    3: required UserAPIKeysRevokeAllData data    (api.body = "data"),
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

// ==================== 服务定义 ====================
//
// 注意：根路径 "/" 不在此注册。前端 SPA 首页由 bootstrap.customizedRegister
// 直接服务 static/index.html，避免与 API 路由冲突。本服务仅提供 Ping。

service CommonService {
    // Ping Ping 检查
    PingResp Ping(1: EmptyReq req) (api.get = "/api/v1/ping")
    // ShareMetadata 取件元数据（不扣次数、不要密码；取件页渲染用）
    ShareMetadataResp ShareMetadata(1: ShareMetadataReq req) (api.get = "/share/metadata/:code")

    // UserSharesImportLocal 服务器本地文件导入为分享（NAS 免上传场景）
    UserSharesImportLocalResp UserSharesImportLocal(1: UserSharesImportLocalReq req) (api.post = "/api/v1/user/shares/import-local")

    // UserRefresh 刷新会话令牌（前端 401 拦截器调用；Cookie 认证时须带 CSRF 头）
    UserRefreshResp UserRefresh(1: EmptyReq req) (api.post = "/api/v1/user/refresh")

    // UserLogout 显式注销（令牌进黑名单 + 清 Cookie）
    UserLogoutResp UserLogout(1: EmptyReq req) (api.post = "/api/v1/user/logout")

    // UserCheckAuth 校验登录态并回带用户信息（前端启动时用）
    UserCheckAuthResp UserCheckAuth(1: EmptyReq req) (api.get = "/api/v1/user/check-auth")

    // UserAPIKeysRevokeAll 一键吊销全部 API Key（JWT-only；应急止损）
    UserAPIKeysRevokeAllResp UserAPIKeysRevokeAll(1: EmptyReq req) (api.post = "/user/api-keys/revoke-all")

    // FederationResolve 口令联邦解析（前端录码本站未命中时查联邦；只做发现，不代理流量）
    FederationResolveResp FederationResolve(1: FederationResolveReq req) (api.get = "/api/v1/federation/resolve")

}
