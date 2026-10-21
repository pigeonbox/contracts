module github.com/pigeonbox/contracts

go 1.26.5
toolchain go1.26.10

// gen/ 由 thrift v0.13.0 编译器生成,依赖其 runtime API;
// 此处直接 require 精确版本(而非 replace),版本约束随 require 传递给所有使用者,
// 下游模块无需复述任何 thrift 版本约束。
require github.com/apache/thrift v0.13.0

require github.com/cloudwego/thriftgo v0.4.5

require (
	github.com/bytedance/gopkg v0.1.4 // indirect
	github.com/cloudwego/gopkg v0.2.0 // indirect
)
