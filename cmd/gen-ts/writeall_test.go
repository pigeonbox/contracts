package main

import (
	"os"
	"path/filepath"
	"testing"
)

// TestWriteAllRemovesResiduals 覆盖 issue #33：IDL 删除类型后重跑 gen-ts 必须
// 清掉残留 .d.ts，否则 --check 的「残留产物」报错与修复指引（重跑 gen-ts）
// 构成死循环——旧 writeAll 只写不删，跑提示里的命令永远修不好。
func TestWriteAllRemovesResiduals(t *testing.T) {
	dir := t.TempDir()
	mustWrite := func(name, content string) {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
			t.Fatalf("预置 %s: %v", name, err)
		}
	}
	mustWrite("stale.d.ts", "IDL 已删除类型的旧产物")
	mustWrite("keep.d.ts", "旧内容")
	mustWrite("notes.txt", "非 .d.ts 不该被动")

	files := map[string]string{
		"keep.d.ts":  "新内容",
		"index.d.ts": "barrel",
	}
	if err := writeAllTo(dir, files); err != nil {
		t.Fatalf("writeAllTo: %v", err)
	}

	if _, err := os.Stat(filepath.Join(dir, "stale.d.ts")); !os.IsNotExist(err) {
		t.Error("残留 stale.d.ts 未被清理（先清后写失效）")
	}
	if _, err := os.Stat(filepath.Join(dir, "notes.txt")); err != nil {
		t.Error("非 .d.ts 文件不应被清理")
	}
	b, err := os.ReadFile(filepath.Join(dir, "keep.d.ts"))
	if err != nil {
		t.Fatalf("读 keep.d.ts: %v", err)
	}
	if string(b) != "新内容" {
		t.Errorf("在册文件未更新: %q", b)
	}
	if _, err := os.Stat(filepath.Join(dir, "index.d.ts")); err != nil {
		t.Errorf("缺 index.d.ts: %v", err)
	}
}
