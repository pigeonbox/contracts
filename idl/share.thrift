// =====================================================================
// share.thrift — 分享
// =====================================================================
// 迁移自: idl/share.proto
// =====================================================================

namespace go share

// ==================== 分享文本 ====================

struct ShareTextReq {
    1: required string text          (api.body = "text"),
    2: required i32    expire_value  (api.body = "expire_value"),
    3: required string expire_style  (api.body = "expire_style"),  // minute, hour, day, week, month, year, forever, count(count=按取件次数)
    4: required bool   require_auth  (api.body = "require_auth"),
    // 密码保护:require_auth 时必填(前端 multipart form 发送;此前 handler DefaultPostForm 直读)
    5: optional string password      (api.body = "password"),
    // 自定义取件码(P3):仅登录用户可指定(防匿名抢注)
    6: optional string custom_code   (api.body = "custom_code"),
    // E2E 密文分享:true 时文本跳过 HTML 转义(转义会破坏解密)
    7: optional bool   encrypted     (api.body = "encrypted"),
}

struct ShareData {
    1: required string code (api.body = "code"),
    2: required string url  (api.body = "url"),
    // 6 位取件码（2026-10-08 起文本/文件/永久分享同权铸造：pickup_code → code 映射，
    // 真相源落 DB file_codes.pickup_code，有 TTL 时另写 KV 加速；E2E 密文分享跳过为空）
    3: optional string pickup_code (api.body = "pickup_code"),
    // 秒传去重命中（2026-10-12，D1=A 同用户内）：本次未写入新存储对象，
    // 分享引用调用者自己历史同 hash+size 文件的既有对象
    4: optional bool deduped (api.body = "deduped"),
}

struct ShareTextResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required ShareData data    (api.body = "data"),
}

// ==================== 分享文件 ====================

struct ShareFileReq {
    // 文件通过 multipart/form-data 上传
    1: required i32    expire_value (api.form = "expire_value"),
    2: required string expire_style (api.form = "expire_style"),
    3: required bool   require_auth (api.form = "require_auth"),
    // 密码保护:require_auth 时必填
    4: optional string password     (api.form = "password"),
    // 文件备注(可空):随分享展示给取件人,文件+文本一并投递(2026-10-12 #489)
    5: optional string note         (api.form = "note"),
}

struct ShareFileResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required ShareData data    (api.body = "data"),
}

// ==================== 获取分享 ====================

struct GetShareReq {
    1: required string code     (api.path = "code"),
    // 取件密码经请求头传递（2026-10-16 拍板「一步到位」）：query 形态有访问日志/
    // 浏览器历史/Referer 泄漏面，与 /share/download 停收 ?password= 同批收敛
    2: optional string password (api.header = "X-Share-Password"),
}

struct ShareDetail {
    1: required string code         (api.body = "code"),
    2: required string text         (api.body = "text"),
    3: required string file_name    (api.body = "file_name"),
    4: required string file_size    (api.body = "file_size"),   // 后端格式化前的字节数字符串
    5: required string url          (api.body = "url"),
    6: required bool   has_password (api.body = "has_password"),
    7: required string expire_time  (api.body = "expire_time"),
    // ---- 以下为此前 handler ad-hoc map 附加字段(v0.6.0 入契约) ----
    8:  optional string download_url (api.body = "download_url"), // 带下载令牌的取件链接(security.download_token.enabled 时必须携带)
    9:  optional string token        (api.body = "token"),        // 下载令牌(功能关闭时不下发)
    10: optional bool   encrypted    (api.body = "encrypted"),    // E2E 密文,前端以链接 #fragment 密钥解密
    11: optional bool   is_multi     (api.body = "is_multi"),     // 多文件分享(前端显示"打包下载")
    12: optional list<ShareFileItem> files (api.body = "files"),  // 文件清单(含单文件,前端统一渲染)
    13: optional string note         (api.body = "note"),         // 文件备注(可空,取件页展示)
}

// 多文件清单项
struct ShareFileItem {
    1: required i64    id   (api.body = "id"),
    2: required string name (api.body = "name"),
    3: required i64    size (api.body = "size"),
}

struct GetShareResp {
    1: required i32         code    (api.body = "code"),
    2: required string      message (api.body = "message"),
    3: required ShareDetail data    (api.body = "data"),
}

// ==================== 下载分享 ====================

