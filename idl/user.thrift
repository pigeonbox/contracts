// =====================================================================
// user.thrift — 用户模块
// =====================================================================
// 迁移自: idl/user.proto
// =====================================================================

namespace go user

// ==================== 用户注册 ====================

struct RegisterReq {
    1: required string username (api.body = "username"),
    2: required string email    (api.body = "email"),
    3: required string password (api.body = "password"),
    4: required string nickname (api.body = "nickname"),
}

struct UserData {
    1: required i64    id         (api.body = "id"),
    2: required string username   (api.body = "username"),
    3: required string email      (api.body = "email"),
    4: required string nickname   (api.body = "nickname"),
    5: required string avatar     (api.body = "avatar"),
    6: required i32    status     (api.body = "status"),
    7: required string created_at (api.body = "created_at"),
    // role 仅 /user/info 返回(handler 补发,前端 admin 判定依赖),/user/login 载荷不含
    8: optional string role       (api.body = "role"),
    // 9: 是否已开启二次验证（5.2.0）。前端据此显隐安全设置页的绑定/解绑入口。
    9: optional bool   totp_enabled (api.body = "totp_enabled"),
}

struct RegisterResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required UserData  data    (api.body = "data"),
}

// ==================== 用户登录 ====================

struct LoginReq {
    1: required string username (api.body = "username"),
    2: required string password (api.body = "password"),
    // 3: 二次验证码（5.2.0）。仅在账号已开启 TOTP 时必填：
    //    缺省且账号已开启 ⇒ 返回 40012（前端据此弹第二个输入框，**不是**错误提示）；
    //    填了但不对 ⇒ 40013（计入既有失败锁定桶）。
    3: optional string totp_code (api.body = "totp_code"),
}

struct LoginData {
    1: required string   token (api.body = "token"),
    2: required UserData user  (api.body = "user"),
}

struct LoginResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required LoginData data    (api.body = "data"),
}

// ==================== 用户信息 ====================

struct UserInfoReq {
}

struct UserInfoResp {
    1: required i32      code    (api.body = "code"),
    2: required string   message (api.body = "message"),
    3: required UserData data    (api.body = "data"),
}

// ==================== 用户资料更新 ====================

struct UpdateProfileReq {
    1: required string nickname (api.body = "nickname"),
    2: required string avatar   (api.body = "avatar"),
}

struct UpdateProfileResp {
    1: required i32      code    (api.body = "code"),
    2: required string   message (api.body = "message"),
    3: required UserData data    (api.body = "data"),
}

// ==================== 修改密码 ====================

struct ChangePasswordReq {
    1: required string old_password (api.body = "old_password"),
    2: required string new_password (api.body = "new_password"),
}

struct ChangePasswordResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 用户统计信息 ====================

struct UserStatsReq {
}

struct UserStats {
    1: required i64 total_uploads (api.body = "total_uploads"),
    2: required i64 total_size    (api.body = "total_size"),
    3: required i64 quota_used    (api.body = "quota_used"),
    4: required i64 quota_limit   (api.body = "quota_limit"),
}

struct UserStatsResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required UserStats data    (api.body = "data"),
}

// ==================== 空请求 ====================

struct EmptyReq {
}

// ==================== 用户文件列表 ====================

struct UserFilesReq {
    1: required i32 page      (api.query = "page"),
    2: required i32 page_size (api.query = "page_size"),
}

// prefix/suffix 已退役（2026-10-26）：旧直传布局的「原始名拆分」死列，
// 全库恒空且无写入方；文件名统一走 file_name。
struct UserFileItem {
    1: required i64    id            (api.body = "id"),
    2: required string code          (api.body = "code"),
    3: required string file_name     (api.body = "file_name"),
    4: required string file_path     (api.body = "file_path"),
    5: required i64    size          (api.body = "size"),
    6: required string expired_at    (api.body = "expired_at"),
    7: required i32    expired_count (api.body = "expired_count"),
    8: required i32   used_count    (api.body = "used_count"),
    9: required string created_at   (api.body = "created_at"),
    10: required string updated_at   (api.body = "updated_at"),
}

struct UserFilePagination {
    1: required i32    page        (api.body = "page"),
    2: required i32    page_size   (api.body = "page_size"),
    3: required i64    total       (api.body = "total"),
    4: required i32    total_pages (api.body = "total_pages"),
    5: required bool   has_next    (api.body = "has_next"),
    6: required bool   has_prev    (api.body = "has_prev"),
}

