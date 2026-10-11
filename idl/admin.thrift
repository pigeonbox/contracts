// =====================================================================
// admin.thrift — 管理员模块
// =====================================================================
// 迁移自: idl/admin.proto
// =====================================================================

namespace go admin

// ==================== 管理员登录 ====================

struct AdminLoginReq {
    1: required string username (api.body = "username"),
    2: required string password (api.body = "password"),
}

struct AdminLoginData {
    1: required string token      (api.body = "token"),
    2: required string token_type (api.body = "token_type"),
    3: required i64    expires_in (api.body = "expires_in"),
}

struct AdminLoginResp {
    1: required i32            code    (api.body = "code"),
    2: required string         message (api.body = "message"),
    3: required AdminLoginData data    (api.body = "data"),
}

// ==================== 系统统计 ====================

struct AdminStatsReq {
}

struct AdminStatsData {
    1: required i64 total_files      (api.body = "total_files"),
    2: required i64 total_users      (api.body = "total_users"),
    3: required i64 total_size       (api.body = "total_size"),
    4: required i64 today_uploads    (api.body = "today_uploads"),
    5: required i64 today_downloads  (api.body = "today_downloads"),
    // 文件健康洞察维度（2026-10-07 对标上游 dashboard；全部为存活记录口径）
    6: required i64 active_files        (api.body = "active_files"),         // 可取件（未过期）
    7: required i64 expired_files       (api.body = "expired_files"),        // 已过期（时间或次数耗尽）
    8: required i64 expiring_soon_files (api.body = "expiring_soon_files"),  // 24h 内即将过期
    9: required i64 never_picked_files  (api.body = "never_picked_files"),   // 创建后从未被取件
    10: required i64 forever_files      (api.body = "forever_files"),         // 永久有效
}

struct AdminStatsResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: required AdminStatsData  data    (api.body = "data"),
}

// ==================== 文件管理 ====================

struct AdminListFilesReq {
    1: required i32    page       (api.query = "page"),
    2: required i32    page_size  (api.query = "page_size"),
    3: optional string keyword    (api.query = "keyword"),
    4: optional string sort_by    (api.query = "sort_by"),
    // 健康洞察过滤（2026-10-07）：active/expired/expiring_soon/never_picked/forever
    5: optional string health     (api.query = "health"),
}

struct FileItem {
    1: required i64    id             (api.body = "id"),
    2: required string code           (api.body = "code"),
    3: required string file_name      (api.body = "file_name"),
    4: required i64    file_size      (api.body = "file_size"),
    5: required string expire_time    (api.body = "expire_time"),
    6: required i32    view_count     (api.body = "view_count"),
    7: required i32    download_count (api.body = "download_count"),
    8: required string created_at     (api.body = "created_at"),
}

struct AdminFileList {
    1: required list<FileItem> items     (api.body = "items"),
    2: required i64            total     (api.body = "total"),
    3: required i32            page      (api.body = "page"),
    4: required i32            page_size (api.body = "page_size"),
}

struct AdminListFilesResp {
    1: required i32            code    (api.body = "code"),
    2: required string         message (api.body = "message"),
    3: required AdminFileList  data    (api.body = "data"),
}

// ==================== 删除文件 ====================

struct AdminDeleteFileReq {
    1: required i64 id (api.path = "id"),
}

struct AdminDeleteFileResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 用户管理 ====================

struct AdminListUsersReq {
    1: required i32    page       (api.query = "page"),
    2: required i32    page_size  (api.query = "page_size"),
    3: optional string keyword    (api.query = "keyword"),
    4: optional i32    status     (api.query = "status"),
}

struct UserItem {
    1: required i64    id          (api.body = "id"),
    2: required string username    (api.body = "username"),
    3: required string email       (api.body = "email"),
    4: required string nickname    (api.body = "nickname"),
    5: required i32    status      (api.body = "status"),
    6: required i64    quota_used  (api.body = "quota_used"),
    7: required i64    quota_limit (api.body = "quota_limit"),
    8: required string created_at  (api.body = "created_at"),
}

struct AdminUserList {
    1: required list<UserItem> items     (api.body = "items"),
    2: required i64            total     (api.body = "total"),
    3: required i32            page      (api.body = "page"),
    4: required i32            page_size (api.body = "page_size"),
}

