#!/usr/bin/env bash
#
# gen-errcode-baseline.sh — 从 errcode/errcode.go 的 const 表生成/校验 errcode/baseline.json
#
# 背景（缺口）：
#   errcode/errcode.go 是全站业务错误码的唯一真相源，但历史上**没有任何机器可读的
#   快照** ⇒「已发布的错误码只增不减、不改名、不改值」这条跨版本不变量无处断言：
#   有人把 10010 改成 10011、或把 CodeTooLarge 改名，仓内没有任何东西会变红，
#   而按旧语义编译进前端/其他仓的判据已经悄悄漂了。
#
# 本脚本把 const 表抽成 errcode/baseline.json（number → Go 常量名，数字升序）：
#   - 默认模式：重新生成并覆盖（幂等：同输入 ⇒ 逐字节同输出）
#   - --check  ：只比对「仓内文件 == 重新生成的结果」，不一致则退出码 1 并打印差异（CI 用）
#
# 断言口径：
#   - 只收录**恰好 5 位十进制**的错误码（10000/20001/…/90003），不含 CodeSuccess = 0
#   - 同一码值出现两次 ⇒ 直接判红退出（码值必须唯一，见 errcode/errcode_test.go）
#   - 一个码都没解析出来 ⇒ 判红退出（防「解析规则失效 ⇒ 生成空基线 ⇒ 门禁恒绿」）
#
# 负对照（怎么让它变红）：
#   把 errcode/errcode.go 里某个 5 位码改成别的 5 位值（例如 CodeTooLarge 10010 → 10019），
#   再跑 `bash scripts/gen-errcode-baseline.sh --check` ⇒ 退出码 1 并打印 JSON 差异；
#   跑默认模式则会改写 baseline.json ⇒ `git diff` 可见。
set -euo pipefail
cd "$(dirname "$0")/.."

# 排序/匹配一律按字节口径（幂等的前提：同输入必须产出逐字节相同的输出）。
export LC_ALL=C

SRC="errcode/errcode.go"
OUT="errcode/baseline.json"
MODE="write"

fail() {
  echo -e "\033[1;31m[ERROR]\033[0m ${1}" >&2
  exit 1
}

usage() {
  echo "用法: bash scripts/gen-errcode-baseline.sh [--check]" >&2
  echo "  无参数   重新生成并覆盖 ${OUT}" >&2
  echo "  --check  只校验 ${OUT} 与 ${SRC} 是否同步（不一致 ⇒ 退出码 1）" >&2
}

case "${1:-}" in
  --check) MODE="check" ;;
  "") ;;
  -h | --help)
    usage
    OK=1
    exit 0
    ;;
  *)
    echo "✗ 未知参数: ${1}" >&2
    usage
    exit 2
    ;;
esac

[ -f "${SRC}" ] || fail "找不到 ${SRC}（请在仓库根目录运行本脚本）"

WORK="$(mktemp -d)"
# EXIT trap 必须**保留脚本退出码**（成功哨兵形态）。
#   为什么：`trap 'rm -rf "$WORK"' EXIT` 的最后一条命令是 rm（成功）⇒ bash 用它的
#   退出码覆盖脚本状态 ⇒ 脚本**报错却 exit 0**（macOS bash 3.2 上未定义变量失败
#   尤其明显）⇒「本地 && 链假绿、CI 才红」。hub 的 check-shell-trap-exit-code.sh
#   门禁（射程含 contracts/scripts）会因此判红。
#   正确形态：跑完的位置置 OK=1；trap 里 rc≠0 ⇒ 原样保留；rc=0 且 OK≠1 ⇒
#   没跑到结尾却没留失败码 ⇒ 判失败。
OK=0
# shellcheck disable=SC2154 # WORK 在 trap 体内使用，shellcheck 看不见跨行的赋值
trap 'rc=$?; rm -rf "${WORK}"; if [ "$rc" -ne 0 ]; then exit "$rc"; fi; if [ "${OK:-0}" != 1 ]; then exit 1; fi; exit 0' EXIT

# 抽 const 表：只认 `CodeXxx = NNNNN` 这一形态（行首可有缩进，行尾可有注释）。
# 用 grep -E（macOS 的 BSD grep 不支持 BRE 交替 |），匹配与抽取各用一条 ERE。
grep -E '^[[:space:]]*Code[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*(//.*)?$' "${SRC}" |
  sed -E 's/^[[:space:]]*(Code[A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*([0-9]+).*/\1 \2/' >"${WORK}/all"

# 只保留恰好 5 位十进制的错误码（CodeSuccess = 0 不进基线）。
awk 'length($2) == 5 && $2 ~ /^[0-9]+$/ { print $1, $2 }' "${WORK}/all" >"${WORK}/codes"

total_all="$(wc -l <"${WORK}/all" | tr -d '[:space:]')"
total_codes="$(wc -l <"${WORK}/codes" | tr -d '[:space:]')"

# 解析规则失效（文件被改格式/改名）必须判红，否则会生成空基线让下游门禁恒绿。
[ "${total_all}" -gt 0 ] || fail "未从 ${SRC} 解析出任何常量（解析规则是否失效？请检查 const 表形态）"
[ "${total_codes}" -gt 0 ] || fail "未从 ${SRC} 解析出任何 5 位错误码（码形是否漂移？）"

# 码值必须唯一：重复即判红（错误码重复 ⇒ 前端无法区分两种语义）。
dup_codes="$(awk '{ print $2 }' "${WORK}/codes" | sort | uniq -d)"
if [ -n "${dup_codes}" ]; then
  echo "✗ 错误码值重复（同一码值被多个常量占用）:" >&2
  printf '%s\n' "${dup_codes}" | while read -r dup; do
    names="$(awk -v c="${dup}" '$2 == c { printf "%s ", $1 }' "${WORK}/codes")"
    echo "    ${dup} => ${names}" >&2
  done
  exit 1
fi

# 数字升序（5 位定长码 ⇒ 字典序与数值序一致，仍显式按数值列排）。
sort -k2,2n "${WORK}/codes" >"${WORK}/sorted"

# 渲染成稳定的 JSON（2 空格缩进，键按数字升序，末尾换行）。
awk -v total="${total_codes}" '
  BEGIN {
    print "{"
    print "  \"codes\": {"
  }
  {
    line = "    \"" $2 "\": \"" $1 "\""
    if (NR < total) {
      print line ","
    } else {
      print line
    }
  }
  END {
    print "  }"
    print "}"
  }
' "${WORK}/sorted" >"${WORK}/baseline.json"

if [ "${MODE}" = "check" ]; then
  [ -f "${OUT}" ] || fail "${OUT} 不存在，请先运行: bash scripts/gen-errcode-baseline.sh"
  if diff -u "${OUT}" "${WORK}/baseline.json" >"${WORK}/diff" 2>&1; then
    echo "✓ ${OUT} 与 ${SRC} 的 const 表同步（${total_codes} 条 5 位错误码）"
    OK=1
    exit 0
  fi
  echo "✗ ${OUT} 与 ${SRC} 的 const 表不同步，差异如下:" >&2
  cat "${WORK}/diff" >&2
  echo "请运行: bash scripts/gen-errcode-baseline.sh 更新后提交" >&2
  exit 1
fi

cp "${WORK}/baseline.json" "${OUT}"
echo "✓ 已生成 ${OUT}（${total_codes} 条 5 位错误码，数字升序）"
echo "  建议: git diff ${OUT} 检查后提交"
OK=1
