// =====================================================================
// notify.thrift — 系统通知（管理员公告）
// =====================================================================
// 管理员发布公告，前端首页/管理面板 banner 显示
// 支持时间窗口、级别、类型
// =====================================================================

namespace go notify

// ==================== 通用 ====================

// NotifyType 通知类型
struct NotifyType {
    1: required string value (api.body = "value"),  // system / feature / maintenance
}

// NotifyLevel 通知级别
struct NotifyLevel {
    1: required string value (api.body = "value"),  // info / warning / error / success
}

// ==================== 通知数据 ====================

struct NotifyItem {
    1: required i64    id         (api.body = "id"),
    2: required string title      (api.body = "title"),
    3: required string content    (api.body = "content"),
    4: required string type       (api.body = "type"),        // system/feature/maintenance
    5: required string level      (api.body = "level"),       // info/warning/error/success
    6: required i32    status     (api.body = "status"),      // 0=草稿 1=发布 2=下线
    7: optional string start_at   (api.body = "start_at"),    // 生效时间（RFC3339）
    8: optional string end_at     (api.body = "end_at"),      // 失效时间
    9: required string created_at (api.body = "created_at"),
    10: required string updated_at (api.body = "updated_at"),
}

// ==================== 列表查询 ====================

struct ListReq {
    1: optional i32    page      (api.query = "page"),
    2: optional i32    page_size (api.query = "page_size"),
    3: optional string type      (api.query = "type"),
    4: optional string level     (api.query = "level"),
    5: optional i32    status    (api.query = "status"),
}

struct ListData {
    1: required list<NotifyItem> items     (api.body = "items"),
    2: required i64              total     (api.body = "total"),
    3: required i32              page      (api.body = "page"),
    4: required i32              page_size (api.body = "page_size"),
}

struct ListResp {
    1: required i32      code    (api.body = "code"),
    2: required string   message (api.body = "message"),
    3: required ListData data    (api.body = "data"),
}

// ==================== 获取活跃通知（公开 API） ====================

struct ActiveReq {
    1: optional string type (api.query = "type"),
}

struct ActiveData {
    1: required list<NotifyItem> items (api.body = "items"),
}

struct ActiveResp {
    1: required i32        code    (api.body = "code"),
    2: required string     message (api.body = "message"),
    3: required ActiveData data    (api.body = "data"),
}

// ==================== 获取单条 ====================

struct GetReq {
    1: required i64 id (api.path = "id"),
}

struct GetResp {
    1: required i32       code    (api.body = "code"),
    2: required string    message (api.body = "message"),
    3: required NotifyItem data   (api.body = "data"),
}

// ==================== 创建 ====================

struct CreateReq {
    1: required string title    (api.body = "title"),
    2: required string content  (api.body = "content"),
    3: required string type     (api.body = "type"),
    4: required string level    (api.body = "level"),
    5: optional i32    status   (api.body = "status"),
    6: optional string start_at (api.body = "start_at"),
    7: optional string end_at   (api.body = "end_at"),
}

struct CreateResp {
    1: required i32        code    (api.body = "code"),
    2: required string     message (api.body = "message"),
    3: required NotifyItem data    (api.body = "data"),
}

// ==================== 更新 ====================

struct UpdateReq {
    1: required i64    id       (api.path = "id"),
    2: optional string title    (api.body = "title"),
    3: optional string content  (api.body = "content"),
    4: optional string type     (api.body = "type"),
    5: optional string level    (api.body = "level"),
    6: optional i32    status   (api.body = "status"),
    7: optional string start_at (api.body = "start_at"),
    8: optional string end_at   (api.body = "end_at"),
}

struct UpdateResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 删除 ====================

struct DeleteReq {
    1: required i64 id (api.path = "id"),
}

struct DeleteResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 我的通知（登录用户，2026-10-09 自 customHandler 收敛进 IDL） ====================

struct MineReq {
    1: optional i32 page      (api.query = "page"),
    2: optional i32 page_size (api.query = "page_size"),
}

