#!/usr/bin/env bash

set -euo pipefail

BATCH_SIZE=50
PUSH=1
REMOTE="origin"
BRANCH=""
MESSAGE_PREFIX="batch upload"
STATE_FILE=".batch-upload.state"
DRY_RUN=0

usage() {
  cat <<'EOF'
用法:
  ./batch_upload.sh [选项]

选项:
  -s, --batch-size N       每批提交文件数（默认: 50）
  -m, --message-prefix STR 提交信息前缀（默认: "batch upload"）
      --no-push            只 commit 不 push
  -r, --remote NAME        远程名（默认: origin）
  -b, --branch NAME        目标分支（默认: 当前分支）
      --dry-run            预览将要提交的文件，不执行 add/commit/push
  -h, --help               显示帮助

说明:
  - 仅处理“尚未提交”的文件（已跟踪改动 + 未跟踪文件）。
  - 支持中断恢复：
    1) 已提交的批次不会重复提交；
    2) 若中断时已有 staged 文件，下次会优先提交这些 staged 文件；
    3) 批次序号会写入 .batch-upload.state 并自动续接。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--batch-size)
      BATCH_SIZE="$2"
      shift 2
      ;;
    -m|--message-prefix)
      MESSAGE_PREFIX="$2"
      shift 2
      ;;
    --no-push)
      PUSH=0
      shift
      ;;
    -r|--remote)
      REMOTE="$2"
      shift 2
      ;;
    -b|--branch)
      BRANCH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || [[ "$BATCH_SIZE" -le 0 ]]; then
  echo "错误: --batch-size 必须是正整数"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "错误: 当前目录不是 Git 仓库"
  exit 1
fi

if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
fi

if [[ -f "$STATE_FILE" ]]; then
  NEXT_BATCH="$(cat "$STATE_FILE")"
  if ! [[ "$NEXT_BATCH" =~ ^[0-9]+$ ]] || [[ "$NEXT_BATCH" -le 0 ]]; then
    NEXT_BATCH=1
  fi
else
  NEXT_BATCH=1
fi

save_next_batch() {
  printf '%s\n' "$NEXT_BATCH" > "$STATE_FILE"
}

print_batch_preview() {
  local count="$1"
  shift
  local files=("$@")
  echo "------"
  echo "批次 #$NEXT_BATCH, 文件数: $count"
  printf '  - %s\n' "${files[@]}"
}

push_if_needed() {
  if [[ "$PUSH" -eq 0 ]]; then
    return 0
  fi
  echo "推送到 $REMOTE/$BRANCH ..."
  git push "$REMOTE" "$BRANCH"
}

commit_staged_if_any() {
  local staged=()
  while IFS= read -r -d '' f; do
    staged+=("$f")
  done < <(git diff --cached --name-only -z)

  if [[ ${#staged[@]} -eq 0 ]]; then
    return 0
  fi

  print_batch_preview "${#staged[@]}" "${staged[@]}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] 检测到已 staged 文件，将在实际执行时先提交这批。"
    return 0
  fi

  git commit -m "$MESSAGE_PREFIX (part $NEXT_BATCH): ${#staged[@]} files"
  NEXT_BATCH=$((NEXT_BATCH + 1))
  save_next_batch
  push_if_needed
}

push_ahead_commits_first() {
  if [[ "$PUSH" -eq 0 ]]; then
    return 0
  fi

  if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    local ahead_count
    ahead_count="$(git rev-list --count "@{u}..HEAD")"
    if [[ "$ahead_count" -gt 0 ]]; then
      echo "检测到本地有 $ahead_count 个未推送提交，先尝试推送..."
      git push "$REMOTE" "$BRANCH"
    fi
  fi
}

collect_pending_files() {
  pending=()
  local f
  while IFS= read -r f; do
    [[ -n "$f" ]] && pending+=("$f")
  done < <(
    {
      git diff --name-only
      git diff --cached --name-only
      git ls-files --others --exclude-standard
    } | awk '!seen[$0]++'
  )
}

echo "开始批量上传：batch_size=$BATCH_SIZE, push=$PUSH, remote=$REMOTE, branch=$BRANCH"

push_ahead_commits_first
commit_staged_if_any

while true; do
  collect_pending_files

  if [[ ${#pending[@]} -eq 0 ]]; then
    echo "没有待提交文件，任务完成。"
    break
  fi

  batch=("${pending[@]:0:BATCH_SIZE}")
  print_batch_preview "${#batch[@]}" "${batch[@]}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] 以上为下一批将提交的文件。"
    break
  fi

  git add -- "${batch[@]}"
  git commit -m "$MESSAGE_PREFIX (part $NEXT_BATCH): ${#batch[@]} files"
  NEXT_BATCH=$((NEXT_BATCH + 1))
  save_next_batch
  push_if_needed
done
