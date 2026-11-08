module github.com/pigeonbox/contracts

go 1.26.5

toolchain go1.26.10

// gen/ 由 thrift v0.13.0 编译器生成,依赖其 runtime API;
// 此处直接 require 精确版本(而非 replace),版本约束随 require 传递给所有使用者,
// 下游模块无需复述任何 thrift 版本约束。
//
// ⚠️ 别随手 go get -u 到 thrift v0.25: 该版本给 IPROT 的 Read*/Skip 全加了 ctx 形参,
// 而 hz 至今(实测 v0.9.8,已是 cmd/hz 子模块最新 tag)产出的 gen/ 仍是无 ctx 的老 API
// ⇒ build 直接报 "not enough arguments in call to iprot.ReadStructBegin"。
// 已实测: 用 hz v0.9.8 重跑 scripts/gen-model.sh, gen/ 逐字节不变 ⇒ 这一跳不是本仓
// 单方面能做的, 得等上游 hz 换成 ctx 风格生成器后整批重生成。
require github.com/apache/thrift v0.13.0

require github.com/cloudwego/thriftgo v0.4.5

require (
	github.com/bytedance/gopkg v0.1.4 // indirect
	github.com/cloudwego/gopkg v0.2.1 // indirect
)
