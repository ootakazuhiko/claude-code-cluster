#!/bin/bash
# SDAD Phase Manager - 各フェーズの自動化と検証

set -euo pipefail

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 現在のフェーズを取得
get_current_phase() {
    local issue_number=$1
    gh issue view "$issue_number" --json labels -q '.labels[].name' | grep -E "phase-[0-4]" | head -1 || echo "phase-0"
}

# フェーズゲートのチェック
check_phase_gate() {
    local phase=$1
    local feature=$2
    
    case $phase in
        "phase-1")
            # フィーチャーファイルの存在確認
            if [[ ! -f "features/${feature}.feature" ]]; then
                echo -e "${RED}Error: Feature file not found${NC}"
                return 1
            fi
            ;;
        "phase-2")
            # 仕様書の存在確認
            if [[ ! -f "docs/${feature}/spec_v1.0.md" ]]; then
                echo -e "${RED}Error: Specification not found${NC}"
                return 1
            fi
            ;;
        "phase-3")
            # テストファイルの存在確認
            if ! find tests -name "*${feature}*test*" | grep -q .; then
                echo -e "${RED}Error: Test files not found${NC}"
                return 1
            fi
            # Check prerequisites
            if [[ ! -d "backend" ]]; then
                echo -e "${RED}Error: 'backend' directory does not exist${NC}"
                return 1
            fi
            if ! command -v uv &> /dev/null; then
                echo -e "${RED}Error: 'uv' command not found. Please install it.${NC}"
                return 1
            fi
            # テストが失敗することを確認
            if cd backend && uv run pytest -k "$feature" 2>/dev/null; then
                echo -e "${RED}Error: Tests should fail in Phase 3${NC}"
                return 1
            fi
            ;;
        "phase-4")
            # Check prerequisites
            if [[ ! -d "backend" ]]; then
                echo -e "${RED}Error: 'backend' directory does not exist${NC}"
                return 1
            fi
            if ! command -v uv &> /dev/null; then
                echo -e "${RED}Error: 'uv' command not found. Please ensure it is installed and in your PATH.${NC}"
                return 1
            fi
            # テストが成功することを確認
            if ! (cd backend && uv run pytest -k "$feature"); then
                echo -e "${RED}Error: Tests should pass in Phase 4${NC}"
                return 1
            fi
            ;;
    esac
    
    echo -e "${GREEN}Phase gate check passed for $phase${NC}"
    return 0
}

# タスクパケットの生成
generate_task_packet() {
    local phase=$1
    local feature=$2
    local agent=$3
    local date=$(date +%Y%m%d)
    
    # Ensure the task-packets directory exists
    mkdir -p task-packets
    
    cat > "task-packets/ITDO-ERP2-${phase}-${feature}-${date}-${agent}.yaml" << EOF
Task_ID: ITDO-ERP2-${phase}-${feature}-${date}
Target_Agent: ${agent}
Phase: ${phase}
Feature: ${feature}
Created_At: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Status: pending

Input_Artifacts:
EOF

    case $phase in
        "phase-1")
            cat >> "task-packets/ITDO-ERP2-${phase}-${feature}-${date}-${agent}.yaml" << EOF
  - path: docs/design/02_要件定義書.md
    status: approved
  - path: features/${feature}_brief.md
    status: approved

Instructions: |
  フィーチャーブリーフと要件定義書を分析し、以下を作成してください：
  1. Gherkin形式のシナリオ（5-10個）
  2. エッジケースのリスト
  3. 受け入れ条件の明確化
  
  20人組織での利用を前提とし、過度に複雑な機能は除外してください。

Constraints:
  - 最小構成での実装を前提とする
  - 複雑な権限管理は不要
  - 既存の実装がある場合は活用方法を明記

Definition_of_Done:
  - [ ] features/${feature}.feature が作成されている
  - [ ] 全シナリオに Given/When/Then が明確に定義されている
  - [ ] エッジケースが網羅されている
EOF
            ;;
        "phase-2")
            cat >> "task-packets/ITDO-ERP2-${phase}-${feature}-${date}-${agent}.yaml" << EOF
  - path: features/${feature}.feature
    status: approved

Instructions: |
  承認されたフィーチャーファイルに基づき、担当領域の技術仕様を作成してください。
  
  ${agent}の担当:
$(
    case $agent in
        "CC01")
            echo "  - UI/UXデザイン（Figma不要、Markdownで記述）"
            echo "  - コンポーネント構成図"
            echo "  - 画面遷移フロー"
            ;;
        "CC02")
            echo "  - API仕様（OpenAPI 3.0形式）"
            echo "  - データモデル（SQLAlchemy 2.0）"
            echo "  - ビジネスロジックの設計"
            ;;
        "CC03")
            echo "  - デプロイメント構成"
            echo "  - CI/CDパイプライン設計"
            echo "  - 環境変数の定義"
            ;;
    esac
)

Constraints:
  - 最小構成を維持（オーバーエンジニアリング禁止）
  - 既存コンポーネントの再利用を優先
  - 20人組織に適したシンプルな設計

Definition_of_Done:
  - [ ] 技術仕様書が作成されている
  - [ ] 他エージェントとの整合性が取れている
  - [ ] 非機能要件が明確化されている
EOF
            ;;
        "phase-3")
            cat >> "task-packets/ITDO-ERP2-${phase}-${feature}-${date}-${agent}.yaml" << EOF
  - path: docs/${feature}/spec_v1.0.md
    status: approved
  - path: features/${feature}.feature
    status: approved

Instructions: |
  承認された仕様に基づき、失敗するテストを作成してください。
  
  ${agent}の担当:
