// =====================================================================
// storage.thrift — 存储管理（OpenDAL 配置）
// =====================================================================
// 迁移自: idl/storage.proto
// 改造点: storage 改用 OpenDAL 风格 scheme + options
// =====================================================================

namespace go storage

// ==================== 存储详情 ====================

struct WebDAVConfig {
    1: required string hostname   (api.body = "hostname"),
    2: required string username   (api.body = "username"),
    3: required string password   (api.body = "password"),
    4: required string root_path  (api.body = "root_path"),
    5: required string url        (api.body = "url"),
}

struct S3Config {
    1: required string access_key_id     (api.body = "access_key_id"),
    2: required string secret_access_key (api.body = "secret_access_key"),
    3: required string bucket_name       (api.body = "bucket_name"),
    4: required string endpoint_url      (api.body = "endpoint_url"),
    5: required string region_name       (api.body = "region_name"),
    6: required string hostname          (api.body = "hostname"),
    7: required string proxy             (api.body = "proxy"),
}

struct NFSConfig {
    1: required string server      (api.body = "server"),
    2: required string path        (api.body = "path"),
    3: required string mount_point (api.body = "mount_point"),
    4: required string version     (api.body = "version"),
    5: required string options     (api.body = "options"),
    6: required i32    timeout     (api.body = "timeout"),
    7: required i32    auto_mount  (api.body = "auto_mount"),
    8: required i32    retry_count (api.body = "retry_count"),
    9: required string sub_path    (api.body = "sub_path"),
}

struct StorageDetail {
    1: required string type          (api.body = "type"),
    2: required bool   available     (api.body = "available"),
    3: required string storage_path  (api.body = "storage_path"),
    4: required i32    usage_percent (api.body = "usage_percent"),
    5: required string error         (api.body = "error"),
}

struct StorageConfig {
    1: required string         type         (api.body = "type"),
    2: required string         storage_path (api.body = "storage_path"),
    3: required WebDAVConfig   webdav       (api.body = "webdav"),
    4: required S3Config       s3           (api.body = "s3"),
    5: required NFSConfig      nfs          (api.body = "nfs"),
}

// ==================== 获取存储信息 ====================

struct GetStorageInfoReq {
}

struct StorageInfoData {
    1: required string                    current          (api.body = "current"),           // 当前存储类型
    2: required list<string>              available        (api.body = "available"),         // 可用存储类型列表
    3: required map<string,StorageDetail> storage_details  (api.body = "storage_details"),   // 各存储类型详细信息
    4: required StorageConfig             storage_config   (api.body = "storage_config"),     // 存储配置
}

struct GetStorageInfoResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: required StorageInfoData  data    (api.body = "data"),
}

// ==================== 切换存储 ====================

struct SwitchStorageReq {
    1: required string type (api.body = "type"),
}

struct SwitchStorageData {
    1: required bool   success      (api.body = "success"),
    2: required string message      (api.body = "message"),
    3: required string current_type (api.body = "current_type"),
}

struct SwitchStorageResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: required SwitchStorageData data    (api.body = "data"),
}

// ==================== 测试存储连接 ====================

struct TestStorageConnectionReq {
    1: required string type (api.path = "type"),
}

struct TestStorageData {
    1: required string type   (api.body = "type"),
    2: required string status (api.body = "status"),
}

struct TestStorageConnectionResp {
    1: required i32              code    (api.body = "code"),
    2: required string           message (api.body = "message"),
    3: required TestStorageData  data    (api.body = "data"),
}

// ==================== 更新存储配置 ====================

// 更新存储配置的请求体。
//
// 形态：**只有**扁平一种——请求体即 conf.StorageConfig 同构 JSON
// （type/storage_path/quota/s3/webdav/ftp/sftp/azureblob/hdfs/onedrive/oss..obs），
// 服务端整体校验 → Probe → 热切换 → 持久化。
//
// 旧嵌套形态 {type, config:{storage_path/webdav/s3}} **已退役**（2026-10-25 删除旧版本
// 兼容）：它只能切 local/webdav/s3 三种、字段名与实际配置模型对不上（旧契约遗留）。
//
// 字段随厂商增长 ⇒ 沿用本仓「松散体」惯例（见 admin.thrift 的 AdminUpdateConfigReq）：
// 结构体只作**声明面**，body 的实际字段由 conf.StorageConfig 决定。
struct UpdateStorageConfigReq {
}

struct UpdateStorageConfigResp {
    1: required i32    code    (api.body = "code"),
    2: required string message (api.body = "message"),
}

// ==================== 服务定义 ====================

struct StorageUsage {
    1: required i64  object_count (api.body = "object_count"),
    2: required i64  total_size   (api.body = "total_size"),
    3: optional i64  quota_used   (api.body = "quota_used"),
}

struct StorageBackendStatus {
    1: required string type        (api.body = "type"),
    2: required bool   configured  (api.body = "configured"),
    3: required bool   active      (api.body = "active"),
    4: optional string detail      (api.body = "detail"),
    5: optional StorageUsage usage (api.body = "usage"),
}

struct TodayTraffic {
    1: required i64 uploads   (api.body = "uploads"),
    2: required i64 downloads (api.body = "downloads"),
}

struct StorageInsightsData {
    1: required string              current_type    (api.body = "current_type"),
    2: required string              effective_type  (api.body = "effective_type"),
    3: required string              presign_policy  (api.body = "presign_policy"),
    4: required bool                direct_download (api.body = "direct_download"),
    5: required map<string,string>  current_detail  (api.body = "current_detail"),
    6: required StorageUsage        remote_usage    (api.body = "remote_usage"),
    7: required StorageUsage        local_usage     (api.body = "local_usage"),
    8: required TodayTraffic        today_traffic   (api.body = "today_traffic"),
    9: required i64                 presign_orphans (api.body = "presign_orphans"),
    10: required i64                alive_shares    (api.body = "alive_shares"),
    11: required i64                soft_deleted    (api.body = "soft_deleted"),
}

struct GetStorageInsightsResp {
    1: required i32                 code    (api.body = "code"),
    2: required string              message (api.body = "message"),
    3: required StorageInsightsData data    (api.body = "data"),
}

struct CleanPresignOrphansResp {
    1: required i32 code    (api.body = "code"),
    2: required string message (api.body = "message"),
    3: required i32 removed (api.body = "removed"),
}

service StorageService {
    // GetStorageInfo 获取存储信息
    GetStorageInfoResp GetStorageInfo(1: GetStorageInfoReq req) (api.get = "/admin/storage")

    // SwitchStorage 切换存储
    SwitchStorageResp SwitchStorage(1: SwitchStorageReq req) (api.post = "/admin/storage/switch")

    // TestStorageConnection 测试存储连接
    TestStorageConnectionResp TestStorageConnection(1: TestStorageConnectionReq req) (api.get = "/admin/storage/test/:type")

    // UpdateStorageConfig 更新存储配置
    UpdateStorageConfigResp UpdateStorageConfig(1: UpdateStorageConfigReq req) (api.put = "/admin/storage/config")

    // GetStorageInsights 存储洞察（双端用量/配额/今日流量/孤儿统计）
    GetStorageInsightsResp GetStorageInsights(1: GetStorageInfoReq req) (api.get = "/admin/storage/insights")

    // CleanPresignOrphans 清理远端 presign 孤儿对象（Init 后未 Complete 的直传残留）
    CleanPresignOrphansResp CleanPresignOrphans(1: GetStorageInfoReq req) (api.post = "/admin/storage/clean-presign-orphans")
}
