# contracts · 契约层

[![CI](https://github.com/pigeonbox/contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/pigeonbox/contracts/actions/workflows/ci.yml)
[![Tag](https://img.shields.io/github/v/tag/pigeonbox/contracts)](https://github.com/pigeonbox/contracts/tags)
[![License](https://img.shields.io/github/license/pigeonbox/contracts)](LICENSE)

PigeonBox 契约层:错误码 + Thrift 生成的 API 类型。纯类型、零业务依赖,是前后端与所有实现方(backend core、fnos 等)的单一真相源。

> 🗂️ [PigeonBox 生态](https://github.com/orgs/pigeonbox)成员仓 · 总览见 [装配仓 pigeonbox](https://github.com/pigeonbox/pigeonbox) · [架构图集](https://github.com/pigeonbox/pigeonbox/blob/main/docs/architecture.md)

## 内容

| 目录 | 说明 |
|------|------|
| `errcode/` | 全站统一业务码(码段规划见文件头注释) |
| `gen/` | 由 `idl/*.thrift` 生成的纯模型类型(Thrift v0.13 工具链) |
| `gen/ts/` | 由 IDL 生成的 **TypeScript** 类型声明(`cmd/gen-ts`,供前端 npm 依赖) |
| `openapi/` | 由 IDL 生成的 OpenAPI 3.0 规范(`cmd/gen-openapi`,core go:embed 服务于 `/openapi.json`) |
| `idl/` | Thrift IDL 源(单一真相源,与 gen/ 同仓演进;现承载 17 个 service,含 `p2p.thrift` 的 P2PPublicService——联邦推送邀请公开收件,以及 AdminP2PService——**联邦面四端点**(设备直传九端点已随 PigeonBeam 拆分于 v0.18.0 拆除) |
| `cmd/` | 自包含生成器:`gen-openapi` / `gen-ts`(纯 Go,零外部工具链) |

## 依赖规则(强制)

- 本模块**不允许** import 任何项目内包,仅依赖 thrift runtime 与标准库。
- 任何破坏性变更(删除/改名字段、改错误码语义)视为 **不兼容变更**,必须升主版本。

## 重新生成 gen/

IDL 源(`idl/`)与生成产物(`gen/`)都在本仓内,自包含再生成:

```bash
./scripts/install-tools.sh       # 首次:安装 hz v0.9.7 + thriftgo v0.4.3(与既有产物一致)
./scripts/gen-model.sh           # 从 idl/*.thrift 全量再生成 gen/<domain>/
CHECK=1 ./scripts/gen-model.sh   # 只校验 gen/ 与 idl/ 是否同步(CI 可用)
```

OpenAPI 规范与 TS 类型是纯 Go 生成器,无需安装工具链:

```bash
go run ./cmd/gen-openapi            # 再生成 openapi/openapi.json(--check 只校验)
go run ./cmd/gen-ts                 # 再生成 gen/ts/*.d.ts(--check 只校验)
```

> 历史说明: 生成曾依赖旧单体仓库 PigeonBox/backend 的 `make gen` + 手工拷贝,
> 现已内聚到本仓(idl/ 与生成脚本于 2026-10 自单体迁入)。

## 引用方式

```go
import (
    "github.com/pigeonbox/contracts/errcode"
    "github.com/pigeonbox/contracts/gen/share"
)
```

下游 `go.mod` 无需任何 `replace`:thrift 版本约束以 `require` 形式从本模块传递。

## 前端(TypeScript)消费

`gen/ts/` 是从同一份 IDL 生成的纯类型声明(零 runtime)。打 `v*` tag 时 Release
工作流自动把类型包成 npm tgz 挂到本仓 Release(`pigeonbox-contracts-<ver>.tgz`,
版本与 tag 对齐),前端以 Release 资产 URL 直接依赖——**匿名 https,Docker/CI
构建免 git 免 npm registry,版本钉定与 tag 严格一致**:

```jsonc
// frontend package.json
"@pigeonbox/contracts": "https://github.com/pigeonbox/contracts/releases/download/v0.14.0/pigeonbox-contracts-0.14.0.tgz"
```

```ts
import type { share, admin } from '@pigeonbox/contracts';

type Detail = share.ShareDetail;
const req: admin.AdminListFilesReq = { /* ... */ };
```

> 不用 npm git 依赖的原因:npm 对 github 简写依赖恒以 `git+ssh` 解析记录进
> lockfile,容器内 `npm ci` 无 SSH key 必挂;Release 资产是纯 https 下载,无此坑。

约定:

- 域 = `namespace go` 名,每域一个 `gen/ts/<domain>.d.ts`;顶层入口 `index.d.ts`
  以 `export type * as <domain>` 命名空间导出——跨域同名类型
  (如 `BaseConfig`/`EmptyReq`)由命名空间隔离,勿改为顶层 `export *`。
- 字段名与线上 JSON 序列化名一致(优先 `api.*` 注解值);`optional` → `?:`;
  `map<K,V>` → `Record<string, V>`(JSON object 键恒为字符串);`i64` → `number`
  (现网值域远低于 2^53)。
- 改 IDL 后:`go run ./cmd/gen-ts` 再生成并提交,CI `--check` 守卫同步;
  `cmd/gen-ts` 的测试会与 `openapi.json` 做类型名单对账,防两侧漂移。
- 发版 = 打 tag(工作流自动对齐 `package.json` version 并发 tgz 资产),
  前端升级 = 换 package.json 里的资产 URL 版本号。

## License

[Apache-2.0](LICENSE)