struct AdminListUsersResp {
    1: required i32           code    (api.body = "code"),
    2: required string        message (api.body = "message"),
    3: required AdminUserList data    (api.body = "data"),
}

// ==================== 更新用户状态 ====================

struct AdminUpdateUserStatusReq {
    1: required i64 id     (api.path = "id"),
    2: required i32 status (api.body = "status"),
}

struct AdminUpdateUserStatusResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 系统配置 ====================
// 契约形态(2026-10-06 定):配置体 = 领域 SystemConfig(app/admin/service.go)
// 的扁平 JSON。配置段随功能版本演进(指针段 nil-overlay、未设段回退 yaml,
// 服务端整体校验),契约层刻意不锁形——自由格式对象,OpenAPI 视角为空
// schema,语义以本注释为准。新增配置段无需改本文件。

struct AdminGetConfigReq {
}

// data = SystemConfig 全量 JSON(base/storage/transfer/user/ui/upload_ex/
// download/notify/local_import/oidc/api_token/runtime_storage 等段;
// omitempty 指针段未在线设置时不下发)。前端按段读取,未知段忽略。
struct AdminConfigData {
}

struct AdminGetConfigResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: required AdminConfigData data    (api.body = "data"),
}

// body = SystemConfig 局部 JSON。段保留语义分两类:
//   - 指针段(user/ui/upload_ex/download/notify/local_import/oidc/api_token/
//     runtime_storage):body 未携带 = 保留现状(nil-overlay);
//   - 值段(base/storage/transfer):结构整体覆盖,body 缺省按零值落库——
//     客户端保存时必须整段携带(前端 Config 页基础页签即整段提交)。
// 注意:勿包 {config:...} 壳——曾因包壳导致新段写入被静默丢弃(假开关,
// v0.13.5 修复;旧三段 typed 契约同时退役)。
struct AdminUpdateConfigReq {
}

struct AdminUpdateConfigResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 管理端增强（2026-10-10 IDL 化收编） ====================
// 迁移注记：20 个管理端 handler（用户 CRUD / 文件管理 / 富统计 / 传输日志 /
// 分享治理）由 customHandler 手写路由（transport/http/handler/admin_manage.go）
// 迁入本契约 + gen 层。信封沿用 pkg/resp 助手（成功 code=0/"success"+trace_id，
// 错误=业务码），与迁移前逐字段保形；仅 /admin/files/filter 与 /admin/logs/transfer
// 走 legacy 信封（code=200 + data{items,total,page,page_size}），其 item 字段为
// 手工小写 snake_case，逐字段保形。本结构仅作契约/文档（wire 由 gen handler 的
// resp 助手产出），复杂领域对象（UserResp/UserSettings/EnhancedStats 等）以空
// 结构占位、语义见注释（同 AdminConfigData 先例）。

// ---- 通用操作结果数据 ----
struct AdminAffectedData { 1: required i64 affected  (api.body = "affected") }
struct AdminDeletedData  { 1: required i64 deleted   (api.body = "deleted") }
struct AdminRestoredData { 1: required i64 restored  (api.body = "restored") }
struct AdminPurgedData   { 1: required i64 purged    (api.body = "purged") }
struct AdminExtendedData { 1: required i64 extended  (api.body = "extended") }

// data = model.UserResp 全量 JSON（用户 CRUD 读写回显）
struct AdminManageUserData {}
// data = adminapp.UserSettings JSON（注册开关/配额默认/会话时长）
struct AdminUserSettingsData {}
// data = app/admin.EnhancedStats JSON（昨日对比/下载总量/top 后缀/类型分布/存储用量）
struct AdminEnhancedStatsData {}
// data.days 项 = app/admin.TrendDay（日期 + uploads/downloads 计数，缺失日补 0）
struct AdminTrendDayData {}
// data.share = model.FileCode 全量 JSON
struct AdminShareDetailData {}