struct DownloadFileReq {
    1: required string code (api.query = "code"),
    // 不再有 password 字段（2026-10-16 拍板「一步到位」，随 core v0.24.0 落地）：
    // 密码保护分享一律走取件流程（retrieve/getShare 以 POST body 或
    // X-Share-Password 头校验密码后签发时间窗令牌）换凭证下载，下载端点只认
    // code + token。IDL 此前仍宣称 ?password= query 通道，与实现背离——生成物
    // （openapi/TS 类型）会把它当契约传播给第三方集成方，诱导其继续发送已废
    // 通道。故此处删除该字段（2 号位留空不复用）。
}

struct DownloadFileResp {
    // 文件下载使用流式响应，此消息用于 JSON 错误响应
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 用户分享管理（/api/v1/user/shares） ====================
// 2026-10-09 IDL 化：此前为 customHandler 手写契约（Go UserShareListItem + 前端
// 手抄 UserShareItem 双维护，pickup_code 类字段变更被迫两端手工同步），收敛回
// IDL 真相源。字段与历史 JSON 逐一对外兼容（前端零改动）。

struct UserSharesListReq {
    1: optional string status    (api.query = "status"),    // all/active/expired/text/file/deleted
    2: optional string search    (api.query = "search"),    // 分享码/取件码/文件名模糊
    3: optional i32    page      (api.query = "page"),
    4: optional i32    page_size (api.query = "page_size"),
}

// prefix/suffix 已退役（2026-10-26）：旧直传布局的「原始名拆分」死列，
// 全库恒空且无写入方；文件名统一走 file_name。
struct UserShareItemData {
    1: required i64     id            (api.body = "id"),
    2: required string  code          (api.body = "code"),
    // 6 位取件码（落库持久化；空 = 未铸造：E2E/历史数据）
    3: optional string  pickup_code   (api.body = "pickup_code"),
    4: required string  file_name     (api.body = "file_name"),
    5: required string  file_path     (api.body = "file_path"),
    6: required i64     size          (api.body = "size"),
    7: required string  text          (api.body = "text"),
    8: optional string expired_at    (api.body = "expired_at"),     // RFC3339Nano
    9: required i32    expired_count (api.body = "expired_count"),  // -1=无限, 0=耗尽, >0=剩余
    10: required i32    used_count    (api.body = "used_count"),
    11: required bool   require_auth  (api.body = "require_auth"),
    12: required string upload_type   (api.body = "upload_type"),
    13: required string created_at    (api.body = "created_at"),     // RFC3339Nano
    14: required string updated_at    (api.body = "updated_at"),
    15: optional string deleted_at    (api.body = "deleted_at"),     // 回收站
    16: required string  viewer_ip     (api.body = "viewer_ip"),
    17: optional string viewer_at     (api.body = "viewer_at"),
    18: required i32    viewer_count  (api.body = "viewer_count"),
    19: required bool   is_expired    (api.body = "is_expired"),
    20: required bool   is_text_share (api.body = "is_text_share"),
    21: required string  status        (api.body = "status"),         // normal/blocked/pending_review
    22: required i32    file_count    (api.body = "file_count"),     // P0 多文件：子文件数
    23: optional string note          (api.body = "note"),           // 文件备注（可空）
    // 逐条取件明细（2026-10-24 新增）：一次取件 = 一次内容交付 = 一个取件凭证，
    // 同一凭证至多扣 1 次 ⇒ 明细按「取件会话」记（多文件逐个下载/断点续传算同一次）。
    // 此前 owner 侧只有「最后一次取件 IP + 累计次数」⇒ 看不到逐条历史。
    24: optional list<PickupRecord> pickups (api.body = "pickups"),
}

// PickupRecord 一次取件的明细（owner 侧「取件历史」逐条展示）。
struct PickupRecord {
    1: required string picked_at (api.body = "picked_at"),  // RFC3339Nano
    2: required string ip        (api.body = "ip"),         // 取件人 IP（可信代理解析后）
    3: optional string channel   (api.body = "channel"),    // 交付面：select/retrieve/download
}

struct UserSharesListData {
    1: required list<UserShareItemData> items      (api.body = "items"),
    2: required i64  total       (api.body = "total"),
    3: required i32  page        (api.body = "page"),
    4: required i32  page_size   (api.body = "page_size"),
    5: required i64  total_pages (api.body = "total_pages"),
    6: required bool has_next    (api.body = "has_next"),
    7: required bool has_prev    (api.body = "has_prev"),
}

struct UserSharesListResp {
    1: required i32                    code    (api.body = "code"),
    2: required string                 message (api.body = "message"),
    3: optional UserSharesListData     data    (api.body = "data"),
}

struct UserShareCodesReq {
    1: required list<string> codes (api.body = "codes"),
}

struct UserShareBatchExtendReq {
    1: required list<string> codes   (api.body = "codes"),
    2: optional i32  hours           (api.body = "hours"),    // 延长小时数（>0）
    3: optional bool forever         (api.body = "forever"),  // true = 设为永久
}

struct UserShareCodeReq {
    1: required string code (api.path = "code"),
}

// 批量操作返回受影响计数（键随操作：deleted/extended）；单操作可空
struct UserShareOpResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
    3: optional map<string, i32> data (api.body = "data"),
}

