// =====================================================================
// setup.thrift — 系统初始化
// =====================================================================
// 迁移自: idl/setup.proto
// =====================================================================

namespace go setup

// ==================== 系统初始化检查 ====================

struct CheckInitializationReq {
}

struct CheckInitializationResp {
    1: required bool   initialized (api.body = "initialized"),
    2: required string message    (api.body = "message"),
}

// ==================== 系统初始化 ====================

struct BaseConfig {
    1: required string name        (api.body = "name"),
    2: required string description (api.body = "description"),
    3: required i32    port        (api.body = "port"),
    4: required string host        (api.body = "host"),
}

struct InitializeReq {
    1: required string     admin_username (api.body = "admin_username"),
    2: required string     admin_password (api.body = "admin_password"),
    3: required string     admin_email    (api.body = "admin_email"),
    4: optional BaseConfig base_config   (api.body = "base_config"),
    // 站点预配置（2026-10-07 对标上游首启向导：管理员+站点策略一页配完；
    // 不传 = 跳过预配置，走 yaml 默认）
    5: optional SitePreConfig site_config (api.body = "site_config"),
}

// SitePreConfig 首启向导的站点策略段（写入 SystemConfig 对应段并热应用）。
// 只收当前可热应用的键：站点名/描述走 BaseConfig，此处为上传与游客策略。
// 2026-10-12 扩容政策段（对标上游首启向导全量）：过期策略/文件白名单/注册开关，
// 全部可选——不传 = 保持 yaml/内置默认，旧客户端零破坏。
struct SitePreConfig {
    1: required i32  upload_size_mb (api.body = "upload_size_mb"),  // 单文件上限（MB，>0 生效）
    2: required bool open_upload    (api.body = "open_upload"),     // 允许游客上传
    3: optional list<string> allowed_expire_styles (api.body = "allowed_expire_styles"), // 允许的过期样式（minute/hour/day/week/month/year/forever/count 子集；空=全部）
    4: optional i32  max_save_days  (api.body = "max_save_days"),   // 最长保存天数上限（0=不限）
    5: optional list<string> allowed_extensions    (api.body = "allowed_extensions"),    // 扩展名白名单（如 .jpg/.png/.pdf；空=黑名单模式）
    6: optional bool allow_registration (api.body = "allow_registration"), // 开放用户注册
}

struct InitializeResp {
    1: required string message  (api.body = "message"),
    2: required string username (api.body = "username"),
}

// ==================== 服务定义 ====================

service SetupService {
    // CheckInitialization 检查系统是否已初始化
    CheckInitializationResp CheckInitialization(1: CheckInitializationReq req) (api.get = "/setup/check")

    // Initialize 初始化系统
    InitializeResp Initialize(1: InitializeReq req) (api.post = "/setup")
}
