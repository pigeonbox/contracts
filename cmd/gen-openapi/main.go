// gen-openapi — 从 idl/*.thrift 生成 OpenAPI 3.0 规范（swagger）。
//
// 与 hz 同源同真相：hz 消费 api.* 注解生成 router/handler 桩，本工具消费同一批
// 注解生成带完整 request/response schema 的 OpenAPI 3.0 规范，输出到
// openapi/openapi.json（随仓提交，core 经 go:embed 在 /openapi.json 服务）。
//
// 支持的注解（与 hz 语义一致）：
//   - 方法级: api.get / api.post / api.put / api.delete = "路径"（:param 风格）
//   - 字段级: api.path / api.query / api.header → parameters；api.body → JSON 请求体；
//     api.form → multipart 请求体
//
// 用法:
//
//	go run ./cmd/gen-openapi                # 生成 openapi/openapi.json
//	go run ./cmd/gen-openapi --check        # 只校验产物与 IDL 同步（CI 用）
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/cloudwego/thriftgo/parser"
)

const (
	idlDir     = "idl"
	outputPath = "openapi/openapi.json"
	specTitle  = "PigeonBox API"
	specDesc   = "由 contracts idl/*.thrift 经 cmd/gen-openapi 生成（勿手改）。" +
		"仅覆盖 IDL 治理域；customizedRegister 手写路由由 core 在运行时合并补充骨架。"
)

// httpMethodAnnotations 方法级 HTTP 动词注解（与 hz 一致）
var httpMethodAnnotations = []string{"api.get", "api.post", "api.put", "api.delete"}

func main() {
	check := flag.Bool("check", false, "校验 openapi/openapi.json 与 IDL 是否同步，不写出")
	flag.Parse()

	spec, err := BuildSpec(idlDir)
	if err != nil {
		fatal("%v", err)
	}
	out, err := json.MarshalIndent(spec, "", "  ")
	if err != nil {
		fatal("序列化规范: %v", err)
	}
	out = append(out, '\n')

	if *check {
		committed, err := os.ReadFile(outputPath)
		if err != nil {
			fatal("--check: 读取 %s: %v（先运行 go run ./cmd/gen-openapi 生成）", outputPath, err)
		}
		if string(committed) != string(out) {
			fatal("openapi/openapi.json 与 idl/ 不同步，请运行 `go run ./cmd/gen-openapi` 更新后提交")
		}
		fmt.Println("✓ openapi/openapi.json 与 idl/ 定义同步")
		return
	}

	if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
		fatal("创建输出目录: %v", err)
	}
	if err := os.WriteFile(outputPath, out, 0o644); err != nil {
		fatal("写出 %s: %v", outputPath, err)
	}
	fmt.Printf("✓ 已生成 %s（%d paths / %d schemas）\n",
		outputPath, len(spec["paths"].(map[string]any)), len(spec["components"].(map[string]any)["schemas"].(map[string]any)))
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "[gen-openapi] ERROR: "+format+"\n", args...)
	os.Exit(1)
}

// ---------------------------------------------------------------- 构造核心

// BuildSpec 解析 dir 下全部带 service 的 IDL，构造 OpenAPI 3.0 规范。
// 导出以便单测直接消费。
func BuildSpec(dir string) (map[string]any, error) {
	files, err := listServiceIDLs(dir)
	if err != nil {
		return nil, err
	}

	// 解析全部根文件并展开 include 闭包（thriftgo 递归解析进 Includes.Reference）
	parsed := map[string]*parser.Thrift{} // filename → AST（按文件名去重）
	for _, f := range files {
		t, err := parser.ParseFile(f, []string{dir}, true)
		if err != nil {
			return nil, fmt.Errorf("解析 %s: %w", f, err)
		}
		collect(t, parsed)
	}

	// schema 命名空间：go namespace（缺失回退文件名基），跨域 struct 靠前缀防撞名
	ns := make(map[string]string, len(parsed)) // filename → namespace
	names := make([]string, 0, len(parsed))
	for fn := range parsed {
		names = append(names, fn)
	}
	sort.Strings(names)
	for _, fn := range names {
		ns[fn] = goNamespace(parsed[fn])
	}

	schemas := map[string]any{}
	// struct/union/exception/enum 全量入 components
	for _, fn := range names {
		t := parsed[fn]
		p := ns[fn]
		for _, s := range t.Structs {
			sc, err := structSchema(t, ns, s)
			if err != nil {
				return nil, fmt.Errorf("%s: %w", fn, err)
			}
			schemas[p+"."+s.Name] = sc
		}
		for _, u := range t.Unions {
			sc, err := structSchema(t, ns, u)
			if err != nil {
				return nil, fmt.Errorf("%s: %w", fn, err)
			}
			schemas[p+"."+u.Name] = sc
		}
		for _, e := range t.Exceptions {
			sc, err := structSchema(t, ns, e)
			if err != nil {
				return nil, fmt.Errorf("%s: %w", fn, err)
			}
			schemas[p+"."+e.Name] = sc
		}
		for _, e := range t.Enums {
			schemas[p+"."+e.Name] = enumSchema(e)
		}
	}

	paths := map[string]any{}
	for _, fn := range names {
		t := parsed[fn]
		scope := localScopeOf(t, ns)
		for _, svc := range t.Services {
			for _, m := range svc.Functions {
				if err := addOperation(paths, scope, svc.Name, m); err != nil {
					return nil, fmt.Errorf("%s.%s: %w", fn, m.Name, err)
				}
			}
		}
	}

	if len(paths) == 0 {
		return nil, fmt.Errorf("未从 %s 解析到任何路由（检查 api.get/post 注解）", dir)
	}

	return map[string]any{
		"openapi": "3.0.3",
		"info": map[string]any{
			"title":       specTitle,
			"description": specDesc,
			"version":     "contracts-idl",
		},
		"paths": paths,
		"components": map[string]any{
			"schemas": schemas,
		},
	}, nil
}

