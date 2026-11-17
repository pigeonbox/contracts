// errcode 包的仓内自检：把「错误码表」这条跨版本契约钉死。
//
// 背景（缺口）：
//
//	errcode/errcode.go 是全站业务错误码的唯一真相源，但除本文件外**没有任何测试守护**：
//	- const 表与 messages 文案表靠人手同步 —— 加了码忘了加文案时，Message() 静默回退兜底文案；
//	- 码值被复用/改名/改值时，仓内无人报警 ⇒ 按旧语义编译进前端与其他仓的判据悄悄漂移；
//	- 「已发布的错误码只增不减、不改名、不改值」这条跨版本不变量没有机器基线。
//
// 断言口径（分两组）：
//  1. 既有门禁 TestErrorThriftCoversErrcode（issue #32）：idl/error.thrift 的注释清单
//     必须覆盖 errcode.go 的全部枚举常量。
//  2. 本次新增（6.2.0 L2 契约底座）：
//     - const ⇄ messages 双向一致：每个常量都要有默认文案，每个文案键都必须是真常量；
//     - 码形：非 CodeSuccess 的码必须恰好 5 位十进制（^[0-9]{5}$），0 只允许 CodeSuccess 占用；
//     - 码值唯一、常量名唯一（重复 ⇒ 点名是哪几个常量）；
//     - messages 非兜底：不得为空串；兜底文案只允许出现在 CodeUnknown 上；
//     - baseline.json 与 const 表完全同步（键集合相等 + 同号常量名不变 ⇒ 防「码号被复用给别的语义」）。
//
// 实现口径：
//
//	新增断言用 go/ast 解析 errcode.go **源码**（而不是手抄一张常量表）：
//	手抄表本身会与源码漂移，而漂移正是要检出的缺陷 ⇒ 不能用它当断言基准。
//
// 负对照（怎么让它变红）：
//   - 删掉 messages 里任意一条 ⇒ TestMessagesCoverAllConsts 红，点名该常量与码值；
//   - 把某个 5 位码改成别的 5 位值（如 10010 → 10019）⇒ TestBaselineMatchesConstTable 红，
//     点名「基线记 10010 = CodeTooLarge，当前 10019 换成了谁」；
//   - 把两个常量的值改成相同 ⇒ TestConstValuesUnique 红，点名两个常量名；
//   - 把某个文案改成空串 ⇒ TestMessagesHaveNoFallback 红，点名该常量。
package errcode

import (
	"encoding/json"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
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

// ---------------------------------------------------------------------------
// 以下为 6.2.0 L2 契约底座：错误码表的结构与基线断言。
// ---------------------------------------------------------------------------

// codePattern 是 5 位错误码的码形判据（与 idl/error.thrift 的码段位规划一致）。
var codePattern = regexp.MustCompile(`^[0-9]{5}$`)

// codeEntry 是从 errcode.go 的 const 表解析出的一条常量。
type codeEntry struct {
	Name  string
	Value int
}

// srcTable 是 errcode.go 的结构化视图（const 表 + messages 文案表）。
type srcTable struct {
	Consts  []codeEntry
	Msgs    map[string]string
	MsgKeys []string // messages 键的源码顺序，仅用于报错可读性
}

// sourceFile 返回本包目录下某个文件的绝对路径。
// 用 runtime.Caller 定位，不依赖 go test 的工作目录。
func sourceFile(t *testing.T, name string) string {
	t.Helper()
	_, thisFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatalf("runtime.Caller 失败，无法定位本测试文件所在目录")
	}
	return filepath.Join(filepath.Dir(thisFile), name)
}

// parseErrcodeSource 解析 errcode.go，取出 const 表与 messages 文案表。
func parseErrcodeSource(t *testing.T) srcTable {
	t.Helper()
	path := sourceFile(t, "errcode.go")
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, path, nil, 0)
	if err != nil {
		t.Fatalf("解析 %s 失败: %v", path, err)
	}

	tbl := srcTable{Msgs: map[string]string{}}
	for _, decl := range f.Decls {
		gd, ok := decl.(*ast.GenDecl)
		if !ok {
			continue
		}
		switch gd.Tok {
		case token.CONST:
			for _, spec := range gd.Specs {
				vs, ok := spec.(*ast.ValueSpec)
				if !ok {
					continue
				}
				for i, name := range vs.Names {
					if i >= len(vs.Values) {
						continue
					}
					lit, ok := vs.Values[i].(*ast.BasicLit)
					if !ok || lit.Kind != token.INT {
						continue
					}
					v, err := strconv.Atoi(lit.Value)
					if err != nil {
						continue
					}
					tbl.Consts = append(tbl.Consts, codeEntry{Name: name.Name, Value: v})
				}
			}
		case token.VAR:
			for _, spec := range gd.Specs {
				vs, ok := spec.(*ast.ValueSpec)
				if !ok {
					continue
				}
				for i, name := range vs.Names {
					if name.Name != "messages" || i >= len(vs.Values) {
						continue
					}
					cl, ok := vs.Values[i].(*ast.CompositeLit)
					if !ok {
						continue
					}
					for _, elt := range cl.Elts {
						kv, ok := elt.(*ast.KeyValueExpr)
						if !ok {
							continue
						}
						key, ok := kv.Key.(*ast.Ident)
						if !ok {
							continue
						}
						val, ok := kv.Value.(*ast.BasicLit)
						if !ok || val.Kind != token.STRING {
							continue
						}
						s, err := strconv.Unquote(val.Value)
						if err != nil {
							continue
						}
						if _, dup := tbl.Msgs[key.Name]; !dup {
							tbl.MsgKeys = append(tbl.MsgKeys, key.Name)
						}
						tbl.Msgs[key.Name] = s
					}
				}
			}
		}
	}

	if len(tbl.Consts) == 0 {
		t.Fatalf("%s 里没解析到任何常量（解析规则失效？）", path)
	}
	if len(tbl.Msgs) == 0 {
		t.Fatalf("%s 里没解析到 messages 表（解析规则失效？）", path)
	}
	return tbl
}