// ---- 用户管理（CRUD 补齐） ----
struct AdminCreateUserReq {
    1: required string username         (api.body = "username"),
    2: optional string email            (api.body = "email"),
    3: required string password         (api.body = "password"),
    4: optional string nickname         (api.body = "nickname"),
    5: optional string role             (api.body = "role"),             // admin/user
    6: optional i64    max_storage_quota (api.body = "max_storage_quota"),
}
struct AdminCreateUserResp {
    1: required i32                 code    (api.body = "code"),
    2: required string              message (api.body = "message"),
    3: optional AdminManageUserData data    (api.body = "data"),
}

struct AdminUpdateUserReq {
    1: required i64    id               (api.path = "id"),
    2: optional string nickname         (api.body = "nickname"),
    3: optional string role             (api.body = "role"),             // admin/user
    4: optional string status           (api.body = "status"),           // active/inactive/banned
    5: optional i64    max_storage_quota (api.body = "max_storage_quota"),
    6: optional i64    max_upload_size  (api.body = "max_upload_size"),
}
struct AdminUpdateUserResp {
    1: required i32                 code    (api.body = "code"),
    2: required string              message (api.body = "message"),
    3: optional AdminManageUserData data    (api.body = "data"),
}

struct AdminUserIdReq {
    1: required i64 id (api.path = "id"),
}
struct AdminDeleteUserResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

struct AdminResetUserPasswordReq {
    1: required i64    id       (api.path = "id"),
    2: required string password (api.body = "password"),   // ≥6 位
}
struct AdminResetUserPasswordResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

struct AdminListUsersFilteredReq {
    1: optional string keyword   (api.query = "keyword"),
    2: optional string status    (api.query = "status"),
    3: optional string role      (api.query = "role"),
    4: optional i32    page      (api.query = "page"),
    5: optional i32    page_size (api.query = "page_size"),
}
struct AdminUserListPage {
    1: required list<AdminManageUserData> list      (api.body = "list"),
    2: required i64                       total     (api.body = "total"),
    3: required i32                       page      (api.body = "page"),
    4: required i32                       page_size (api.body = "page_size"),
}
struct AdminListUsersFilteredResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: optional AdminUserListPage data   (api.body = "data"),
}

// ---- 文件管理（详情/编辑/批量/下载） ----
struct AdminFileDetailFileItem {
    1: required i64    id   (api.body = "id"),
    2: required string name (api.body = "name"),
    3: required i64    size (api.body = "size"),
    4: required string hash (api.body = "hash"),
}
struct AdminFileDetailData {
    1: required AdminShareDetailData         share      (api.body = "share"),
    2: required list<AdminFileDetailFileItem> files      (api.body = "files"),
    3: required i64                          file_count (api.body = "file_count"),
}
struct AdminFileDetailResp {
    1: required i32                code    (api.body = "code"),
    2: required string             message (api.body = "message"),
    3: optional AdminFileDetailData data   (api.body = "data"),
}

// body = adminapp.UserSettings JSON（注册开关/配额默认/会话时长），写穿 DB 即时生效
struct AdminGetUserSettingsReq {}
struct AdminGetUserSettingsResp {
    1: required i32                   code    (api.body = "code"),
    2: required string                message (api.body = "message"),
    3: optional AdminUserSettingsData data    (api.body = "data"),
}

struct AdminUpdateUserSettingsReq {}
struct AdminUpdateUserSettingsResp {
    1: required i32               code    (api.body = "code"),
    2: required string            message (api.body = "message"),
    3: optional AdminAffectedData data    (api.body = "data"),
}

struct AdminUpdateFileReq {
    1: required i64    id            (api.path = "id"),
    2: optional i32    expire_value  (api.body = "expire_value"),
    3: optional string expire_style  (api.body = "expire_style"),
    4: optional i32    expired_count (api.body = "expired_count"),
}
struct AdminUpdateFileResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

struct AdminFileIdsReq {
    1: required list<i64> ids (api.body = "ids"),
}
struct AdminBatchDeleteFilesResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: optional AdminDeletedData data   (api.body = "data"),
}
struct AdminRestoreFilesResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: optional AdminRestoredData data   (api.body = "data"),
}
struct AdminPurgeFilesResp {
    1: required i32            code    (api.body = "code"),
    2: required string         message (api.body = "message"),
    3: optional AdminPurgedData data   (api.body = "data"),
}