// ------------------------------------------------------------- IDL 收集/工具

// listServiceIDLs 带 service 定义的 IDL（与 gen-model.sh 同过滤规则）
func listServiceIDLs(dir string) ([]string, error) {
	patterns := []string{filepath.Join(dir, "*.thrift"), filepath.Join(dir, "http", "*.thrift")}
	var out []string
	for _, p := range patterns {
		fs, err := filepath.Glob(p)
		if err != nil {
			return nil, err
		}
		out = append(out, fs...)
	}
	var withSvc []string
	for _, f := range out {
		b, err := os.ReadFile(f)
		if err != nil {
			return nil, err
		}
		if hasService(string(b)) {
			withSvc = append(withSvc, f)
		}
	}
	if len(withSvc) == 0 {
		return nil, fmt.Errorf("%s 下未找到带 service 定义的 IDL", dir)
	}
	sort.Strings(withSvc)
	return withSvc, nil
}

func hasService(src string) bool {
	for _, line := range strings.Split(src, "\n") {
		t := strings.TrimSpace(line)
		if strings.HasPrefix(t, "//") || strings.HasPrefix(t, "#") {
			continue
		}
		if strings.HasPrefix(t, "service ") || strings.HasPrefix(t, "service\t") {
			return true
		}
	}
	return false
}

// collect 收集根文件与 include 闭包（按 Filename 去重）
func collect(t *parser.Thrift, into map[string]*parser.Thrift) {
	if t == nil {
		return
	}
	if _, ok := into[t.Filename]; ok {
		return
	}
	into[t.Filename] = t
	for _, inc := range t.Includes {
		collect(inc.Reference, into)
	}
}

// goNamespace 取 thrift go namespace 作 schema 前缀；缺失回退文件名基
func goNamespace(t *parser.Thrift) string {
	for _, ns := range t.Namespaces {
		if ns.Language == "go" && ns.Name != "" {
			if i := strings.LastIndex(ns.Name, "."); i >= 0 {
				return ns.Name[i+1:]
			}
			return ns.Name
		}
	}
	base := filepath.Base(t.Filename)
	return strings.TrimSuffix(base, filepath.Ext(base))
}

// alias include 引用别名（thrift 引用外部类型写作 `alias.Type`）
func alias(includePath string) string {
	base := filepath.Base(includePath)
	return strings.TrimSuffix(base, filepath.Ext(base))
}

// methodComment 取方法保留注释为 description
func methodComment(m *parser.Function) string {
	lines := []string{}
	for _, l := range strings.Split(m.ReservedComments, "\n") {
		l = strings.TrimSpace(l)
		l = strings.TrimPrefix(l, "//")
		l = strings.TrimPrefix(l, "#")
		l = strings.TrimSpace(l)
		if l != "" {
			lines = append(lines, l)
		}
	}
	return strings.Join(lines, "\n")
}

// convertPath hz ":param" 风格 → OpenAPI "{param}"
func convertPath(p string) string {
	segs := strings.Split(p, "/")
	for i, seg := range segs {
		if strings.HasPrefix(seg, ":") && len(seg) > 1 {
			segs[i] = "{" + seg[1:] + "}"
		}
	}
	return strings.Join(segs, "/")
}

