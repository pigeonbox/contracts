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
    3: required string expire_style  (api.body = "expire_style"),  // minute, hour, day, week, month, year, forever
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
    // 6 位取件码（2026-10-07 起文件分享铸造：pickup_code → code 的 KV 映射，
    // 匿名通道 retrieve/search/download 均可解析；文本分享与永久分享不铸造，为空）
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
}

struct ShareFileResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required ShareData data    (api.body = "data"),
}

// ==================== 获取分享 ====================

struct GetShareReq {
    1: required string code     (api.path = "code"),
    2: optional string password (api.query = "password"),
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
    1: required string code     (api.query = "code"),
    2: optional string password (api.query = "password"),
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

struct UserShareItemData {
    1: required i64     id            (api.body = "id"),
    2: required string  code          (api.body = "code"),
    // 6 位取件码（落库持久化；空 = 未铸造：E2E/历史数据）
    3: optional string  pickup_code   (api.body = "pickup_code"),
    4: required string  prefix        (api.body = "prefix"),
    5: required string  suffix        (api.body = "suffix"),
    6: required string  file_name     (api.body = "file_name"),
    7: required string  file_path     (api.body = "file_path"),
    8: required i64     size          (api.body = "size"),
    9: required string  text          (api.body = "text"),
    10: optional string expired_at    (api.body = "expired_at"),     // RFC3339Nano
    11: required i32    expired_count (api.body = "expired_count"),  // -1=无限, 0=耗尽, >0=剩余
    12: required i32    used_count    (api.body = "used_count"),
    13: required bool   require_auth  (api.body = "require_auth"),
    14: required string upload_type   (api.body = "upload_type"),
    15: required string created_at    (api.body = "created_at"),     // RFC3339Nano
    16: required string updated_at    (api.body = "updated_at"),
    17: optional string deleted_at    (api.body = "deleted_at"),     // 回收站
    18: required string  viewer_ip     (api.body = "viewer_ip"),
    19: optional string viewer_at     (api.body = "viewer_at"),
    20: required i32    viewer_count  (api.body = "viewer_count"),
    21: required bool   is_expired    (api.body = "is_expired"),
    22: required bool   is_text_share (api.body = "is_text_share"),
    23: required string  status        (api.body = "status"),         // normal/blocked/pending_review
    24: required i32    file_count    (api.body = "file_count"),     // P0 多文件：子文件数
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
}