struct UserFileList {
    1: required list<UserFileItem>     files      (api.body = "files"),
    2: required UserFilePagination     pagination (api.body = "pagination"),
}

struct UserFilesResp {
    1: required i32          code    (api.body = "code"),
    2: required string       message (api.body = "message"),
    3: required UserFileList data    (api.body = "data"),
}

// ==================== API Key 管理 ====================

struct APIKeyData {
    1: required i64    id           (api.body = "id"),
    2: required string name         (api.body = "name"),
    3: required string prefix       (api.body = "prefix"),
    4: required string last_used_at (api.body = "last_used_at"),
    5: required string expires_at   (api.body = "expires_at"),
    6: required string created_at   (api.body = "created_at"),
    7: required bool   revoked      (api.body = "revoked"),
    // 8: 权限范围（2026-10-30）：该 Key 被允许的能力面。
    //    **缺省/空 = 全量**（与本字段引入前行为完全一致 ⇒ 老 Key 无需重建）。
    //    取值：admin（管理面）/ user（用户自有资源）/ share（寄件·取件）。
    //    服务端按**请求路径**判定所需能力，Key 缺该能力 ⇒ 403。
    8: optional list<string> scopes (api.body = "scopes"),
    // 9: 撤销时间（2026-10-30 真机实录补齐）。
    //    撤销是**软撤销**（保留审计留痕，列表**含**已撤销项），DB 里 revoked_at
    //    一直有值，但此前**响应里没有这个字段** ⇒ 用户/前端看不到「这把 Key 是什么
    //    时候被撤销的」⇒ 审计信息断在回传面。空串 = 未撤销。
    9: optional string revoked_at (api.body = "revoked_at"),
}

struct APIKeyListResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: required list<APIKeyData> keys    (api.body = "keys"),
}

struct CreateAPIKeyReq {
    1: required string name             (api.body = "name"),
    2: optional string expires_at       (api.body = "expires_at"),
    3: optional i64    expires_in_days  (api.body = "expires_in_days"),
    // 4: 权限范围（2026-10-30）：缺省 = 全量（老行为不变）。
    //    取值：admin / user / share；服务端校验取值合法，非法值直接 400。
    4: optional list<string> scopes     (api.body = "scopes"),
}

struct CreateAPIKeyData {
    1: required string    key     (api.body = "key"),
    2: required APIKeyData api_key (api.body = "api_key"),
}

struct CreateAPIKeyResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: required CreateAPIKeyData data    (api.body = "data"),
}

struct DeleteAPIKeyReq {
    1: required i64 id (api.path = "id"),
}

struct DeleteAPIKeyResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 会话与 API Key（2026-10-26 自 customHandler 收敛进 IDL） ====================
//
// ⚠️ 收敛前这些端点是 bootstrap/routes_custom.go 里的**内联闭包**（无契约）⇒
//   wire 形状按现状镜像：logout 成功响应**没有 data 字段**（不声明 data）。








// ==================== 账号与信任（5.2.0） ====================
//
// 三组能力：二次验证（TOTP）· 邮箱自助找回密码 · 登录设备管理。
// 全部为**新增**端点 ⇒ 未开启/未使用时，既有登录流程与 wire 形状一字不改。

// ---- 二次验证（TOTP，RFC 6238）----

// TotpSetupData 绑定第一步的返回值：密钥与 otpauth:// URL。
// ⚠️ 此时**尚未启用**（totp_enabled 仍为 false）——必须再调 /user/totp/enable
//   送一次有效验证码才算绑定成功（防止「扫了码但没验过」把自己锁在门外）。
struct TotpSetupData {
    1: required string secret      (api.body = "secret"),
    2: required string otpauth_url (api.body = "otpauth_url"),
}

struct TotpSetupResp {
    1: required i32           code    (api.body = "code"),
    2: required string        message (api.body = "message"),
    3: required TotpSetupData data    (api.body = "data"),
}

struct TotpEnableReq {
    1: required string code (api.body = "code"),
}

// TotpEnableData 恢复码**只在启用这一刻返回一次**（库内只存 bcrypt 哈希）。
struct TotpEnableData {
    1: required list<string> recovery_codes (api.body = "recovery_codes"),
}

struct TotpEnableResp {
    1: required i32            code    (api.body = "code"),
    2: required string         message (api.body = "message"),
    3: required TotpEnableData data    (api.body = "data"),
}

// TotpDisableReq 关闭 2FA 必须**双因子**：口令 + 当前 TOTP 码
// （防「令牌被盗后顺手把二验关掉」）。
struct TotpDisableReq {
    1: required string password (api.body = "password"),
    2: required string code     (api.body = "code"),
}