$(
    case $agent in
        "CC01")
            echo "  - Vitestによるコンポーネントテスト"
            echo "  - React Testing Libraryによる統合テスト"
            echo "  - アクセシビリティテスト"
            ;;
        "CC02")
            echo "  - Pytestによるユニットテスト"
            echo "  - API統合テスト"
            echo "  - データベーステスト（SQLite）"
            ;;
    esac
)

Non_Functional_Requirements:
  - performance: レスポンス時間 200ms以内
  - coverage: 80%以上のカバレッジ
  - security: 基本的なバリデーション

Definition_of_Done:
  - [ ] 全シナリオに対応するテストが作成されている
  - [ ] テスト実行で全て失敗する（Red）
  - [ ] CI/CDで自動実行される
EOF
            ;;
        "phase-4")
            cat >> "task-packets/ITDO-ERP2-${phase}-${feature}-${date}-${agent}.yaml" << EOF
  - path: tests/
    status: approved
  - path: docs/${feature}/spec_v1.0.md
    status: approved

Instructions: |
  失敗しているテストを通すための最小限の実装を行ってください。
  TDDサイクル（Red → Green → Refactor）に従ってください。
  
  実装の優先順位：
  1. テストを通す最小限のコード
  2. リファクタリング（必要な場合のみ）
  3. パフォーマンス最適化（必要な場合のみ）

Constraints:
  - YAGNI原則の厳守
  - 既存コードの活用
  - コードの重複を避ける

Definition_of_Done:
  - [ ] 全テストがグリーン
  - [ ] リント/フォーマットチェック通過
  - [ ] 型チェック通過
  - [ ] コードレビューの準備完了
EOF
            ;;
    esac
    
    echo -e "${GREEN}Task packet generated: task-packets/ITDO-ERP2-${phase}-${feature}-${date}-${agent}.yaml${NC}"
}

# エージェントへのタスク割り当て
assign_task_to_agent() {
    local task_packet=$1
    local agent=$2
    local issue_title="[${agent}] $(basename "$task_packet" .yaml)"
    
    # GitHubイシューとして作成
    gh issue create \
        --title "$issue_title" \
        --body-file "$task_packet" \
        --label "agent-task,${agent}" \
        --assignee "@me"
    
    echo -e "${GREEN}Task assigned to ${agent}${NC}"
}

# メイン処理
main() {
    local command=${1:-help}
    
    case $command in
        "init")
            # 必要なディレクトリ作成
            mkdir -p task-packets features docs tests
            echo -e "${GREEN}SDAD workspace initialized${NC}"
            ;;
            
        "check")
            # 現在のフェーズ確認
            local issue=${2:-}
            if [[ -z $issue ]]; then
                echo -e "${RED}Usage: $0 check <issue_number>${NC}"
                exit 1
            fi
            local phase=$(get_current_phase "$issue")
            echo -e "Current phase: ${YELLOW}$phase${NC}"
            ;;
            
        "gate")
            # フェーズゲートチェック
            local phase=${2:-}
            local feature=${3:-}
            if [[ -z $phase ]] || [[ -z $feature ]]; then
                echo -e "${RED}Usage: $0 gate <phase> <feature>${NC}"
                exit 1
            fi
            check_phase_gate "$phase" "$feature"
            ;;
            
        "packet")
            # タスクパケット生成
            local phase=${2:-}
            local feature=${3:-}
            local agent=${4:-}
            if [[ -z $phase ]] || [[ -z $feature ]] || [[ -z $agent ]]; then
                echo -e "${RED}Usage: $0 packet <phase> <feature> <agent>${NC}"
                exit 1
            fi
            generate_task_packet "$phase" "$feature" "$agent"
            ;;
            
        "assign")
            # タスク割り当て
            local packet=${2:-}
            local agent=${3:-}
            if [[ -z $packet ]] || [[ -z $agent ]]; then
                echo -e "${RED}Usage: $0 assign <packet_file> <agent>${NC}"
                exit 1
            fi
            assign_task_to_agent "$packet" "$agent"
            ;;
            
        "status")
            # 全体ステータス確認
            echo -e "${YELLOW}=== SDAD Project Status ===${NC}"
            echo -e "\n${GREEN}Open Agent Tasks:${NC}"
            gh issue list --label "agent-task" --limit 10
            
            echo -e "\n${GREEN}Recent PRs:${NC}"
            gh pr list --limit 5
            
            echo -e "\n${GREEN}Phase Distribution:${NC}"
            for phase in phase-0 phase-1 phase-2 phase-3 phase-4; do
                count=$(gh issue list --label "$phase" --json id -q '. | length')
                echo "  $phase: $count issues"
            done
            ;;
            
        *)
            echo -e "${YELLOW}SDAD Phase Manager${NC}"
            echo ""
            echo "Usage:"
            echo "  $0 init                          - Initialize SDAD workspace"
            echo "  $0 check <issue>                 - Check current phase of an issue"
            echo "  $0 gate <phase> <feature>        - Check phase gate requirements"
            echo "  $0 packet <phase> <feature> <agent> - Generate task packet"
            echo "  $0 assign <packet> <agent>       - Assign task to agent"
            echo "  $0 status                        - Show project status"
            echo ""
            echo "Phases:"
            echo "  phase-0: Kickoff (Human only)"
            echo "  phase-1: Discovery"
            echo "  phase-2: Documentation"
            echo "  phase-3: Validation"
            echo "  phase-4: Generation"
            echo ""
            echo "Agents:"
            echo "  COORD: Coordinator"
            echo "  CC01: Frontend"
            echo "  CC02: Backend"
            echo "  CC03: Infrastructure"
            ;;
    esac
}

# 実行
main "$@"