// fieldAnnValue 取字段注解第一个值（无则空串）
func fieldAnnValue(f *parser.Field, key string) string {
	for _, ann := range f.Annotations {
		if strings.EqualFold(ann.Key, key) && len(ann.Values) > 0 {
			return ann.Values[0]
		}
	}
	return ""
}

// ------------------------------------------------------------ schema 构造

// typeDef 作用域条目：名字 → 定义处（namespace 前缀 + struct 定义指针 / typedef 别名）
type typeDef struct {
	ns string
	// st struct 定义指针（enum/typedef 无此字段）
	st *parser.StructLike
	// aliasType typedef 指向的原类型（仅 typedef 条目非 nil，与 gen-ts 同构）
	aliasType *parser.Type
}

// typeSchema thrift 类型 → OpenAPI schema。
// 注意：thriftgo parser 的原始 AST 不做类型语义解析（所有类型引用的 Category
// 均为 Constant），因此本函数以 TypeName 为主判据（标量按名、容器按前缀），
// 其余视为命名类型（struct/enum/typedef）经 scope 解析：typedef 展开原类型
// （与 gen-ts 同口径），其余产出 $ref；解析失败**报错**而非静默空 schema
// （issue #29：空 schema 会让 /openapi.json 与前端类型面对同一字段给出不一致契约）。
func typeSchema(scope map[string]typeDef, t *parser.Type) (map[string]any, error) {
	if t == nil {
		return map[string]any{}, nil
	}
	switch t.GetName() {
	case "bool":
		return map[string]any{"type": "boolean"}, nil
	case "byte", "i16", "i32":
		return map[string]any{"type": "integer"}, nil
	case "i64":
		return map[string]any{"type": "integer", "format": "int64"}, nil
	case "double":
		return map[string]any{"type": "number", "format": "double"}, nil
	case "string", "binary":
		return map[string]any{"type": "string"}, nil
	}
	name := t.GetName()
	// 容器判据用结构化字段(KeyType/ValueType):原始 AST 的 Category 未分类
	// (恒为 Constant),GetName 对容器只返回裸名("list"/"map",无泛型后缀),
	// 按名字形态匹配会漏判并产出空 schema
	if t.KeyType != nil { // map
		v, err := typeSchema(scope, t.ValueType)
		if err != nil {
			return nil, err
		}
		return map[string]any{"type": "object", "additionalProperties": v}, nil
	}
	if t.ValueType != nil { // list/set
		v, err := typeSchema(scope, t.ValueType)
		if err != nil {
			return nil, err
		}
		return map[string]any{"type": "array", "items": v}, nil
	}
	// 命名类型（struct/enum/typedef 引用）：scope 查得到 → typedef 展开或 $ref；
	// 查不到 → 报错（issue #29，不再静默空 schema、不再拼可能悬空的 $ref）
	def, key, ok := resolveNamed(scope, t)
	if !ok {
		return nil, fmt.Errorf("无法解析类型引用 %q（未登记于作用域：本地/include 的 struct/union/exception/enum/typedef）", name)
	}
	if def.aliasType != nil {
		// typedef 直接展开原类型（与 gen-ts 同口径，产物不引入中间名）
		return typeSchema(scope, def.aliasType)
	}
	return map[string]any{"$ref": "#/components/schemas/" + def.ns + "." + lastSegment(key)}, nil
}

// resolveNamed 命名类型引用解析（与 gen-ts resolveNamed 同构）：include 引用按
// "alias.Name" 查，本地名直查；返回定义条目与解析所用 key（拼 $ref 用）。
func resolveNamed(scope map[string]typeDef, t *parser.Type) (typeDef, string, bool) {
	if t.Reference != nil && t.Reference.Name != "" {
		if d, ok := scope[t.Reference.Name]; ok {
			return d, t.Reference.Name, true
		}
	}
	if name := t.GetName(); name != "" {
		if d, ok := scope[name]; ok {
			return d, name, true
		}
	}
	return typeDef{}, "", false
}

func lastSegment(s string) string {
	if i := strings.LastIndex(s, "."); i >= 0 {
		return s[i+1:]
	}
	return s
}