struct TotpDisableResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ---- 邮箱自助找回密码 ----
//
// ⚠️ forgot 恒返回成功（防账号枚举）；未配置 SMTP 时不发信，
//   前端按 capabilities.email_password_reset 隐藏入口。
struct PasswordForgotReq {
    1: required string email (api.body = "email"),
}

struct PasswordForgotResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

struct PasswordResetReq {
    1: required string token        (api.body = "token"),
    2: required string new_password (api.body = "new_password"),
}

struct PasswordResetResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ---- 登录设备管理 ----

struct UserSessionItem {
    1: required i64    id           (api.body = "id"),
    2: required string ip           (api.body = "ip"),
    3: required string user_agent   (api.body = "user_agent"),
    4: required string created_at   (api.body = "created_at"),
    5: required string last_seen_at (api.body = "last_seen_at"),
    // current = 本次请求所用的会话（前端据此禁掉「踢掉自己」的按钮）
    6: required bool   current      (api.body = "current"),
}

struct UserSessionsData {
    1: required list<UserSessionItem> sessions (api.body = "sessions"),
}

struct UserSessionsResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: required UserSessionsData data   (api.body = "data"),
}

struct RevokeSessionReq {
    1: required i64 id (api.path = "id"),
}

struct RevokeSessionResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

struct RevokeAllSessionsResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 服务定义 ====================

service UserService {
    // Register 用户注册
    RegisterResp Register(1: RegisterReq req) (api.post = "/user/register")

    // Login 用户登录
    LoginResp Login(1: LoginReq req) (api.post = "/user/login")

    // UserInfo 获取用户信息
    UserInfoResp UserInfo(1: UserInfoReq req) (api.get = "/user/info")

    // UpdateProfile 更新用户资料
    UpdateProfileResp UpdateProfile(1: UpdateProfileReq req) (api.put = "/user/profile")

    // ChangePassword 修改密码
    ChangePasswordResp ChangePassword(1: ChangePasswordReq req) (api.post = "/user/change-password")

    // UserStats 用户统计信息
    UserStatsResp UserStats(1: UserStatsReq req) (api.get = "/user/stats")

    // UserFiles 获取用户文件列表
    UserFilesResp UserFiles(1: UserFilesReq req) (api.get = "/user/files")

    // ListAPIKeys 获取 API Key 列表
    APIKeyListResp ListAPIKeys(1: EmptyReq req) (api.get = "/user/api-keys")

    // CreateAPIKey 创建 API Key
    CreateAPIKeyResp CreateAPIKey(1: CreateAPIKeyReq req) (api.post = "/user/api-keys")

    // DeleteAPIKey 删除 API Key
    DeleteAPIKeyResp DeleteAPIKey(1: DeleteAPIKeyReq req) (api.delete = "/user/api-keys/:id")

    // ==================== 自 customHandler 收敛进 IDL（2026-10-26） ====================





    // ==================== 账号与信任（5.2.0） ====================

    // TotpSetup 二次验证绑定第一步：生成密钥（尚未启用）
    TotpSetupResp TotpSetup(1: EmptyReq req) (api.post = "/user/totp/setup")

    // TotpEnable 二次验证绑定第二步：校验一次有效码后启用，并一次性返回恢复码
    TotpEnableResp TotpEnable(1: TotpEnableReq req) (api.post = "/user/totp/enable")

    // TotpDisable 关闭二次验证（口令 + 当前 TOTP 码双因子）
    TotpDisableResp TotpDisable(1: TotpDisableReq req) (api.post = "/user/totp/disable")

    // ForgotPassword 申请找回密码（恒成功，防账号枚举）
    PasswordForgotResp ForgotPassword(1: PasswordForgotReq req) (api.post = "/user/password/forgot")

    // ResetPassword 用一次性 token 重置密码
    PasswordResetResp ResetPassword(1: PasswordResetReq req) (api.post = "/user/password/reset")

    // UserSessions 当前账号的登录设备列表
    UserSessionsResp UserSessions(1: EmptyReq req) (api.get = "/user/sessions")

    // RevokeSession 踢掉指定设备
    RevokeSessionResp RevokeSession(1: RevokeSessionReq req) (api.delete = "/user/sessions/:id")

    // RevokeAllSessions 退出所有设备（API Key 不受影响）
    RevokeAllSessionsResp RevokeAllSessions(1: EmptyReq req) (api.post = "/user/sessions/revoke-all")

}