struct AdminBatchExtendFilesReq {
    1: required list<i64> ids          (api.body = "ids"),
    2: required i32      expire_value  (api.body = "expire_value"),
    3: required string   expire_style  (api.body = "expire_style"),
}
struct AdminBatchExtendFilesResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: optional AdminExtendedData data   (api.body = "data"),
}

// 管理端下载：302 到公开下载端点（附服务端签发下载令牌），Resp 空
struct AdminDownloadFileReq {
    1: required i64 id (api.path = "id"),
}
struct AdminDownloadFileResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ---- Dashboard 富统计 ----
struct AdminEnhancedStatsReq {}
struct AdminEnhancedStatsResp {
    1: required i32                   code    (api.body = "code"),
    2: required string                message (api.body = "message"),
    3: optional AdminEnhancedStatsData data   (api.body = "data"),
}

struct AdminStatsTrendReq {
    1: optional i32 days (api.query = "days"),   // 1..30，缺省 7
}
struct AdminStatsTrendData {
    1: required list<AdminTrendDayData> days (api.body = "days"),
}
struct AdminStatsTrendResp {
    1: required i32               code    (api.body = "code"),
    2: required string            message (api.body = "message"),
    3: optional AdminStatsTrendData data   (api.body = "data"),
}

// ---- 传输日志（legacy 信封：code=200 + data{items,total,page,page_size}） ----
// item 字段为手工小写 snake_case（gorm.Model 默认序列化为大写，此处显式映射）。
struct TransferLogItem {
    1: required i64    id          (api.body = "id"),
    2: required string operation   (api.body = "operation"),
    3: required string file_code   (api.body = "file_code"),
    4: required string file_name   (api.body = "file_name"),
    5: required i64    file_size   (api.body = "file_size"),
    6: required string username    (api.body = "username"),
    7: required string ip          (api.body = "ip"),
    8: required i64    duration_ms (api.body = "duration_ms"),
    9: required string created_at  (api.body = "created_at"),
}
struct AdminTransferLogPage {
    1: required list<TransferLogItem> items     (api.body = "items"),
    2: required i64                   total     (api.body = "total"),
    3: required i32                   page      (api.body = "page"),
    4: required i32                   page_size (api.body = "page_size"),
}
struct AdminTransferLogsReq {
    1: optional i32    page      (api.query = "page"),
    2: optional i32    page_size (api.query = "page_size"),
    3: optional string operation (api.query = "operation"),
    4: optional string keyword   (api.query = "keyword"),
}
struct AdminTransferLogsResp {
    1: required i32                 code    (api.body = "code"),
    2: required string              message (api.body = "message"),
    3: required AdminTransferLogPage data   (api.body = "data"),
}

// ---- 分享治理（legacy 信封：code=200 + data{items,total,page,page_size}） ----
// item 字段为手工小写 snake_case（含管控字段；owner_ip 仅管理端可见）。
struct FileGovernanceItem {
    1: required i64    id            (api.body = "id"),
    2: required string code          (api.body = "code"),
    3: required string file_name     (api.body = "file_name"),
    4: required bool   is_text       (api.body = "is_text"),
    5: required string text_preview  (api.body = "text_preview"),
    6: required i64    size          (api.body = "size"),
    7: optional string expired_at    (api.body = "expired_at"),
    8: required i32    expired_count (api.body = "expired_count"),
    9: required i32    used_count    (api.body = "used_count"),
    10: required i32   viewer_count  (api.body = "viewer_count"),
    11: required string status       (api.body = "status"),
    12: required string upload_type  (api.body = "upload_type"),
    13: optional i64   user_id       (api.body = "user_id"),
    14: required string owner_ip     (api.body = "owner_ip"),
    15: required bool  require_auth  (api.body = "require_auth"),
    16: required string created_at   (api.body = "created_at"),
    17: required bool  deleted       (api.body = "deleted"),
    18: required i64   file_count    (api.body = "file_count"),
}
struct AdminFileGovernancePage {
    1: required list<FileGovernanceItem> items     (api.body = "items"),
    2: required i64                      total     (api.body = "total"),
    3: required i32                      page      (api.body = "page"),
    4: required i32                      page_size (api.body = "page_size"),
}
struct AdminListFilesFilteredReq {
    1: optional string keyword        (api.query = "keyword"),
    2: optional i64    user_id        (api.query = "user_id"),
    3: optional string upload_type    (api.query = "upload_type"),
    4: optional string owner_ip       (api.query = "owner_ip"),
    5: optional string status         (api.query = "status"),
    6: optional i64    min_size       (api.query = "min_size"),
    7: optional i64    max_size       (api.query = "max_size"),
    8: optional string created_after  (api.query = "created_after"),
    9: optional string created_before (api.query = "created_before"),
    10: optional string expired       (api.query = "expired"),
    11: optional string deleted       (api.query = "deleted"),
    12: optional string health        (api.query = "health"),
    13: optional i32   page           (api.query = "page"),
    14: optional i32   page_size      (api.query = "page_size"),
}
struct AdminListFilesFilteredResp {
    1: required i32                    code    (api.body = "code"),
    2: required string                 message (api.body = "message"),
    3: required AdminFileGovernancePage data   (api.body = "data"),
}