// structSchema struct/union/exception → OpenAPI object schema
func structSchema(t *parser.Thrift, ns map[string]string, s *parser.StructLike) (map[string]any, error) {
	scope := localScopeOf(t, ns)
	props := map[string]any{}
	required := []string{}
	for _, f := range s.Fields {
		name := serializedFieldName(f)
		ps, err := typeSchema(scope, f.Type)
		if err != nil {
			return nil, fmt.Errorf("字段 %s.%s: %w", s.Name, name, err)
		}
		props[name] = ps
		// 默认 requiredness 的字段一律计入 required（2026-11-06 修：两个生成器
		// 对「未标注」的判定此前**相反**——本工具只在 == Required 时计入
		// required（未标注 ⇒ 可选），而 cmd/gen-ts 只在 == Optional 时加 "?"
		// （未标注 ⇒ 必填）⇒ 同一份 IDL 在 TS 与 OpenAPI 里给出相反的契约。
		// 统一口径：**只有显式 optional 才可缺省**，其余（required 与默认）皆必填。
		// 这样 TS 侧无需改动（现有类型已是该口径），OpenAPI 随之对齐。
		if f.Requiredness != parser.FieldType_Optional {
			required = append(required, name)
		}
	}
	out := map[string]any{"type": "object", "properties": props}
	if len(required) > 0 {
		out["required"] = required
	}
	return out, nil
}

// localScopeOf 文件级名字作用域（本地定义 + include 引用，含 typedef）→ 定义处条目
func localScopeOf(t *parser.Thrift, ns map[string]string) map[string]typeDef {
	m := map[string]typeDef{}
	p := ns[t.Filename]
	reg := func(name string, d *parser.StructLike) {
		m[name] = typeDef{ns: p, st: d}
	}
	for _, s := range t.Structs {
		reg(s.Name, s)
	}
	for _, s := range t.Unions {
		reg(s.Name, s)
	}
	for _, s := range t.Exceptions {
		reg(s.Name, s)
	}
	for _, e := range t.Enums {
		m[e.Name] = typeDef{ns: p}
	}
	for _, td := range t.Typedefs {
		// typedef 登记别名条目（与 gen-ts localScopeOf 对称，issue #29）：
		// typeSchema 命中 aliasType 时展开原类型，不产 $ref
		m[td.Alias] = typeDef{ns: p, aliasType: td.Type}
	}
	for _, inc := range t.Includes {
		if inc.Reference == nil {
			continue
		}
		ip := ns[inc.Reference.Filename]
		a := alias(inc.Path)
		for _, s := range inc.Reference.Structs {
			m[a+"."+s.Name] = typeDef{ns: ip, st: s}
		}
		for _, e := range inc.Reference.Enums {
			m[a+"."+e.Name] = typeDef{ns: ip}
		}
		for _, td := range inc.Reference.Typedefs {
			m[a+"."+td.Alias] = typeDef{ns: ip, aliasType: td.Type}
		}
	}
	return m
}

func enumSchema(e *parser.Enum) map[string]any {
	values, names := []string{}, []string{}
	for _, m := range e.Values {
		values = append(values, m.Name)
		names = append(names, m.Name)
	}
	return map[string]any{"type": "string", "enum": values, "x-enum-varnames": names}
}

// serializedFieldName 组件 schema 属性名：优先 api.body 注解值（本仓 envelope
// 统一 JSON 序列化语义），无注解回退字段名
func serializedFieldName(f *parser.Field) string {
	for _, key := range []string{"api.body", "api.form", "api.query", "api.path"} {
		if v := fieldAnnValue(f, key); v != "" {
			return v
		}
	}
	return f.Name
}

