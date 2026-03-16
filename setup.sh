#!/bin/bash
# learn-repo skill 설치 스크립트
# 프로젝트의 skills/ 디렉토리를 ~/.claude/skills/ 에 심링크로 연결한다

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"

echo "🔗 learn-repo skill 설치 중..."

# ~/.claude/skills/ 없으면 생성
mkdir -p "$CLAUDE_SKILLS_DIR"

# skills/ 하위 디렉토리마다 심링크 생성
for skill_dir in "$PROJECT_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$CLAUDE_SKILLS_DIR/$skill_name"

  if [ -L "$target" ]; then
    rm "$target"
    echo "  ↻  $skill_name (기존 심링크 교체)"
  elif [ -d "$target" ]; then
    echo "  ⚠  $skill_name: 이미 디렉토리가 존재합니다 → $target"
    echo "     수동으로 삭제 후 다시 실행하세요: rm -rf $target"
    continue
  fi

  ln -s "$skill_dir" "$target"
  echo "  ✅ $skill_name → $target"
done

echo ""
echo "설치 완료! Claude Code에서 /learn-repo 로 사용하세요."
