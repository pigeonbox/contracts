// =====================================================================
// request.thrift — 寄件码/反向收件（P2）
// =====================================================================
// 链接属主创建投递链接，访客凭公开链接上传，落成属主名义的分享。
// 2026-10-09 IDL 化（此前为 customHandler 手写路由 + gorm 模型直出）。
// 兼容注记：历史 wire 中 gorm.Model 内嵌字段以 Go 字段名输出（ID/CreatedAt
// 等混合大小写，前端未消费）；IDL 化后统一为小写 snake_case（增量键，无害）。
// =====================================================================

namespace go request

// ==================== 链接管理（登录用户，JWT-only） ====================

struct CreateReq {
    1: required string title        (api.body = "title"),
    2: optional i32    max_files    (api.body = "max_files"),     // 0 = 不限
    3: optional i64    max_bytes    (api.body = "max_bytes"),     // 0 = 不限
    4: optional i32    expire_value (api.body = "expire_value"),
    5: optional string expire_style (api.body = "expire_style"),  // minute/hour/day/week/month/year/forever（投递通道只支持按时间过期，不支持 count）
}

struct FileRequestData {
    1: required i64    id         (api.body = "id"),
    2: required string token      (api.body = "token"),      // 链接令牌（crypto/rand 32 hex）
    3: required string title      (api.body = "title"),
    4: required i32    max_files  (api.body = "max_files"),  // 0 = 不限
    5: required i64    max_bytes  (api.body = "max_bytes"),  // 0 = 不限
    6: optional string expired_at (api.body = "expired_at"), // RFC3339Nano；缺省 = 永久
    7: required i32    used_count (api.body = "used_count"),
    8: required i64    recv_bytes (api.body = "recv_bytes"),
    9: required string created_at (api.body = "created_at"),
    10: required string updated_at (api.body = "updated_at"),
}

struct CreateResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: optional FileRequestData data    (api.body = "data"),
}

struct ListMineResp {
    1: required i32                    code    (api.body = "code"),
    2: required string                 message (api.body = "message"),
    3: optional list<FileRequestData>  data    (api.body = "data"),
}

struct TokenReq {
    1: required string token (api.path = "token"),
}

struct ListMineReq {
    // 无查询参数（全量返回本人链接）
}

struct DeletedData {
    1: required bool deleted (api.body = "deleted"),
}

struct DeleteResp {
    1: required i32      code    (api.body = "code"),
    2: required string   message (api.body = "message"),
    3: optional DeletedData data (api.body = "data"),
}

// ==================== 访客侧（公开，无认证） ====================

struct PublicViewData {
    1: required string token      (api.body = "token"),
    2: required string title      (api.body = "title"),
    3: required i32    max_files  (api.body = "max_files"),
    4: required i64    max_bytes  (api.body = "max_bytes"),
    5: optional string expired_at (api.body = "expired_at"),
}

struct PublicResp {
    1: required i32           code    (api.body = "code"),
    2: required string        message (api.body = "message"),
    3: optional PublicViewData data  (api.body = "data"),
}

struct GuestUploadReq {
    1: required string token (api.path = "token"),
    // 文件通过 multipart/form-data 上传（字段名 files，兼容 file；1-100 项），
    // 访客按 IP 计入匿名日配额——管道在 handler 内（storage/quota/transfer）
}

struct GuestUploadData {
    1: required i32 file_count (api.body = "file_count"),
}

struct GuestUploadResp {
    1: required i32            code    (api.body = "code"),
    2: required string         message (api.body = "message"),
    3: optional GuestUploadData data   (api.body = "data"),
}

// ==================== 服务定义 ====================

service RequestService {
    // Create 创建投递链接（登录用户）
    CreateResp Create(1: CreateReq req) (api.post = "/api/v1/user/requests")

    // ListMine 我的投递链接列表（登录用户）
    ListMineResp ListMine(1: ListMineReq req) (api.get = "/api/v1/user/requests")

    // Delete 撤销投递链接（登录用户；不存在 404）
    DeleteResp Delete(1: TokenReq req) (api.delete = "/api/v1/user/requests/:token")

    // PublicGet 访客取链接信息（公开）
    PublicResp PublicGet(1: TokenReq req) (api.get = "/request/:token")

    // GuestUpload 访客投递（公开；multipart files[]，显式受邀不走总闸）
    GuestUploadResp GuestUpload(1: GuestUploadReq req) (api.post = "/api/v1/request/:token/upload")
}
