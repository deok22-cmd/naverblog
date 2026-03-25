#!/bin/bash
# ============================================================
# 최초 1회 실행: 환경 설정 & cron 등록
# 사용법: bash setup.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}======================================================"
echo "  블로그 자동생성 환경 설정"
echo -e "======================================================${NC}"

# ── 1. Node.js 확인 ─────────────────────────────────────────
echo -e "\n${YELLOW}[1/5] Node.js 확인...${NC}"
if ! command -v node &> /dev/null; then
  echo -e "${RED}Node.js가 설치되어 있지 않습니다.${NC}"
  echo "설치: https://nodejs.org (LTS 버전 권장)"
  exit 1
fi
NODE_VER=$(node --version)
echo "✅ Node.js $NODE_VER"

# ── 2. Claude Code 확인 ─────────────────────────────────────
echo -e "\n${YELLOW}[2/5] Claude Code 확인...${NC}"
if ! command -v claude &> /dev/null; then
  echo "Claude Code 설치 중..."
  npm install -g @anthropic-ai/claude-code
fi
CLAUDE_VER=$(claude --version 2>/dev/null || echo "설치됨")
echo "✅ Claude Code $CLAUDE_VER"

# ── 3. Git 설정 확인 ────────────────────────────────────────
echo -e "\n${YELLOW}[3/5] Git 설정 확인...${NC}"
if ! command -v git &> /dev/null; then
  echo -e "${RED}Git이 설치되어 있지 않습니다.${NC}"
  exit 1
fi

GIT_USER=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -z "$GIT_USER" ] || [ -z "$GIT_EMAIL" ]; then
  echo -e "${YELLOW}Git 사용자 정보를 입력하세요:${NC}"
  read -p "이름: " GIT_NAME_INPUT
  read -p "이메일: " GIT_EMAIL_INPUT
  git config --global user.name "$GIT_NAME_INPUT"
  git config --global user.email "$GIT_EMAIL_INPUT"
fi
echo "✅ Git 사용자: $(git config --global user.name)"

# ── 4. GitHub 인증 확인 ─────────────────────────────────────
echo -e "\n${YELLOW}[4/5] GitHub 인증 방법 선택${NC}"
echo ""
echo "아래 두 가지 방법 중 하나를 선택하세요:"
echo ""
echo "  방법 A — SSH 키 (권장)"
echo "    1) ssh-keygen -t ed25519 -C 'your@email.com'"
echo "    2) cat ~/.ssh/id_ed25519.pub  (공개키 복사)"
echo "    3) GitHub → Settings → SSH Keys → New SSH Key 에 붙여넣기"
echo "    4) git remote set-url origin git@github.com:deok22-cmd/naverblog.git"
echo ""
echo "  방법 B — Personal Access Token"
echo "    1) GitHub → Settings → Developer settings → Tokens (classic)"
echo "    2) repo 권한 체크 후 토큰 생성"
echo "    3) git config --global credential.helper store"
echo "    4) 최초 push 시 토큰을 비밀번호로 입력"
echo ""
read -p "GitHub 인증 설정을 완료했으면 Enter를 누르세요..."

# ── 5. cron 등록 ────────────────────────────────────────────
echo -e "\n${YELLOW}[5/5] cron 등록 (매일 새벽 4시)...${NC}"

GENERATE_SCRIPT="$SCRIPT_DIR/generate_blog.sh"
chmod +x "$GENERATE_SCRIPT"

# 기존 cron에서 이 스크립트 제거 후 재등록
CRON_JOB="0 4 * * * $GENERATE_SCRIPT >> $SCRIPT_DIR/logs/cron.log 2>&1"
( crontab -l 2>/dev/null | grep -v "$GENERATE_SCRIPT"; echo "$CRON_JOB" ) | crontab -

echo "✅ cron 등록 완료"
echo ""
crontab -l | grep "$GENERATE_SCRIPT"

# ── 폴더 구조 생성 ──────────────────────────────────────────
mkdir -p "$SCRIPT_DIR/output"
mkdir -p "$SCRIPT_DIR/logs"

# ── 완료 안내 ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}======================================================"
echo "✅ 설정 완료!"
echo "======================================================"
echo ""
echo "📁 프로젝트 구조:"
echo "   $SCRIPT_DIR/"
echo "   ├── CLAUDE.md          ← 블로그 운영 지침"
echo "   ├── generate_blog.sh   ← 메인 실행 스크립트"
echo "   ├── setup.sh           ← 이 파일 (최초 1회)"
echo "   ├── output/            ← 생성된 HTML 저장 위치"
echo "   │   └── YYMMDD/"
echo "   └── logs/              ← 실행 로그"
echo ""
echo "🕓 cron: 매일 새벽 4:00 자동 실행"
echo "🔧 즉시 테스트: bash generate_blog.sh"
echo -e "${NC}"
