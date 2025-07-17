# 🚀 GitHub Actions最小コスト実装設計

## 📋 概要

Docker/サーバー不要の軽量なラベルベース処理システムをGitHub Actionsのみで実装します。

## 🎯 設計原則

### コスト最小化
- **GitHub Actions無料枠活用**: 2,000分/月の無料実行時間
- **外部サービス不要**: DB/Redis/監視ツール等は使用しない
- **サーバーレス**: 専用サーバー不要
- **ストレージ最小**: GitHubリポジトリ内で完結

### シンプルな実装
- **ワークフロー中心**: GitHub Actions Workflowで全処理
- **ステートレス**: 状態管理はGitHub Issues/PRのみ
- **設定ファイル不要**: ラベルとワークフローで制御

## 📦 システム構成

### 1. コアワークフロー

```yaml
# .github/workflows/label-processor.yml
name: Label-Based Issue Processor

on:
  issues:
    types: [opened, labeled, unlabeled, reopened]
  issue_comment:
    types: [created]

jobs:
  evaluate-labels:
    runs-on: ubuntu-latest
    outputs:
      should_process: ${{ steps.check.outputs.should_process }}
      processing_type: ${{ steps.check.outputs.processing_type }}
      priority: ${{ steps.check.outputs.priority }}
    
    steps:
      - name: Check Processing Labels
        id: check
        uses: actions/github-script@v7
        with:
          script: |
            const issue = context.issue;
            const labels = context.payload.issue.labels.map(l => l.name);
            
            // 除外ラベルチェック
            const excludeLabels = ['discussion', 'design', 'on-hold', 'manual-only'];
            if (labels.some(label => excludeLabels.includes(label))) {
              core.setOutput('should_process', 'false');
              return;
            }
            
            // 処理ラベルチェック
            const processingLabels = {
              'claude-code-ready': { type: 'general', priority: 'medium' },
              'claude-code-urgent': { type: 'general', priority: 'high' },
              'claude-code-backend': { type: 'backend', priority: 'medium' },
              'claude-code-frontend': { type: 'frontend', priority: 'medium' },
              'claude-code-testing': { type: 'testing', priority: 'medium' },
              'claude-code-infrastructure': { type: 'infrastructure', priority: 'medium' }
            };
            
            for (const [label, config] of Object.entries(processingLabels)) {
              if (labels.includes(label)) {
                core.setOutput('should_process', 'true');
                core.setOutput('processing_type', config.type);
                core.setOutput('priority', config.priority);
                return;
              }
            }
            
            core.setOutput('should_process', 'wait');

  process-issue:
    needs: evaluate-labels
    if: needs.evaluate-labels.outputs.should_process == 'true'
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
      
      - name: Add Processing Label
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              labels: ['claude-code-processing']
            });
      
      - name: Process Based on Type
        id: process
        run: |
          case "${{ needs.evaluate-labels.outputs.processing_type }}" in
            backend)
              echo "Processing backend issue..."
              # バックエンド処理ロジック
              ;;
            frontend)
              echo "Processing frontend issue..."
              # フロントエンド処理ロジック
              ;;
            testing)
              echo "Processing testing issue..."
              # テスト処理ロジック
              ;;
            *)
              echo "Processing general issue..."
              # 汎用処理ロジック
              ;;
          esac
      
      - name: Update Issue Status
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const success = '${{ steps.process.outcome }}' === 'success';
            
            // 処理中ラベル削除
            try {
              await github.rest.issues.removeLabel({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                name: 'claude-code-processing'
              });
            } catch (e) {}
            
            // 結果ラベル追加
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              labels: [success ? 'claude-code-completed' : 'claude-code-failed']
            });
            
            // コメント追加
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: success 
                ? '✅ Processing completed successfully!'
                : '❌ Processing failed. Please check the logs.'
            });

  handle-waiting:
    needs: evaluate-labels
    if: needs.evaluate-labels.outputs.should_process == 'wait'
    runs-on: ubuntu-latest
    
    steps:
      - name: Add Waiting Label
        uses: actions/github-script@v7
        with:
          script: |
            // 既存のclaude-codeラベルをチェック
            const labels = context.payload.issue.labels.map(l => l.name);
            const hasClaudeLabel = labels.some(l => l.startsWith('claude-code-'));
            
            if (!hasClaudeLabel) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                labels: ['claude-code-waiting']
              });
              
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body: '⏳ This issue is waiting for a processing label. Please add one of the following labels:\n' +
                      '- `claude-code-ready` - General processing\n' +
                      '- `claude-code-backend` - Backend specialized processing\n' +
                      '- `claude-code-frontend` - Frontend specialized processing\n' +
                      '- `claude-code-testing` - Testing specialized processing'
              });
            }
```

### 2. 専門処理ワークフロー

```yaml
# .github/workflows/backend-processor.yml
name: Backend Issue Processor

on:
  workflow_dispatch:
    inputs:
      issue_number:
        description: 'Issue number to process'
        required: true
        type: number

jobs:
  process-backend:
    runs-on: ubuntu-latest
    steps:
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Analyze and Process
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # バックエンド特化処理
          # APIドキュメント生成、コード分析など
```

### 3. 処理状況モニタリング