// ---- 分享治理状态机（单个/批量管控） ----
struct AdminSetFileStatusReq {
    1: required i64    id     (api.path = "id"),
    2: required string status (api.body = "status"),   // normal/blocked/pending_review
}
struct AdminSetFileStatusResp {
    1: required i32               code    (api.body = "code"),
    2: required string            message (api.body = "message"),
    3: optional AdminAffectedData data    (api.body = "data"),
}

struct AdminBatchSetFilesStatusReq {
    1: required list<i64> ids    (api.body = "ids"),
    2: required string   status  (api.body = "status"),   // normal/blocked/pending_review
}
struct AdminBatchSetFilesStatusResp {
    1: required i32               code    (api.body = "code"),
    2: required string            message (api.body = "message"),
    3: optional AdminAffectedData data    (api.body = "data"),
}

// ---- 本地文件管理（对标上游 data/local 管理；root=服务端白名单索引，杜绝穿越） ----
struct LocalFileEntry {
    1: required string name    (api.body = "name"),
    2: required string path    (api.body = "path"),      // 相对 root 的路径，正斜杠
    3: required i64    size    (api.body = "size"),
    4: required string mod_time (api.body = "mod_time"),  // RFC3339
    5: required bool   is_dir  (api.body = "is_dir"),
}
struct AdminListLocalFilesReq {
    1: optional i32    root (api.query = "root"),
    2: optional string dir  (api.query = "dir"),
}
struct AdminListLocalFilesData {
    1: required list<string>         roots   (api.body = "roots"),    // 白名单根目录（前端切换用）
    2: required list<LocalFileEntry> entries (api.body = "entries"),
}
struct AdminListLocalFilesResp {
    1: required i32                     code    (api.body = "code"),
    2: required string                  message (api.body = "message"),
    3: required AdminListLocalFilesData data    (api.body = "data"),
}
struct AdminDeleteLocalFileReq {
    1: optional i32    root (api.query = "root"),
    2: required string path (api.query = "path"),
}
// data 恒 null（SuccessWithMessage nil）：契约不再携带 data 键（增量无害）
struct AdminDeleteLocalFileResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}
struct AdminImportLocalFileReq {
    1: required i32    root         (api.body = "root"),
    2: required string path         (api.body = "path"),
    3: optional i32    expire_value (api.body = "expire_value"),
    4: optional string expire_style (api.body = "expire_style"),
    5: optional bool   require_auth (api.body = "require_auth"),
    6: optional string password     (api.body = "password"),
    7: optional string custom_code  (api.body = "custom_code"),
}
struct AdminImportLocalFileData {
    1: required string code      (api.body = "code"),       // 分享码（导入即分享）
    2: required string share_url (api.body = "share_url"),
}
struct AdminImportLocalFileResp {
    1: required i32                     code    (api.body = "code"),
    2: required string                  message (api.body = "message"),
    3: optional AdminImportLocalFileData data   (api.body = "data"),
}

