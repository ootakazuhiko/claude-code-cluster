# システム要件

Claude Code Clusterの動作に必要なハードウェア・ソフトウェア要件

## 🖥️ ハードウェア要件

### Central Coordinator（1台）

**最小要件**
- **CPU**: 4コア（8スレッド）
- **メモリ**: 16GB RAM
- **ストレージ**: 500GB SSD
- **ネットワーク**: Gigabit Ethernet
- **OS**: Ubuntu 22.04 LTS または CentOS 8+

**推奨要件**
- **CPU**: 8コア（16スレッド）
- **メモリ**: 32GB RAM
- **ストレージ**: 1TB NVMe SSD
- **ネットワーク**: Gigabit Ethernet
- **OS**: Ubuntu 22.04 LTS

### Claude Code Agent（2-10台）

**最小要件**
- **CPU**: 4コア（8スレッド）
- **メモリ**: 16GB RAM
- **ストレージ**: 500GB SSD
- **ネットワーク**: Gigabit Ethernet
- **OS**: Ubuntu 22.04 LTS または Windows 11 Pro

**推奨要件**
- **CPU**: 8コア（16スレッド）
- **メモリ**: 32GB RAM
- **ストレージ**: 1TB NVMe SSD
- **ネットワーク**: Gigabit Ethernet + Wi-Fi 6
- **GPU**: NVIDIA GTX 1660以上（オプション、AI推論高速化用）
- **OS**: Ubuntu 22.04 LTS

## 🌐 ネットワーク要件

### 基本ネットワーク構成

```
Internet
    │
    ▼
┌─────────────────┐
│   Router/FW     │
│ 192.168.1.1     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│   L2 Switch     │
│                 │
└─────────┬───────┘
          │
    ┌─────┼─────┐
    ▼     ▼     ▼
┌────────┐ ┌────────┐ ┌────────┐
│Coord.  │ │Agent-1 │ │Agent-2 │
│.100    │ │.101    │ │.102    │
└────────┘ └────────┘ └────────┘
```

### IPアドレス設計

**固定IPアドレス（推奨）**
- Coordinator: `192.168.1.100`
- Agent-001: `192.168.1.101`
- Agent-002: `192.168.1.102`
- Agent-003: `192.168.1.103`
- ...
- Agent-010: `192.168.1.110`

### ポート要件

**Coordinator**
- `8080/tcp`: Coordinator API
- `6379/tcp`: Redis
- `5432/tcp`: PostgreSQL
- `9090/tcp`: Prometheus
- `3000/tcp`: Grafana Dashboard
- `22/tcp`: SSH

**Agent（各台）**
- `8081/tcp`: Agent API
- `9091/tcp`: Prometheus Node Exporter
- `22/tcp`: SSH

### 帯域幅要件

- **最小**: 100Mbps（共有）
- **推奨**: 1Gbps（専用）
- **外部接続**: 50Mbps以上（Claude API/GitHub API用）

## 💻 ソフトウェア要件

### 共通要件（全PC）

**基本OS**
- Ubuntu 22.04 LTS（推奨）
- CentOS Stream 8+
- Windows 11 Pro（Agent のみ）

**必須ソフトウェア**
```bash
# システム基盤
- systemd
- OpenSSH Server
- curl, wget, unzip
- git 2.30+

# 開発環境
- Python 3.11+
- Node.js 20 LTS
- Docker 24.0+
- Docker Compose v2

# 監視
- Prometheus Node Exporter
- systemd journal
```

### Coordinator専用要件

**データベース**
- PostgreSQL 15+
- Redis 7+

**コンテナオーケストレーション**
- Docker Compose
- Portainer（オプション）

**監視システム**
- Prometheus
- Grafana
- AlertManager

### Agent専用要件

**開発ツール**
```bash
# Python環境
- uv (Python package manager)
- PyEnv（複数バージョン管理）

# Node.js環境
- npm/yarn
- nvm（複数バージョン管理）

# その他開発ツール
- make
- gcc/clang
- sqlite3
```