// constNames 返回常量名集合。
func (tbl srcTable) constNames() map[string]bool {
	names := make(map[string]bool, len(tbl.Consts))
	for _, c := range tbl.Consts {
		names[c.Name] = true
	}
	return names
}

// sortedCodes 返回当前 const 表里的 5 位码（码值 → 常量名）。
func (tbl srcTable) sortedCodes() map[string]string {
	codes := map[string]string{}
	for _, c := range tbl.Consts {
		if c.Value == 0 || !codePattern.MatchString(strconv.Itoa(c.Value)) {
			continue // 码形非法由 TestConstTableShape 点名
		}
		codes[strconv.Itoa(c.Value)] = c.Name
	}
	return codes
}

// TestConstTableShape 断言码形：0 只允许 CodeSuccess 占用，其余必须是恰好 5 位十进制。
func TestConstTableShape(t *testing.T) {
	tbl := parseErrcodeSource(t)
	for _, c := range tbl.Consts {
		switch {
		case c.Value == 0:
			if c.Name != "CodeSuccess" {
				t.Errorf("常量 %s = 0：0 只允许 CodeSuccess 占用（成功码），请改用 5 位错误码", c.Name)
			}
		case !codePattern.MatchString(strconv.Itoa(c.Value)):
			t.Errorf("常量 %s = %d：码形非法。非成功码必须是恰好 5 位十进制（^[0-9]{5}$），例如 10016", c.Name, c.Value)
		}
	}
}

// TestConstValuesUnique 断言码值唯一：两个常量取同一个码 ⇒ 前端无法区分两种语义。
func TestConstValuesUnique(t *testing.T) {
	tbl := parseErrcodeSource(t)
	byValue := map[int][]string{}
	for _, c := range tbl.Consts {
		byValue[c.Value] = append(byValue[c.Value], c.Name)
	}
	values := make([]int, 0, len(byValue))
	for v := range byValue {
		values = append(values, v)
	}
	sort.Ints(values)
	for _, v := range values {
		names := byValue[v]
		if len(names) < 2 {
			continue
		}
		t.Errorf("码值 %d 被多个常量占用: %s —— 错误码必须唯一", v, strings.Join(names, ", "))
	}
}

// TestConstNamesUnique 断言常量名不重复。
func TestConstNamesUnique(t *testing.T) {
	tbl := parseErrcodeSource(t)
	seen := map[string]bool{}
	var dups []string
	for _, c := range tbl.Consts {
		if seen[c.Name] {
			dups = append(dups, c.Name)
			continue
		}
		seen[c.Name] = true
	}
	if len(dups) > 0 {
		t.Errorf("常量名重复定义: %s", strings.Join(dups, ", "))
	}
}

// TestMessagesCoverAllConsts 断言每个常量都有默认文案（漏写 ⇒ Message() 静默回退兜底文案）。
func TestMessagesCoverAllConsts(t *testing.T) {
	tbl := parseErrcodeSource(t)
	for _, c := range tbl.Consts {
		if _, ok := tbl.Msgs[c.Name]; !ok {
			t.Errorf("常量 %s（码值 %d）在 messages 表里没有默认文案: Message(%d) 会静默回退到兜底文案", c.Name, c.Value, c.Value)
		}
	}
}

// TestMessagesKeysAreConsts 断言 messages 表的每个键都是真常量（防止文案挂在不存在的码上）。
func TestMessagesKeysAreConsts(t *testing.T) {
	tbl := parseErrcodeSource(t)
	names := tbl.constNames()
	for _, key := range tbl.MsgKeys {
		if !names[key] {
			t.Errorf("messages 表的键 %q 不是任何常量名: 要么补上常量，要么删掉这条文案", key)
		}
	}
}