// addOperation service 方法 → OpenAPI operation（api.get/post/put/delete）
func addOperation(paths map[string]any, scope map[string]typeDef, svcName string, m *parser.Function) error {
	method, rawPath := "", ""
	for _, ann := range m.Annotations {
		key := strings.ToLower(ann.Key)
		for _, verb := range httpMethodAnnotations {
			if key == verb && len(ann.Values) > 0 {
				method = strings.TrimPrefix(verb, "api.")
				rawPath = ann.Values[0]
			}
		}
	}
	if method == "" {
		return nil // 非 HTTP 方法（RPC 占位等），跳过
	}

	op := map[string]any{
		"operationId": m.Name,
		"summary":     strings.ToUpper(method) + " " + rawPath,
		"tags":        []string{svcName},
		"responses": map[string]any{
			"200": map[string]any{"description": "成功（响应体见 envelope，code=0 表示成功）"},
		},
	}
	if note := methodComment(m); note != "" {
		op["description"] = note
	}

	// 请求模型：hz 惯例 = 单个 request struct 入参
	params := []any{}
	var jsonProps, formProps map[string]any
	var jsonRequired, formRequired []string
	if len(m.Arguments) > 0 && m.Arguments[0].Type != nil &&
		isNamedType(scope, m.Arguments[0].Type) {
		if def := lookupStructDef(scope, m.Arguments[0].Type); def != nil {
			for _, f := range def.Fields {
				fs, err := typeSchema(scope, f.Type)
				if err != nil {
					return fmt.Errorf("%s.%s: %w", def.Name, f.Name, err)
				}
				if name := fieldAnnValue(f, "api.path"); name != "" {
					params = append(params, map[string]any{
						"name": name, "in": "path", "required": true,
						"schema": fs,
					})
					continue
				}
				if name := fieldAnnValue(f, "api.query"); name != "" {
					pp := map[string]any{"name": name, "in": "query", "schema": fs}
					if f.Requiredness == parser.FieldType_Required {
						pp["required"] = true
					}
					params = append(params, pp)
					continue
				}
				// api.header → 请求头参数。不落到下面的 JSON body 分支：
				// 否则规范会告诉集成方「把密码放 JSON body」，而服务端读的是头
				// （取件密码走 X-Share-Password，见 idl/share.thrift GetShareReq）。
				if name := fieldAnnValue(f, "api.header"); name != "" {
					pp := map[string]any{"name": name, "in": "header", "schema": fs}
					if f.Requiredness == parser.FieldType_Required {
						pp["required"] = true
					}
					params = append(params, pp)
					continue
				}
				if name := fieldAnnValue(f, "api.form"); name != "" {
					if formProps == nil {
						formProps = map[string]any{}
					}
					formProps[name] = fs
					if f.Requiredness == parser.FieldType_Required {
						formRequired = append(formRequired, name)
					}
					continue
				}
				// 无注解字段默认 JSON body 语义（hz 默认 body）
				if jsonProps == nil {
					jsonProps = map[string]any{}
				}
				jn := fieldAnnValue(f, "api.body")
				if jn == "" {
					jn = f.Name
				}
				jsonProps[jn] = fs
				if f.Requiredness == parser.FieldType_Required {
					jsonRequired = append(jsonRequired, jn)
				}
			}
		}
	}

	if len(params) > 0 {
		op["parameters"] = params
	}
	content := map[string]any{}
	if jsonProps != nil {
		body := map[string]any{"type": "object", "properties": jsonProps}
		if len(jsonRequired) > 0 {
			body["required"] = jsonRequired
		}
		content["application/json"] = map[string]any{"schema": body}
	}
	if formProps != nil {
		body := map[string]any{"type": "object", "properties": formProps}
		if len(formRequired) > 0 {
			body["required"] = formRequired
		}
		content["multipart/form-data"] = map[string]any{"schema": body}
	}
	if len(content) > 0 {
		op["requestBody"] = map[string]any{"required": true, "content": content}
	}

	// 响应模型：方法返回 struct → $ref（本仓 Resp 结构即 envelope 本体），
	// typedef 返回则展开原类型；解析失败报错（issue #29，不再拼可能悬空的 $ref）
	if m.FunctionType != nil && isNamedType(scope, m.FunctionType) {
		resp, err := typeSchema(scope, m.FunctionType)
		if err != nil {
			return fmt.Errorf("返回类型: %w", err)
		}
		op["responses"] = map[string]any{
			"200": map[string]any{
				"description": "成功（响应体见 envelope，code=0 表示成功）",
				"content":     map[string]any{"application/json": map[string]any{"schema": resp}},
			},
		}
	}

	path := convertPath(rawPath)
	pm, ok := paths[path].(map[string]any)
	if !ok {
		pm = map[string]any{}
		paths[path] = pm
	}
	pm[method] = op
	return nil
}

// lookupStructDef 按 scope 解析 struct 引用 → 定义（请求体字段枚举用）

// isNamedType 命名类型（struct/enum/typedef 引用，含 thriftgo 原始 AST 未解析的 Constant 类别）
func isNamedType(scope map[string]typeDef, t *parser.Type) bool {
	switch t.Category {
	case parser.Category_Struct, parser.Category_Enum:
		return true
	case parser.Category_Constant:
		if _, ok := scope[t.GetName()]; ok {
			return true
		}
	}
	return false
}

// lookupStructDef 按 scope 解析 struct 引用 → 定义（请求体字段枚举用）
func lookupStructDef(scope map[string]typeDef, t *parser.Type) *parser.StructLike {
	name := t.GetName()
	if name == "" && t.Reference != nil {
		name = t.Reference.Name
	}
	if d, ok := scope[name]; ok && d.st != nil {
		return d.st
	}
	if t.Reference != nil && t.Reference.Name != "" {
		if d, ok := scope[t.Reference.Name]; ok && d.st != nil {
			return d.st
		}
	}
	return nil
}