// ---- 设置测试端点（测「当前生效值」，非草稿） ----
struct AdminTestSMTPReq {
    1: required string to (api.body = "to"),
}
struct AdminTestSMTPResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}
struct AdminTestOIDCReq {
}
struct AdminTestOIDCResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ---- 管理操作审计日志（gorm.Model 内嵌键已契约化为小写 snake_case，增量无害） ----
struct AdminActivityItem {
    1: required i64    id         (api.body = "id"),
    2: required string action     (api.body = "action"),
    3: required string target     (api.body = "target"),
    4: required bool   success    (api.body = "success"),
    5: required string message    (api.body = "message"),
    6: optional i64    actor_id   (api.body = "actor_id"),
    7: required string actor_name (api.body = "actor_name"),
    8: required string ip         (api.body = "ip"),
    9: required i64    latency_ms (api.body = "latency_ms"),
    10: required string created_at (api.body = "created_at"),
}
struct AdminActivitiesReq {
    1: optional i32    page      (api.query = "page"),
    2: optional i32    page_size (api.query = "page_size"),   // 上限 200
    3: optional string action    (api.query = "action"),
    4: optional string actor     (api.query = "actor"),
    5: optional string success   (api.query = "success"),     // true/false；缺省=全部
}
struct AdminActivitiesData {
    1: required list<AdminActivityItem> items     (api.body = "list"),
    2: required i64                     total     (api.body = "total"),
    3: required i32                     page      (api.body = "page"),
    4: required i32                     page_size (api.body = "page_size"),
}
struct AdminActivitiesResp {
    1: required i32                 code    (api.body = "code"),
    2: required string              message (api.body = "message"),
    3: required AdminActivitiesData data    (api.body = "data"),
}

// ==================== 服务定义 ====================