// TestMessagesRuntimeMatchesSource 断言运行时 messages 表与源码解析结果一致。
// 源码是真相源、运行时表是编译产物；两者不一致 = 「看着对、跑起来是另一套」的漂移。
func TestMessagesRuntimeMatchesSource(t *testing.T) {
	tbl := parseErrcodeSource(t)
	if len(messages) != len(tbl.Msgs) {
		t.Errorf("运行时 messages 表有 %d 条，源码解析出 %d 条", len(messages), len(tbl.Msgs))
	}
	for _, c := range tbl.Consts {
		want, ok := tbl.Msgs[c.Name]
		if !ok {
			continue // 缺文案已由 TestMessagesCoverAllConsts 点名
		}
		got, ok := messages[c.Value]
		if !ok {
			t.Errorf("运行时 messages 表缺码值 %d（常量 %s）", c.Value, c.Name)
			continue
		}
		if got != want {
			t.Errorf("码值 %d（%s）的运行时文案 %q 与源码文案 %q 不一致", c.Value, c.Name, got, want)
		}
	}
}

// TestMessageLookup 断言 Message() 按码值取到对应文案，未知码回退到兜底文案。
func TestMessageLookup(t *testing.T) {
	tbl := parseErrcodeSource(t)
	for _, c := range tbl.Consts {
		want := tbl.Msgs[c.Name]
		if got := Message(c.Value); got != want {
			t.Errorf("Message(%d)（%s）= %q，期望 %q", c.Value, c.Name, got, want)
		}
	}
	// 兜底文案就是 CodeUnknown 的文案（Message() 的实现如此）。
	fallback := tbl.Msgs["CodeUnknown"]
	if got := Message(987654); got != fallback {
		t.Errorf("Message(987654)（未知码）= %q，期望回退到 CodeUnknown 的文案 %q", got, fallback)
	}
}

// TestMessagesHaveNoFallback 断言文案表不是兜底表：不得为空，兜底文案只归 CodeUnknown。
func TestMessagesHaveNoFallback(t *testing.T) {
	tbl := parseErrcodeSource(t)
	fallback := tbl.Msgs["CodeUnknown"]
	if strings.TrimSpace(fallback) == "" {
		t.Fatalf("CodeUnknown 的兜底文案为空: 未知码将返回空串")
	}
	for _, key := range tbl.MsgKeys {
		msg := tbl.Msgs[key]
		if strings.TrimSpace(msg) == "" {
			t.Errorf("messages[%s] 是空文案: 前端会拿到空提示", key)
			continue
		}
		if key == "CodeUnknown" {
			continue
		}
		if msg == fallback {
			t.Errorf("messages[%s] = %q: 这是 Message() 的兜底文案，只有 CodeUnknown 可以用它，其它码必须给具体语义文案", key, msg)
		}
	}
}

// baselineFile 是 errcode/baseline.json 的结构（number → Go 常量名）。
type baselineFile struct {
	Codes map[string]string `json:"codes"`
}

// TestBaselineMatchesConstTable 断言基线与 const 表完全同步。
// 键集合相等 ⇒ 新增码必须重生成基线（不许只改代码不更新基线）；
// 同号常量名不变 ⇒ 码号不许被复用给别的语义（已发布的码只增不减、不改名、不改值）。
func TestBaselineMatchesConstTable(t *testing.T) {
	tbl := parseErrcodeSource(t)
	path := sourceFile(t, "baseline.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("读取基线 %s 失败: %v（请运行 bash scripts/gen-errcode-baseline.sh 生成）", path, err)
	}
	var bl baselineFile
	if err := json.Unmarshal(raw, &bl); err != nil {
		t.Fatalf("解析基线 %s 失败: %v", path, err)
	}
	if bl.Codes == nil {
		t.Fatalf("基线 %s 没有 codes 字段", path)
	}

	current := tbl.sortedCodes()

	// 1) 当前每个 5 位码都要在基线里，且常量名一致。
	for _, code := range sortedKeys(current) {
		name := current[code]
		blName, ok := bl.Codes[code]
		if !ok {
			t.Errorf("基线缺少码值 %s（当前常量 %s）: 请运行 bash scripts/gen-errcode-baseline.sh 重生成", code, name)
			continue
		}
		if blName != name {
			t.Errorf("码值 %s 的常量名漂移: 基线记 %q，当前是 %q —— 已发布的码不许改名或复用给别的语义", code, blName, name)
		}
	}

	// 2) 基线里的码不许消失（已发布的码只增不减）。
	for _, code := range sortedKeys(bl.Codes) {
		if _, ok := current[code]; !ok {
			t.Errorf("基线里的码值 %s（%s）已不在 const 表: 已发布的码不许删除", code, bl.Codes[code])
		}
	}

	// 3) 基线只收录 5 位错误码，不含 CodeSuccess = 0。
	if _, ok := bl.Codes["0"]; ok {
		t.Errorf("基线里不应包含 0（CodeSuccess）: 基线只收录 5 位错误码")
	}
}

// sortedKeys 返回 map 的键（按数值升序；非纯数字键按字典序排在后面），保证报错顺序稳定。
func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		ni, erri := strconv.Atoi(keys[i])
		nj, errj := strconv.Atoi(keys[j])
		if erri == nil && errj == nil {
			return ni < nj
		}
		return keys[i] < keys[j]
	})
	return keys
}