struct UserNotifyItemData {
    1: required i64    id         (api.body = "id"),
    2: required string title      (api.body = "title"),
    3: required string content    (api.body = "content"),
    4: required string type       (api.body = "type"),
    5: required string level      (api.body = "level"),
    6: optional string read_at    (api.body = "read_at"),   // RFC3339Nano；缺省 = 未读
    7: required string created_at (api.body = "created_at"),
    8: required bool   is_read    (api.body = "is_read"),
}

struct MineData {
    1: required list<UserNotifyItemData> items       (api.body = "items"),
    2: required i64  total       (api.body = "total"),
    3: required i64  unread      (api.body = "unread"),
    4: required i32  page        (api.body = "page"),
    5: required i32  page_size   (api.body = "page_size"),
    6: required i64  total_pages (api.body = "total_pages"),
}

struct MineResp {
    1: required i32     code    (api.body = "code"),
    2: required string  message (api.body = "message"),
    3: optional MineData data   (api.body = "data"),
}

struct UnreadCountData {
    1: required i64 unread (api.body = "unread"),
}

struct UnreadCountResp {
    1: required i32             code    (api.body = "code"),
    2: required string          message (api.body = "message"),
    3: optional UnreadCountData data    (api.body = "data"),
}

struct MarkReadReq {
    1: optional bool all (api.body = "all"),  // true = 全部已读（当前仅支持全部已读）
}

struct MarkReadData {
    1: required i64 marked (api.body = "marked"),
}

struct MarkReadResp {
    1: required i32     code    (api.body = "code"),
    2: required string  message (api.body = "message"),
    3: optional MarkReadData data (api.body = "data"),
}

// ==================== 公开公告（2026-10-26 自 customHandler 收敛进 IDL） ====================

struct NotifyPublicItem {
    1: required i64    id       (api.body = "id"),
    2: required string title    (api.body = "title"),
    3: required string content  (api.body = "content"),
    4: required string type     (api.body = "type"),
    5: required string level    (api.body = "level"),
    6: required string start_at (api.body = "start_at"),
    7: required string end_at   (api.body = "end_at"),
}

struct NotifyPublicListReq {
}

struct NotifyPublicListData {
    1: required list<NotifyPublicItem> items (api.body = "items"),
}

struct NotifyPublicListResp {
    1: required i32                code    (api.body = "code"),
    2: required string             message (api.body = "message"),
    3: required NotifyPublicListData data   (api.body = "data"),
}

// ==================== 服务定义 ====================

service NotifyService {
    // List 通知列表（管理）
    ListResp List(1: ListReq req) (api.get = "/admin/notifies")

    // Active 当前活跃通知（公开）
    ActiveResp Active(1: ActiveReq req) (api.get = "/notifies/active")

    // Get 获取单条
    GetResp Get(1: GetReq req) (api.get = "/admin/notifies/:id")

    // Create 创建
    CreateResp Create(1: CreateReq req) (api.post = "/admin/notifies")

    // Update 更新
    UpdateResp Update(1: UpdateReq req) (api.put = "/admin/notifies/:id")

    // Delete 删除
    DeleteResp Delete(1: DeleteReq req) (api.delete = "/admin/notifies/:id")

    // ==================== 我的通知（2026-10-09 IDL 化；认证=JWT/API Key 二选一） ====================

    // Mine 我的通知列表（含广播 + 定向）
    MineResp Mine(1: MineReq req) (api.get = "/api/v1/notifies/mine")

    // UnreadCount 未读数（未登录防御性返回 0——历史语义，路由层实际拦截）
    UnreadCountResp UnreadCount(1: MineReq req) (api.get = "/api/v1/notifies/unread-count")

    // MarkRead 标记已读（当前仅支持 all=true）
    MarkReadResp MarkRead(1: MarkReadReq req) (api.post = "/api/v1/notifies/mark-read")

    // ==================== 自 customHandler 收敛进 IDL（2026-10-26） ====================

    // NotifyPublicList 站级公开公告列表（匿名可访问；最多 50 条）
    NotifyPublicListResp NotifyPublicList(1: NotifyPublicListReq req) (api.get = "/api/v1/notifies/public")

}