service AdminService {
    // AdminLogin 管理员登录
    AdminLoginResp AdminLogin(1: AdminLoginReq req) (api.post = "/admin/login")

    // AdminStats 系统统计
    AdminStatsResp AdminStats(1: AdminStatsReq req) (api.get = "/admin/stats")

    // AdminListFiles 文件列表
    AdminListFilesResp AdminListFiles(1: AdminListFilesReq req) (api.get = "/admin/files")

    // AdminDeleteFile 删除文件
    AdminDeleteFileResp AdminDeleteFile(1: AdminDeleteFileReq req) (api.delete = "/admin/files/:id")

    // AdminListUsers 用户列表
    AdminListUsersResp AdminListUsers(1: AdminListUsersReq req) (api.get = "/admin/users")

    // AdminUpdateUserStatus 更新用户状态
    AdminUpdateUserStatusResp AdminUpdateUserStatus(1: AdminUpdateUserStatusReq req) (api.put = "/admin/users/:id/status")

    // AdminGetConfig 获取系统配置
    AdminGetConfigResp AdminGetConfig(1: AdminGetConfigReq req) (api.get = "/admin/config")

    // AdminUpdateConfig 更新系统配置
    AdminUpdateConfigResp AdminUpdateConfig(1: AdminUpdateConfigReq req) (api.put = "/admin/config")

    // ===== 管理端增强（2026-10-10 IDL 化收编，原 admin_manage.go） =====

    // AdminCreateUser 创建用户
    AdminCreateUserResp AdminCreateUser(1: AdminCreateUserReq req) (api.post = "/admin/users")
    // AdminUpdateUser 更新用户（昵称/角色/状态/配额）
    AdminUpdateUserResp AdminUpdateUser(1: AdminUpdateUserReq req) (api.put = "/admin/users/:id")
    // AdminDeleteUser 删除用户（级联软删分享）
    AdminDeleteUserResp AdminDeleteUser(1: AdminUserIdReq req) (api.delete = "/admin/users/:id")
    // AdminResetUserPassword 管理员重置用户密码
    AdminResetUserPasswordResp AdminResetUserPassword(1: AdminResetUserPasswordReq req) (api.post = "/admin/users/:id/reset-password")
    // AdminListUsersFiltered 带筛选的用户列表
    AdminListUsersFilteredResp AdminListUsersFiltered(1: AdminListUsersFilteredReq req) (api.get = "/admin/users/filter")

    // AdminFileDetail 文件详情（含子文件列表）
    AdminFileDetailResp AdminFileDetail(1: AdminUserIdReq req) (api.get = "/admin/files/:id")
    // AdminUpdateFile 编辑文件（延期/改剩余次数）
    AdminUpdateFileResp AdminUpdateFile(1: AdminUpdateFileReq req) (api.put = "/admin/files/:id")
    // AdminBatchDeleteFiles 批量删除文件
    AdminBatchDeleteFilesResp AdminBatchDeleteFiles(1: AdminFileIdsReq req) (api.post = "/admin/files/batch-delete")
    // AdminRestoreFiles 从回收站恢复
    AdminRestoreFilesResp AdminRestoreFiles(1: AdminFileIdsReq req) (api.post = "/admin/files/restore")
    // AdminPurgeFiles 彻底删除（DB 硬删+存储对象删除）
    AdminPurgeFilesResp AdminPurgeFiles(1: AdminFileIdsReq req) (api.post = "/admin/files/purge")
    // AdminBatchExtendFiles 批量延期
    AdminBatchExtendFilesResp AdminBatchExtendFiles(1: AdminBatchExtendFilesReq req) (api.post = "/admin/files/batch-extend")
    // AdminDownloadFile 管理端下载（302 重定向到公开下载端点）
    AdminDownloadFileResp AdminDownloadFile(1: AdminDownloadFileReq req) (api.get = "/admin/files/:id/download")

    // AdminGetUserSettings 获取"用户配置"段（生效值）
    AdminGetUserSettingsResp AdminGetUserSettings(1: AdminGetUserSettingsReq req) (api.get = "/admin/config/user")
    // AdminUpdateUserSettings 在线更新"用户配置"段（写穿 DB 即时生效）
    AdminUpdateUserSettingsResp AdminUpdateUserSettings(1: AdminUpdateUserSettingsReq req) (api.put = "/admin/config/user")

    // AdminEnhancedStats 富指标（昨日对比/下载总量/top 后缀/类型分布/存储用量）
    AdminEnhancedStatsResp AdminEnhancedStats(1: AdminEnhancedStatsReq req) (api.get = "/admin/stats/enhanced")
    // AdminStatsTrend 趋势序列（连续 N 天，缺失日补 0）
    AdminStatsTrendResp AdminStatsTrend(1: AdminStatsTrendReq req) (api.get = "/admin/stats/trend")

    // AdminTransferLogs 传输日志分页（legacy 信封）
    AdminTransferLogsResp AdminTransferLogs(1: AdminTransferLogsReq req) (api.get = "/admin/logs/transfer")
    // AdminListFilesFiltered 管理端文件列表组合过滤（legacy 信封）
    AdminListFilesFilteredResp AdminListFilesFiltered(1: AdminListFilesFilteredReq req) (api.get = "/admin/files/filter")

    // AdminSetFileStatus 设置单个分享管控状态
    AdminSetFileStatusResp AdminSetFileStatus(1: AdminSetFileStatusReq req) (api.put = "/admin/files/:id/status")
    // AdminBatchSetFilesStatus 批量设置分享管控状态
    AdminBatchSetFilesStatusResp AdminBatchSetFilesStatus(1: AdminBatchSetFilesStatusReq req) (api.post = "/admin/files/batch-status")

    // AdminListLocalFiles 本地文件管理：白名单根目录+条目列表
    AdminListLocalFilesResp AdminListLocalFiles(1: AdminListLocalFilesReq req) (api.get = "/admin/local-files")
    // AdminDeleteLocalFile 删除白名单目录内文件
    AdminDeleteLocalFileResp AdminDeleteLocalFile(1: AdminDeleteLocalFileReq req) (api.delete = "/admin/local-files")
    // AdminImportLocalFile 把白名单目录内文件导入为分享（配额/审核同链路）
    AdminImportLocalFileResp AdminImportLocalFile(1: AdminImportLocalFileReq req) (api.post = "/admin/local-files/import")

    // AdminTestSMTP 用当前生效 SMTP 配置发送测试邮件
    AdminTestSMTPResp AdminTestSMTP(1: AdminTestSMTPReq req) (api.post = "/admin/notify/smtp/test")
    // AdminTestOIDC 验证当前生效 OIDC issuer discovery 可达
    AdminTestOIDCResp AdminTestOIDC(1: AdminTestOIDCReq req) (api.post = "/admin/oidc/test")

    // AdminActivities 管理操作审计日志分页
    AdminActivitiesResp AdminActivities(1: AdminActivitiesReq req) (api.get = "/admin/activities")
}
