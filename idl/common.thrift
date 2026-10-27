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

// ==================== 站级公开公告（2026-10-26 自 customHandler 收敛进 IDL） ====================
//
// ⚠️ **为什么公告端点不放在 notify.thrift**：hz 生成的路由是**按路径**建组的
// （cmd/hz 的 RouterNode.FindNearest/Insert 走路径树），同一路径前缀下的路由**共用
// 同一组中间件**。notify.thrift 的 /api 组挂了 UserOrAPIKey（2026-10-09「我的通知」
// 组的守卫），所以 /api/v1/notifies/public 一旦留在 notify.thrift 就会落进那个组 ⇒
// 公开公告端点被误加登录门槛（收敛前是 `r.GET(...)` 无中间件的匿名端点）。
// 而 hz 是**按 IDL 文件**各生成一棵独立的路由树 ⇒ 把该端点挪到 common.thrift，
// 它落在 common 域自己的 /api 组（该组不带鉴权）⇒ 恢复匿名可访问。
//
// 副本可见性不变：本域在 public 与 admin **两面都注册**（gencommon），与收敛前
// 「无条件注册」一致。

// 公开公告条目（⚠️ start_at/end_at 运行时**可能回 null**）。
//
// ⚠️ **形状差（2026-10-27 真机冒烟实测记录）**：该端点的响应**不是**由本契约的
// 模型序列化出来的 —— core 侧是 transport/http/handler/notify_public.go 里的
// 手工 map（逐字段挑的 7 个字段），未设置生效窗口时 **start_at/end_at 显式回
// null**（而不是空串、也不是缺省）。
// ⇒ 这里把两字段声明为 **optional**（TS 侧 `start_at?: string`）而不是 required：
//   required 会让 TS 以为它恒为 string，消费面直接 `.slice()`/`.length` 会在
//   运行时被 null 打断；optional 至少让 TS 强制消费面处理「可能没有」。
// ⚠️ 消费面仍不得当非空字符串用（null ≠ undefined）；本仓库的公告横幅组件
// （NotifyBanner.vue）不消费这两个字段。
struct NotifyPublicItem {
    1: required i64    id       (api.body = "id"),
    2: required string title    (api.body = "title"),
    3: required string content  (api.body = "content"),
    4: required string type     (api.body = "type"),
    5: required string level    (api.body = "level"),
    6: optional string start_at (api.body = "start_at"),
    7: optional string end_at   (api.body = "end_at"),
}

struct NotifyPublicListReq {
}

struct NotifyPublicListData {
    1: required list<NotifyPublicItem> items (api.body = "items"),
}

struct NotifyPublicListResp {
    1: required i32                 code    (api.body = "code"),
    2: required string              message (api.body = "message"),
    3: required NotifyPublicListData data   (api.body = "data"),
}

// ==================== 服务定义 ====================
//
// 注意：根路径 "/" 不在此注册。前端 SPA 首页由 bootstrap.customizedRegister
// 直接服务 static/index.html，避免与 API 路由冲突。本服务仅提供 Ping。

service CommonService {
    // Ping Ping 检查
    PingResp Ping(1: EmptyReq req) (api.get = "/api/v1/ping")


    // UserRefresh 刷新会话令牌（前端 401 拦截器调用；Cookie 认证时须带 CSRF 头）
    UserRefreshResp UserRefresh(1: EmptyReq req) (api.post = "/api/v1/user/refresh")

    // UserLogout 显式注销（令牌进黑名单 + 清 Cookie）
    UserLogoutResp UserLogout(1: EmptyReq req) (api.post = "/api/v1/user/logout")

    // UserCheckAuth 校验登录态并回带用户信息（前端启动时用）
    UserCheckAuthResp UserCheckAuth(1: EmptyReq req) (api.get = "/api/v1/user/check-auth")

    // UserAPIKeysRevokeAll 一键吊销全部 API Key（JWT-only；应急止损）
    UserAPIKeysRevokeAllResp UserAPIKeysRevokeAll(1: EmptyReq req) (api.post = "/user/api-keys/revoke-all")

    // NotifyPublicList 站级公开公告列表（匿名可访问；最多 50 条）
    NotifyPublicListResp NotifyPublicList(1: NotifyPublicListReq req) (api.get = "/api/v1/notifies/public")

}
