# idl/ - 接口定义语言（真相源）

此目录存放 IDL（Interface Definition Language）文件，是整个生态 API 契约的**单一真相源**：
路由/模型的变更必须先改这里再跑生成链（见下），生成物一律禁止手改。

## 目录结构

```
idl/
├── api.thrift             # hz HTTP 注解约定文档（非服务定义）
├── error.thrift           # 统一错误响应 schema（纯 struct）
├── common.thrift          # health/index/ping
├── setup.thrift           # 系统初始化
├── qrcode.thrift          # 二维码
├── chunk.thrift           # 分片上传
├── share.thrift           # 分享
├── share_anonymous.thrift # 匿名取件
├── user.thrift            # 用户
├── admin.thrift           # 管理员
├── storage.thrift         # 存储管理（OpenDAL）
├── maintenance.thrift     # 维护
├── notify.thrift          # 系统通知
├── presign.thrift         # 预签名上传
├── preview.thrift         # 在线预览
├── ratelimit.thrift       # 限流管理
├── http/                  # HTTP 基础设施端点
│   └── health.thrift      # K8s 风格健康检查
└── rpc/                   # Kitex RPC 预留（当前为空，见 rpc/README.md）
```

全部为 `.thrift`（proto → thrift 迁移已完成，仓内已无 .proto 文件）。

## 代码生成链路

IDL 与全部生成产物都在本仓内，由生成器从 IDL 再生成（仓内无 Makefile，直接跑脚本/命令）：

```bash
# 1) 模型：IDL → gen/<domain>/（hz + thriftgo，仅纯类型，无 handler/router）
./scripts/gen-model.sh            # 全量再生成
CHECK=1 ./scripts/gen-model.sh    # 只校验产物与仓内 gen/ 一致（CI 用）

# 2) OpenAPI：IDL → openapi/openapi.json（带 schema 的 OpenAPI 3.0，core 启动时 embed 服务）
go run ./cmd/gen-openapi          # --check 校验

# 3) 前端 TS 类型：IDL → gen/ts/*.d.ts（发 v* tag 自动打包 npm tgz 挂 Release）
go run ./cmd/gen-ts               # --check 校验
```

下游 core 仓消费同一份 IDL 生成路由：`core/scripts/gen-router.sh` → `core/gen/router/`，
随后 `go test ./bootstrap/` 路由守卫必须绿（`gen/router/*/middleware.go` 鉴权接线是唯一手工区）。

**改路由的标准流程**：改 `contracts/idl/*.thrift` → `./scripts/gen-model.sh` +（core 仓）
`./scripts/gen-router.sh` →（按需）`go run ./cmd/gen-openapi` / `./cmd/gen-ts` → 路由守卫测试
→ IDL 与生成物一起提交。

## thrift IDL 编写规范

参见 `idl/api.thrift` 约定文档，关键规则：

1. `namespace go <sub>`（裸域名，Go 包名 = namespace，如 `namespace go share`）
2. type 命名 `XxxReq` / `XxxResp`
3. service 命名 `XxxService`
4. field 编号从 1 开始，只增不改不复用（API 兼容）
5. hz 注解直接内联（无需 include）：字段上 `api.body`/`api.query`/`api.path` 等，
   路由注解在 method 末尾：`Method(1: Req req) (api.get = "/path")`
6. 路径参数用 `:param` 表示（hz 自动转 `{param}`）

## 安装工具

```bash
./scripts/install-tools.sh           # 装 hz(v0.9.8) + thriftgo(v0.4.3)
./scripts/install-tools.sh hz        # 只装 hz
./scripts/install-tools.sh thriftgo  # 只装 thriftgo
```

## 注意事项

- 仅含 `service` 定义的 IDL 会生成模型；`api.thrift`/`error.thrift` 等纯 struct/文档文件被跳过（其类型被引用时随 include 自动带出）
- 生成物（`gen/`、`openapi/openapi.json`、`gen/ts/`）勿手改，CI 以 `CHECK=1`/`--check` 对账
- `api.thrift` 是约定文档，不是服务定义
