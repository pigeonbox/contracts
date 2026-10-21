package main

import (
	"encoding/json"
	"strings"
	"testing"
)

// TestBuildSpecOnRealIDL 用仓内真实 IDL 做生成质量守卫：
// 路径/方法来自 api.* 注解，schema 类型按字段注解与 thrift 类型映射，
// $ref 不允许悬空。IDL 变更导致本测试失败时，请重新生成 openapi.json 并确认
// 变更符合预期（这也是 CI 的 --check 同义校验的本仓内版本）。
func TestBuildSpecOnRealIDL(t *testing.T) {
	// 测试 cwd = 包目录，IDL 在仓根 idl/
	spec, err := BuildSpec("../../idl")
	if err != nil {
		t.Fatalf("BuildSpec: %v", err)
	}

	paths := spec["paths"].(map[string]any)
	schemas := spec["components"].(map[string]any)["schemas"].(map[string]any)

	// 路径规模守卫：IDL 治理域路由不应异常缩水
	if len(paths) < 50 {
		t.Fatalf("paths=%d，异常缩水（期望 ≥50，IDL 治理域全量应在此量级）", len(paths))
	}

	t.Run("路径与方法", func(t *testing.T) {
		for path, expect := range map[string]map[string]bool{
			"/admin/login":   {"post": true},
			"/user/login":    {"post": true},
			"/share/text/":   {"post": true},
			"/share/file/":   {"post": true},
			"/share/select/": {"get": true},
			"/qrcode/generate": {"post": true},
			"/qrcode/{id}":     {"get": true},
			"/preview/{code}":  {"get": true},
			"/chunk/upload/init/": {"post": true},
		} {
			ops, ok := paths[path].(map[string]any)
			if !ok {
				t.Errorf("路径 %s 缺失", path)
				continue
			}
			for m := range expect {
				if _, ok := ops[m]; !ok {
					t.Errorf("路径 %s 缺方法 %s", path, m)
				}
			}
		}
	})

	t.Run("请求体语义", func(t *testing.T) {
		// api.body → application/json；api.form → multipart/form-data
		f := paths["/share/file/"].(map[string]any)["post"].(map[string]any)["requestBody"].(map[string]any)["content"].(map[string]any)
		if _, ok := f["multipart/form-data"]; !ok {
			t.Error("/share/file/ 应为 multipart 请求体（api.form 注解）")
		}
		x := paths["/share/text/"].(map[string]any)["post"].(map[string]any)["requestBody"].(map[string]any)["content"].(map[string]any)
		if _, ok := x["application/json"]; !ok {
			t.Error("/share/text/ 应为 JSON 请求体（api.body 注解）")
		}
	})

	t.Run("path/query/header 参数", func(t *testing.T) {
		op := paths["/preview/{code}"].(map[string]any)["get"].(map[string]any)
		params := op["parameters"].([]any)
		var inPath, inHeader bool
		for _, p := range params {
			pm := p.(map[string]any)
			if pm["name"] == "code" && pm["in"] == "path" {
				inPath = true
			}
			if pm["name"] == "X-Share-Password" && pm["in"] == "header" {
				inHeader = true
			}
		}
		if !inPath || !inHeader {
			t.Errorf("preview 参数解析不完整: path=%v header=%v", inPath, inHeader)
		}
	})

	// 回归守卫：取件密码只走 X-Share-Password 头（2026-10-16 拍板，core v0.24.0
	// 落地）。规范里再出现 password query = 教集成方发已废通道——该通道服务端
	// 已不收（实测 401），且 URL 形态有访问日志/Referer 泄漏面。
	t.Run("密码不进 query 参数", func(t *testing.T) {
		for p, v := range paths {
			for m, op := range v.(map[string]any) {
				om, ok := op.(map[string]any)
				if !ok {
					continue
				}
				params, _ := om["parameters"].([]any)
				for _, pr := range params {
					pm := pr.(map[string]any)
					if pm["in"] == "query" && strings.Contains(strings.ToLower(pm["name"].(string)), "password") {
						t.Errorf("%s %s 的 password 仍在 query 参数里: %v", p, m, pm)
					}
				}
			}
		}
	})

	t.Run("$ref 不悬空", func(t *testing.T) {
		raw, _ := json.Marshal(spec)
		var m any
		_ = json.Unmarshal(raw, &m)
		var refs []string
		collectRefs(m, &refs)
		for _, r := range refs {
			if _, ok := schemas[r]; !ok {
				t.Errorf("悬空 $ref: #/components/schemas/%s", r)
			}
		}
		if len(refs) == 0 {
			t.Error("规范内无任何 $ref，schema 解析疑似失效")
		}
	})
}

func collectRefs(o any, out *[]string) {
	switch v := o.(type) {
	case map[string]any:
		for k, val := range v {
			if k == "$ref" {
				if s, ok := val.(string); ok && len(s) > len("#/components/schemas/") {
					*out = append(*out, s[len("#/components/schemas/"):])
				}
				continue
			}
			collectRefs(val, out)
		}
	case []any:
		for _, val := range v {
			collectRefs(val, out)
		}
	}
}
