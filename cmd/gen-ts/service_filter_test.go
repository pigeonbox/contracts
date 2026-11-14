package main

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"testing"
)

// 三道生成链「带 service IDL」过滤口径一致性守卫（issue #28）。
//
// gen-model.sh 的 grep 正则、本包 hasService、cmd/gen-openapi 的 hasService 此前
// 各写各的：脚本侧要求 service 名后同行跟 "{"，Go 侧只判前缀 ⇒
// `service Foo extends Bar {`（thrift 合法继承）或大括号换行会让脚本跳过该 IDL
// 而 Go 两道照常收录 ⇒ 三份产物对同一 IDL 不一致，且三道 CHECK 各自只对账自己
// 那份、同时全绿。
//
// 本测试用 scripts/gen-model.sh 里**真实的**正则跑 grep，与本包 hasService 对
// 同一批用例断言同真同假；cmd/gen-openapi 侧有同构测试用同一批用例 ⇒ 三方口径
// 任一漂移即红。
var grepQERe = regexp.MustCompile(`grep -qE '([^']+)'`)

func TestServiceFilterParity(t *testing.T) {
	pattern := shellFilterPattern(t)
	cases := map[string]bool{
		"service Foo {\n":             true,  // 常规
		"service Foo extends Bar {\n": true,  // issue #28 主触发：继承
		"service Foo\n{\n":            true,  // 大括号换行
		"  service Foo {\n":           true,  // 缩进
		"service\tFoo {\n":            true,  // tab 分隔
		"// service Foo {\n":          false, // // 注释
		"# service Foo {\n":           false, // # 注释
		"struct Foo {\n}\n":           false, // 纯 struct IDL
		"serviceFoo {\n":              false, // 非 service 关键字
		"services Foo {\n":            false, // 复数不误判
	}
	for src, want := range cases {
		if got := hasService(src); got != want {
			t.Errorf("hasService(%q) = %v, 期望 %v", src, got, want)
		}
		if got := shellHasService(t, pattern, src); got != want {
			t.Errorf("gen-model.sh grep(%q) = %v, 期望 %v", src, got, want)
		}
	}
}

// shellFilterPattern 从 scripts/gen-model.sh 抽取真实的过滤正则——脚本改判据而
// 不同步本测试时立刻红（正则出现次数必须恰为 1）。
func shellFilterPattern(t *testing.T) string {
	t.Helper()
	b, err := os.ReadFile("../../scripts/gen-model.sh")
	if err != nil {
		t.Fatalf("读取 scripts/gen-model.sh: %v", err)
	}
	m := grepQERe.FindAllStringSubmatch(string(b), -1)
	if len(m) != 1 {
		t.Fatalf("gen-model.sh 里 grep -qE 出现 %d 次（期望恰 1 次），过滤判据可能已迁移，请同步本测试", len(m))
	}
	return m[0][1]
}

// shellHasService 用抽出的正则跑真 grep（argv 直传，不经 shell 解释）。
func shellHasService(t *testing.T, pattern, src string) bool {
	t.Helper()
	f := filepath.Join(t.TempDir(), "case.thrift")
	if err := os.WriteFile(f, []byte(src), 0o644); err != nil {
		t.Fatalf("写临时 IDL: %v", err)
	}
	err := exec.Command("grep", "-qE", pattern, f).Run()
	if err == nil {
		return true
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) && ee.ExitCode() == 1 {
		return false
	}
	t.Fatalf("grep -qE 执行异常（pattern=%q）: %v", pattern, err)
	return false
}
