// =====================================================================
// preview.thrift — 在线预览
// =====================================================================
// 2026-10-06 补建：preview 路由此前是"无 IDL 孤儿"（router 为 hz 生成后
// IDL 散佚，无法再生成）。本文件按现存 router/handler 实际行为回填，
// 使 preview 域回到 IDL 治理（hz update 可再生成 router）。
// 注意：响应 data 字段实际返回 repo/db/model.FilePreview 的 JSON 形状，
// 此处按对外契约固化（新增字段向后兼容地追加可选字段）。
// =====================================================================

namespace go preview

// ==================== 获取预览 ====================

struct GetPreviewReq {
    1: required string code (api.path = "code"),
    // 取件密码经请求头传递（同批随 core v0.24.0 收敛，与 GetShareReq 同口径）：
    // query 形态有访问日志/浏览器历史/Referer 泄漏面
    2: optional string password (api.header = "X-Share-Password"),
}

struct PreviewData {
    1: required i64    id           (api.body = "id"),
    2: required i64    file_code_id (api.body = "file_code_id"),
    3: required string preview_type (api.body = "preview_type"),   // image/video/audio/pdf/text/office
    4: optional string thumbnail    (api.body = "thumbnail"),
    5: optional string preview_url  (api.body = "preview_url"),
    6: optional i32    width        (api.body = "width"),
    7: optional i32    height       (api.body = "height"),
    8: optional i32    duration     (api.body = "duration"),       // 秒
    9: optional i32    page_count   (api.body = "page_count"),
    10: optional string text_content (api.body = "text_content"),
    11: optional string mime_type    (api.body = "mime_type"),
    12: optional i64   file_size    (api.body = "file_size"),
}

struct GetPreviewResp {
    1: required i32         code    (api.body = "code"),
    2: required string      message (api.body = "message"),
    3: optional PreviewData data    (api.body = "data"),
}

// ==================== 服务定义 ====================

service PreviewService {
    // GetPreview 获取文件预览信息（受取件闸门/锁定管控，语义同取件）
    GetPreviewResp GetPreview(1: GetPreviewReq req) (api.get = "/preview/:code")
}