// ==================== 取件元数据（2026-10-26 自 customHandler 收敛进 IDL） ====================
//
// ⚠️ 字段名/可空性**必须**与收敛前的 JSON 完全一致（前端与外部集成方都依赖）：
//   · name  仅 file 分享有 ⇒ optional（缺省不输出，与原 omitempty 一致）
//   · expired_at 原为 *time.Time（null）⇒ optional（缺省不输出；前端用 ?? null 兜）
//   · 其余字段恒有 ⇒ required

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

// ==================== 多文件分享（2026-10-26 自 customHandler 收敛进 IDL） ====================
//
// ⚠️ 公共参数在收敛前用 DefaultPostForm 读（**缺省值兜底**）⇒ 契约里一律 optional
//   （缺字段时 handler 显式兜底）⇒ 行为与收敛前完全一致（原来缺 expire_value 不报 400）。
//   文件本体**不入契约**（多文件 multipart 无法用 form 绑定表达）⇒ handler 仍手工取。

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

// MultiShareBindEntry multi-bind 的一个条目（分片会话 或 已直传对象，二选一）。
struct MultiShareBindEntry {
    1: optional string upload_id  (api.body = "upload_id"),
    2: optional string object_key (api.body = "object_key"),
    3: required string file_name  (api.body = "file_name"),
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

// ==================== 服务器本地文件导入（2026-10-26 自 customHandler 收敛进 IDL） ====================

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

// ==================== 服务定义 ====================

service ShareService {
    // ShareText 分享文本
    ShareTextResp ShareText(1: ShareTextReq req) (api.post = "/share/text/")

    // ShareFile 分享文件
    ShareFileResp ShareFile(1: ShareFileReq req) (api.post = "/share/file/")

    // GetShare 获取分享内容
    GetShareResp GetShare(1: GetShareReq req) (api.get = "/share/select/")

    // DownloadFile 下载文件
    DownloadFileResp DownloadFile(1: DownloadFileReq req) (api.get = "/share/download")

    // ==================== 用户分享管理（2026-10-09 自 customHandler 收敛进 IDL） ====================

    // UserSharesList 我的分享列表（登录用户；认证在 handler 内 requireLogin 语义不变）
    UserSharesListResp UserSharesList(1: UserSharesListReq req) (api.get = "/api/v1/user/shares")

    // UserSharesBatchDelete 批量软删除（回收站）
    UserShareOpResp UserSharesBatchDelete(1: UserShareCodesReq req) (api.post = "/api/v1/user/shares/batch-delete")

    // UserSharesBatchExtend 批量延期
    UserShareOpResp UserSharesBatchExtend(1: UserShareBatchExtendReq req) (api.post = "/api/v1/user/shares/batch-extend")

    // UserSharesRestore 恢复软删除的分享
    UserShareOpResp UserSharesRestore(1: UserShareCodeReq req) (api.post = "/api/v1/user/shares/:code/restore")

    // UserSharesHardDelete 永久删除（仅回收站内）
    UserShareOpResp UserSharesHardDelete(1: UserShareCodeReq req) (api.delete = "/api/v1/user/shares/:code/hard")

    // ==================== 自 customHandler 收敛进 IDL（2026-10-26） ====================

    // ShareMetadata 取件元数据（不扣次数、不要密码；取件页渲染用）
    ShareMetadataResp ShareMetadata(1: ShareMetadataReq req) (api.get = "/share/metadata/:code")

    // MultiShareDirect 多文件直传建分享（multipart；文件本体不入契约，handler 手工取）
    MultiShareDirectResp MultiShareDirect(1: MultiShareDirectReq req) (api.post = "/api/v1/share/multi-direct")

    // MultiShareBind 多文件绑定建分享（分片会话 / 已直传对象）
    MultiShareBindResp MultiShareBind(1: MultiShareBindReq req) (api.post = "/api/v1/share/multi-bind")

    // UserSharesImportLocal 服务器本地文件导入为分享（NAS 免上传场景）
    UserSharesImportLocalResp UserSharesImportLocal(1: UserSharesImportLocalReq req) (api.post = "/api/v1/user/shares/import-local")

}
