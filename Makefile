.PHONY: help setup-sdad

help:
	@echo "利用可能なコマンド:"
	@echo "  make setup-sdad    - SDAD開発環境をセットアップ"

# SDAD (仕様駆動AI開発) セットアップ
setup-sdad:
	@echo "🚀 SDAD環境のセットアップを開始..."
	@echo ""
	@echo "1. Git Hooksの設定..."
	@git config core.hooksPath .githooks
	@chmod +x .githooks/pre-commit 2>/dev/null || true
	@echo "   ✅ Git Hooks有効化完了"
	@echo ""
	@echo "2. SDAD作業ディレクトリの作成..."
	@chmod +x scripts/sdad-phase-manager.sh 2>/dev/null || true
	@./scripts/sdad-phase-manager.sh init
	@echo "   ✅ 作業ディレクトリ作成完了"
	@echo ""
	@echo "3. GitHubラベルの作成..."
	@echo "   以下のコマンドを手動で実行してください:"
	@echo "   gh label create 'phase-1-discovery' --color '0E8A16'"
	@echo "   gh label create 'phase-2-documentation' --color '1D76DB'"
	@echo "   gh label create 'phase-3-validation' --color 'FBCA04'"
	@echo "   gh label create 'phase-4-generation' --color '5319E7'"
	@echo ""
	@echo "4. エージェントプロンプトの確認..."
	@ls -la docs/architecture/*.md 2>/dev/null || echo "   ⚠️  プロンプトファイルが見つかりません"
	@echo ""
	@echo "✨ SDAD環境のセットアップが完了しました！"
	@echo ""
	@echo "📚 次のステップ:"
	@echo "   1. docs/architecture/SDAD_CLAUDE_CODE_CLUSTER_INTEGRATION.md を参照"
	@echo "   2. make help でコマンド一覧を確認"
	@echo "   3. ./scripts/sdad-phase-manager.sh help でSDADコマンドを確認"