**言語固有要件**
```bash
# Backend Specialist
- Python 3.11+
- PostgreSQL client
- Redis client

# Frontend Specialist  
- Node.js 20 LTS
- Chrome/Chromium（テスト用）

# Testing Specialist
- Python 3.11+
- Node.js 20 LTS
- Selenium WebDriver

# DevOps Specialist
- Ansible
- Terraform（オプション）
- kubectl（オプション）
```

## 🔐 セキュリティ要件

### 認証・認可

**必須設定**
- SSH Key認証（パスワード認証無効化）
- sudo権限の制限
- ファイアウォール設定

**推奨設定**
- VPN接続（外部からのアクセス時）
- 証明書ベース認証
- 多要素認証（MFA）

### ネットワークセキュリティ

**ファイアウォール設定例**
```bash
# Coordinator
ufw allow 22/tcp    # SSH
ufw allow 8080/tcp  # API
ufw allow 3000/tcp  # Grafana
ufw allow from 192.168.1.0/24 to any port 5432  # PostgreSQL
ufw allow from 192.168.1.0/24 to any port 6379  # Redis

# Agent
ufw allow 22/tcp    # SSH
ufw allow 8081/tcp  # Agent API
ufw allow from 192.168.1.100 to any port 8081   # Coordinator only
```

### データ保護

**暗号化要件**
- ディスク暗号化（LUKS/BitLocker）
- 通信暗号化（TLS 1.3）
- 認証情報暗号化（HashiCorp Vault推奨）

## 📊 パフォーマンス要件

### 応答時間

| 操作 | 目標時間 | 最大許容時間 |
|------|----------|--------------|
| Agent登録 | < 1秒 | 5秒 |
| タスク割り当て | < 2秒 | 10秒 |
| Claude API呼び出し | < 30秒 | 120秒 |
| Git操作 | < 10秒 | 60秒 |
| PR作成 | < 5秒 | 30秒 |

### スループット

| メトリクス | 最小値 | 目標値 |
|------------|--------|--------|
| 同時タスク実行数 | 3 | 10 |
| 1時間あたりPR作成数 | 5 | 20 |
| Agent稼働率 | 80% | 95% |

### リソース使用率

**Coordinator**
- CPU使用率: < 70%
- メモリ使用率: < 80%
- ディスク使用率: < 85%

**Agent**
- CPU使用率: < 80%（アイドル時 < 20%）
- メモリ使用率: < 70%
- ディスク使用率: < 90%

## 📈 拡張性要件

### 水平スケーリング

**Agent追加**
- 最大10台まで線形スケーリング
- 新Agent追加時のダウンタイム: 0秒
- 自動負荷分散

**リソーススケーリング**
- Coordinatorの垂直スケーリング対応
- PostgreSQL/Redisの分離・クラスタ化対応

### 可用性

**目標稼働率**
- システム全体: 99.5%（月間3.6時間以下のダウンタイム）
- 個別Agent: 99.0%（月間7.2時間以下のダウンタイム）

**障害復旧**
- Agent障害時: 自動フェイルオーバー
- Coordinator障害時: 手動復旧（15分以内）

## ✅ 環境検証チェックリスト

### 事前確認

```bash
# ハードウェア確認
- [ ] CPU コア数 ≥ 4
- [ ] メモリ ≥ 16GB
- [ ] ディスク空き容量 ≥ 500GB
- [ ] ネットワーク接続確認

# ソフトウェア確認  
- [ ] OS バージョン確認
- [ ] Python 3.11+ インストール
- [ ] Docker インストール・動作確認
- [ ] Git 設定完了

# ネットワーク確認
- [ ] 各PC間の通信確認
- [ ] インターネット接続確認
- [ ] DNS解決確認
- [ ] ファイアウォール設定確認

# セキュリティ確認
- [ ] SSH Key認証設定
- [ ] sudo権限設定
- [ ] ファイアウォール設定
```

### 性能検証

```bash
# CPU性能テスト
sysbench cpu --threads=4 run

# メモリ性能テスト  
sysbench memory --memory-total-size=10G run

# ディスク性能テスト
sysbench fileio --file-test-mode=seqwr run

# ネットワーク性能テスト
iperf3 -s  # サーバー側
iperf3 -c <server-ip>  # クライアント側
```

---

この要件を満たすことで、Claude Code Clusterの安定動作が保証されます。