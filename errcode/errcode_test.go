package errcode

import (
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"
)

// TestErrorThriftCoversErrcode 比对门禁（issue #32）：errcode.go 的全部枚举常量
// 必须出现在 idl/error.thrift 的注释清单里，缺一个即红。
// 此前清单靠人工跳着补（40012-40014 在、40009-40011 不在），滞后 27 个码且
// 注释型内容不进任何 gen CHECK，无人拦。
func TestErrorThriftCoversErrcode(t *testing.T) {
	constSrc, err := os.ReadFile("errcode.go")
	if err != nil {
		t.Fatalf("读取 errcode.go: %v", err)
	}
	thriftSrc, err := os.ReadFile("../idl/error.thrift")
	if err != nil {
		t.Fatalf("读取 idl/error.thrift: %v", err)
	}

	// const 块内的常量声明：行首缩进 + CodeXxx = 数字（注释行以 // 开头不匹配，
	// messages map 的 CodeXxx: 键是冒号不匹配）
	constRe := regexp.MustCompile(`(?m)^\s*(Code[A-Za-z0-9]+)\s*=\s*(\d+)`)
	// error.thrift 注释清单：行首 // + 数字（含 "1xxxx" 段头误捕为 1，无害）
	docRe := regexp.MustCompile(`(?m)^//\s*(\d+)`)

	codes := map[int]string{} // 码 → 常量名
	for _, m := range constRe.FindAllStringSubmatch(string(constSrc), -1) {
		n, err := strconv.Atoi(m[2])
		if err != nil {
			t.Fatalf("解析常量 %s 的值 %q: %v", m[1], m[2], err)
		}
		codes[n] = m[1]
	}
	if len(codes) == 0 {
		t.Fatal("未从 errcode.go 解析到任何常量，正则疑似失效")
	}

	documented := map[int]bool{}
	for _, m := range docRe.FindAllStringSubmatch(string(thriftSrc), -1) {
		n, err := strconv.Atoi(m[1])
		if err != nil {
			t.Fatalf("解析 error.thrift 码 %q: %v", m[1], err)
		}
		documented[n] = true
	}
	if len(documented) == 0 {
		t.Fatal("未从 idl/error.thrift 解析到任何错误码注释，正则疑似失效")
	}

	var missing []string
	for code, name := range codes {
		if !documented[code] {
			missing = append(missing, name+"="+strconv.Itoa(code))
		}
	}
	sort.Strings(missing)
	if len(missing) > 0 {
		t.Errorf("idl/error.thrift 错误码清单缺少 %d 个 errcode 常量: %s\n"+
			"（补齐注释清单到与 errcode/errcode.go 一致）",
			len(missing), strings.Join(missing, ", "))
	}
}
