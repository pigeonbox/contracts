// =====================================================================
// chunk.thrift — 分片上传
// =====================================================================
// 迁移自: idl/chunk.proto
// =====================================================================

namespace go chunk

// ==================== 初始化分片上传 ====================

struct ChunkUploadInitReq {
    1: required string file_name    (api.body = "file_name"),
    2: required i64    file_size    (api.body = "file_size"),
    3: required string file_hash    (api.body = "file_hash"),
    4: required i32    chunk_size   (api.body = "chunk_size"),
    5: required i32    total_chunks (api.body = "total_chunks"),
    // ---- 秒传建分享元数据（2026-10-12，与 CompleteReq 同形；可选）----
    // 携带 expire_style 即视为启用秒传快速通道：命中同用户同 hash+size 历史文件时
    // 按本次元数据建新分享（引用既有对象，免传分片）；不携带则不做快速通道
    // （正常分片上传，Complete 再按其元数据建分享）。两条路径均过 CreateShare
    // 去重钩子（存储级去重恒生效）。
    6: optional i32    expire_value  (api.body = "expire_value"),
    7: optional string expire_style  (api.body = "expire_style"),
    8: optional bool   require_auth  (api.body = "require_auth"),
    9: optional string password      (api.body = "password"),
    // 自定义取件码：仅登录用户可指定（与 Complete 同把关）
    10: optional string custom_code  (api.body = "custom_code"),
    // 文件备注(可空,随分享展示给取件人;2026-10-12 #489)
    11: optional string note         (api.body = "note"),
}

struct ChunkUploadInitData {
    1: required string upload_id        (api.body = "upload_id"),
    2: required string chunk_size       (api.body = "chunk_size"),
    3: required string total_chunks     (api.body = "total_chunks"),
    4: required bool   is_quick_upload  (api.body = "is_quick_upload"),     // Quick upload flag
    5: required string share_code       (api.body = "share_code"),          // If quick upload, return share code directly
    // 秒传命中时的完整分享链接（2026-10-12 建新分享语义；未命中为空）
    6: optional string share_url        (api.body = "share_url"),
}

struct ChunkUploadInitResp {
    1: required i32                  code    (api.body = "code"),
    2: required string               message (api.body = "message"),
    3: required ChunkUploadInitData  data    (api.body = "data"),
}

// ==================== 上传单个分片 ====================

struct ChunkUploadReq {
    1: required string upload_id   (api.path = "upload_id"),
    2: required i32    chunk_index (api.path = "chunk_index"),
    // 分片数据通过 multipart/form-data 上传
}

struct ChunkUploadData {
    1: required i32    chunk_index (api.body = "chunk_index"),
    2: required string chunk_hash  (api.body = "chunk_hash"),
}

struct ChunkUploadResp {
    1: required i32           code    (api.body = "code"),
    2: required string        message (api.body = "message"),
    3: required ChunkUploadData data   (api.body = "data"),
}

// ==================== 查询上传进度 ====================

struct ChunkUploadStatusReq {
    1: required string upload_id (api.path = "upload_id"),
}

struct ChunkUploadStatusData {
    1: required string upload_id        (api.body = "upload_id"),
    2: required i32    total_chunks     (api.body = "total_chunks"),
    3: required i32    uploaded_chunks  (api.body = "uploaded_chunks"),
    4: required list<i32> uploaded_indexes (api.body = "uploaded_indexes"),
    5: required i32    progress         (api.body = "progress"),   // 百分比
    6: required string status           (api.body = "status"),     // uploading, completed, cancelled
}

struct ChunkUploadStatusResp {
    1: required i32                     code    (api.body = "code"),
    2: required string                  message (api.body = "message"),
    3: required ChunkUploadStatusData   data    (api.body = "data"),
}

// ==================== 完成上传 ====================

struct ChunkUploadCompleteReq {
    1: required string upload_id     (api.path = "upload_id"),
    2: required i32    expire_value  (api.body = "expire_value"),
    3: required string expire_style  (api.body = "expire_style"),
    4: required bool   require_auth  (api.body = "require_auth"),
    // 密码保护:require_auth 时必填(此前 handler form 直读+二次解析 body)
    5: optional string password      (api.body = "password"),
    // 自定义取件码(P3):仅登录用户可指定(此前 handler form 直读+二次解析 body)
    6: optional string custom_code   (api.body = "custom_code"),
    // 文件备注(可空,随分享展示给取件人;2026-10-12 #489)
    7: optional string note          (api.body = "note"),
}

struct ChunkUploadCompleteData {
    1: required string share_code (api.body = "share_code"),
    2: required string share_url  (api.body = "share_url"),
    3: required string file_name  (api.body = "file_name"),
    4: required i64    file_size  (api.body = "file_size"),
}

struct ChunkUploadCompleteResp {
    1: required i32                     code    (api.body = "code"),
    2: required string                  message (api.body = "message"),
    3: required ChunkUploadCompleteData data    (api.body = "data"),
}

// ==================== 取消上传 ====================

struct ChunkUploadCancelReq {
    1: required string upload_id (api.path = "upload_id"),
}

struct ChunkUploadCancelResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 服务定义 ====================

service ChunkService {
    // ChunkUploadInit 初始化分片上传
    ChunkUploadInitResp ChunkUploadInit(1: ChunkUploadInitReq req) (api.post = "/chunk/upload/init/")

    // ChunkUpload 上传单个分片
    ChunkUploadResp ChunkUpload(1: ChunkUploadReq req) (api.post = "/chunk/upload/chunk/:upload_id/:chunk_index")

    // ChunkUploadStatus 查询上传进度
    ChunkUploadStatusResp ChunkUploadStatus(1: ChunkUploadStatusReq req) (api.get = "/chunk/upload/status/:upload_id")

    // ChunkUploadComplete 完成上传
    ChunkUploadCompleteResp ChunkUploadComplete(1: ChunkUploadCompleteReq req) (api.post = "/chunk/upload/complete/:upload_id")

    // ChunkUploadCancel 取消上传
    ChunkUploadCancelResp ChunkUploadCancel(1: ChunkUploadCancelReq req) (api.delete = "/chunk/upload/cancel/:upload_id")
}
