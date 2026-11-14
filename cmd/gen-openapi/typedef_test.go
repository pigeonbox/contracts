package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// TestTypedefInScope 覆盖 issue #29：gen-openapi 的 localScopeOf 此前不登记
// typedef ⇒ typedef 字段在 /openapi.json 里退化为 {} 空 schema，而 gen-ts 侧
// 正常展开 ⇒ 同一字段两侧契约不一致。修复后：本地 typedef 与 include 进来的
// typedef 都展开为原类型 schema，且解析失败报错（不再静默空 schema）。
func TestTypedefInScope(t *testing.T) {
	dir := t.TempDir()
	write := func(name, content string) {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
			t.Fatalf("写 %s: %v", name, err)
		}
	}
	// 无 service 的纯 typedef 文件：只能经 include 进入作用域
	write("base.thrift", `namespace go base

typedef i64 Timestamp
`)
	write("api.thrift", `include "base.thrift"

namespace go fixture

typedef string LocalId

struct TypedefReq {
    1: required LocalId local_id (api.body = "local_id"),
    2: required base.Timestamp inc_ts (api.body = "inc_ts"),
    3: required list<LocalId> ids (api.body = "ids"),
}

service Fixture {
    void ping(1: TypedefReq req) (api.post = "/fixture/ping")
}
`)

	spec, err := BuildSpec(dir)
	if err != nil {
		t.Fatalf("BuildSpec: %v", err)
	}
	paths := spec["paths"].(map[string]any)
	op, ok := paths["/fixture/ping"].(map[string]any)
	if !ok {
		t.Fatal("缺路径 /fixture/ping")
	}
	body := op["post"].(map[string]any)["requestBody"].(map[string]any)["content"].(map[string]any)["application/json"].(map[string]any)["schema"].(map[string]any)
	props := body["properties"].(map[string]any)

	cases := map[string]map[string]any{
		// 本地 typedef string → 展开为 string
		"local_id": {"type": "string"},
		// include 进来的 typedef i64 → 展开为 integer/int64（此前为 {} 空 schema）
		"inc_ts": {"type": "integer", "format": "int64"},
		// list<typedef> → items 也要展开
		"ids": {"type": "array", "items": map[string]any{"type": "string"}},
	}
	for field, want := range cases {
		got, ok := props[field]
		if !ok {
			t.Errorf("缺字段 %s", field)
			continue
		}
		gm := got.(map[string]any)
		if len(gm) == 0 {
			t.Errorf("字段 %s 仍是空 schema {}（typedef 未登记/未展开，issue #29 回归）", field)
			continue
		}
		for k, v := range want {
			if !reflect.DeepEqual(gm[k], v) {
				t.Errorf("字段 %s 的 %s = %#v, 期望 %#v", field, k, gm[k], v)
			}
		}
	}
}
