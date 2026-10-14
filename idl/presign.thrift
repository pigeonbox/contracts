// =====================================================================
// presign.thrift — 预签名上传
// =====================================================================
// 客户端直传对象存储，减轻服务器压力
// 流程: init → 客户端 PUT 直传 → complete 通知服务
// =====================================================================

namespace go presign

// ==================== Init 申请预签名 URL ====================

struct InitReq {
    1: required string file_name    (api.body = "file_name"),
    2: required i64    file_size    (api.body = "file_size"),
    3: required string content_type (api.body = "content_type"),
    4: optional string scheme       (api.body = "scheme"),  // s3/oss/cos 等，留空用默认
    5: optional i32    expire_value  (api.body = "expire_value"),
    6: optional string expire_style  (api.body = "expire_style"),
    7: optional bool   require_auth  (api.body = "require_auth"),
    // 客户端预计算 SHA-256(秒传指纹,超限可空);此前靠 handler 二次解析 body
    8: optional string file_hash    (api.body = "file_hash"),
    // require_auth 时必填(bcrypt 后随 meta 存储);此前靠 handler 二次解析 body/form
    9: optional string password     (api.body = "password"),
    // 匿名取件码直传绑定(2026-10-07):传 /anonymous/generate 返回的 6 位码后,
    // 本会话 Complete 不再新建分享,而是把对象回填到该占位记录——修复"generate
    // 只建占位、无回填端点"的死码链路。有效期/密码以占位记录为准(init 时的
    // expire_value/require_auth 等字段被忽略)
    10: optional string pickup_code (api.body = "pickup_code"),
    // 文件备注(可空,随分享展示给取件人;2026-10-12 #489)
    11: optional string note        (api.body = "note"),
}

struct InitData {
    1: required string upload_id    (api.body = "upload_id"),
    2: required string upload_url   (api.body = "upload_url"),
    3: required string method       (api.body = "method"),     // PUT
    4: required map<string,string> headers (api.body = "headers"), // 需要附加的 header
    5: required i32    expire_seconds (api.body = "expire_seconds"),
    6: required string object_key   (api.body = "object_key"),
    7: required string scheme       (api.body = "scheme"),
    8: required string token        (api.body = "token"),    // 校验令牌
    // ---- 秒传命中时有效(此前响应走 ad-hoc map;未命中时为缺省) ----
    9:  optional bool   is_quick    (api.body = "is_quick"),   // 秒传命中,免直传
    10: optional bool   existed     (api.body = "existed"),    // 同哈希分享已存在
    11: optional string share_code  (api.body = "share_code"),
    12: optional string share_url   (api.body = "share_url"),
    // 注:不再签发 download_token——2026-10-03 安全修复,持同哈希者可借令牌
    // 跳过原分享密码校验(穿透),勿再加回
}

struct InitResp {
    1: required i32      code    (api.body = "code"),
    2: required string   message (api.body = "message"),
    3: required InitData data    (api.body = "data"),
}

// ==================== Complete 上传完成通知 ====================

struct CompleteReq {
    1: required string upload_id   (api.body = "upload_id"),
    2: required string token       (api.body = "token"),
    3: optional string object_key  (api.body = "object_key"),
    4: optional string file_hash   (api.body = "file_hash"),
}

struct CompleteData {
    1: required string code         (api.body = "code"),         // share code
    2: required string url          (api.body = "url"),          // 分享 URL
    3: required string file_name    (api.body = "file_name"),
    4: required i64    file_size    (api.body = "file_size"),
    5: required string download_url (api.body = "download_url"),
    // 6 位取件码（语义同 ShareData.pickup_code：文本/文件/永久分享同权铸造）
    6: optional string pickup_code  (api.body = "pickup_code"),
}

struct CompleteResp {
    1: required i32          code    (api.body = "code"),
    2: required string       message (api.body = "message"),
    3: required CompleteData data    (api.body = "data"),
}

// ==================== Abort 取消 ====================

struct AbortReq {
    1: required string upload_id (api.body = "upload_id"),
    2: required string token     (api.body = "token"),
}

struct AbortResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 服务定义 ====================

service PresignService {
    // Init 申请预签名上传 URL
    InitResp Init(1: InitReq req) (api.post = "/api/v1/presign/upload")

    // Complete 上传完成后通知服务写 share 表
    CompleteResp Complete(1: CompleteReq req) (api.post = "/api/v1/presign/complete")

    // Abort 取消预签名上传
    AbortResp Abort(1: AbortReq req) (api.post = "/api/v1/presign/abort")
}