```yaml
# .github/workflows/daily-report.yml
name: Daily Processing Report

on:
  schedule:
    - cron: '0 9 * * *'  # 毎日9時
  workflow_dispatch:

jobs:
  generate-report:
    runs-on: ubuntu-latest
    steps:
      - name: Generate Report
        uses: actions/github-script@v7
        with:
          script: |
            const oneDayAgo = new Date(Date.now() - 24*60*60*1000).toISOString();
            
            // 処理済みIssue取得
            const processed = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: 'claude-code-completed',
              since: oneDayAgo,
              state: 'all'
            });
            
            // 失敗Issue取得
            const failed = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: 'claude-code-failed',
              since: oneDayAgo,
              state: 'all'
            });
            
            // レポート作成
            const report = `# 📊 Daily Processing Report
            
            **Date**: ${new Date().toLocaleDateString()}
            
            ## Summary
            - ✅ Processed: ${processed.data.length}
            - ❌ Failed: ${failed.data.length}
            - 🎯 Success Rate: ${(processed.data.length / (processed.data.length + failed.data.length) * 100).toFixed(1)}%
            
            ## Details
            ### Successfully Processed
            ${processed.data.map(i => `- #${i.number}: ${i.title}`).join('\n')}
            
            ### Failed Processing
            ${failed.data.map(i => `- #${i.number}: ${i.title}`).join('\n')}
            `;
            
            // Issue作成
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Daily Report - ${new Date().toLocaleDateString()}`,
              body: report,
              labels: ['report', 'automated']
            });
```

## 🏷️ ラベル管理

### ラベル作成ワークフロー

```yaml
# .github/workflows/setup-labels.yml
name: Setup Processing Labels

on:
  workflow_dispatch:

jobs:
  create-labels:
    runs-on: ubuntu-latest
    steps:
      - name: Create Labels
        uses: actions/github-script@v7
        with:
          script: |
            const labels = [
              { name: 'claude-code-ready', color: '0E8A16', description: 'Ready for automated processing' },
              { name: 'claude-code-urgent', color: 'D93F0B', description: 'Urgent automated processing' },
              { name: 'claude-code-backend', color: '1D76DB', description: 'Backend specialized processing' },
              { name: 'claude-code-frontend', color: '5319E7', description: 'Frontend specialized processing' },
              { name: 'claude-code-testing', color: 'FBCA04', description: 'Testing specialized processing' },
              { name: 'claude-code-infrastructure', color: 'C5DEF5', description: 'Infrastructure specialized processing' },
              { name: 'claude-code-waiting', color: 'BFD4F2', description: 'Waiting for processing label' },
              { name: 'claude-code-processing', color: '0052CC', description: 'Currently being processed' },
              { name: 'claude-code-completed', color: '0E8A16', description: 'Processing completed' },
              { name: 'claude-code-failed', color: 'B60205', description: 'Processing failed' }
            ];
            
            for (const label of labels) {
              try {
                await github.rest.issues.createLabel({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  ...label
                });
                console.log(`Created label: ${label.name}`);
              } catch (e) {
                console.log(`Label ${label.name} might already exist`);
              }
            }
```

## 💰 コスト分析

### GitHub Actions使用量

```yaml
想定使用量:
  1日あたり:
    - Issue処理: 50件 × 2分 = 100分
    - レポート生成: 1件 × 1分 = 1分
    - 合計: 101分/日
  
  月間使用量:
    - 101分 × 30日 = 3,030分
    - 無料枠: 2,000分
    - 超過分: 1,030分
    - 追加コスト: $8.24 (0.008$/分)

最適化による削減:
  - 条件付き実行で50%削減可能
  - 実質月額コスト: $4程度
```

### コスト削減戦略

```yaml
1. 条件付き実行:
   - 特定ラベルのみ処理
   - 営業時間内のみ実行
   - 重複処理の防止

2. 処理時間短縮:
   - 必要最小限の処理
   - キャッシュ活用
   - 並列処理の活用

3. 無料枠最大活用:
   - パブリックリポジトリは無制限
   - セルフホストランナー活用（既存PC）
```

## 🚀 実装手順

### 1. 初期セットアップ
```bash
# ワークフローファイル配置
mkdir -p .github/workflows
cp label-processor.yml .github/workflows/
cp daily-report.yml .github/workflows/
cp setup-labels.yml .github/workflows/

# ラベル作成実行
gh workflow run setup-labels.yml
```

### 2. テスト実行
```bash
# テストIssue作成
gh issue create --title "Test Issue" --label "claude-code-ready"

# 処理確認
gh issue view <issue-number>
```

### 3. 本番適用
```bash
# main ブランチにマージ
git add .github/workflows/
git commit -m "Add label-based processing workflows"
git push origin main
```

## 📊 メリット

### コスト面
- **初期費用**: $0
- **月額費用**: $0〜$5程度
- **インフラ不要**: サーバー、DB、監視ツール不要

### 運用面
- **メンテナンス最小**: GitHub管理のインフラ
- **自動スケーリング**: GitHub Actionsが自動処理
- **高可用性**: GitHubのSLAに準拠

### 開発面
- **実装シンプル**: YAMLファイルのみ
- **デバッグ容易**: GitHub UI上で確認
- **バージョン管理**: Gitで自動管理

## 🔧 カスタマイズ

### 処理ロジックの追加
```yaml
# カスタム処理の例
- name: Custom Processing
  run: |
    # 独自の処理スクリプト
    python scripts/process_issue.py \
      --issue "${{ github.event.issue.number }}" \
      --type "${{ needs.evaluate-labels.outputs.processing_type }}"
```

### 通知の追加
```yaml
# Slack通知の例
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Issue processing failed: #${{ github.event.issue.number }}'
```

この設計により、Dockerやサーバーを一切使用せず、GitHub Actionsのみで完全なラベルベース処理システムを実現できます。