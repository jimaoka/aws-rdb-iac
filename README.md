# aws-rdb-iac

RDS MySQL / Aurora MySQL を管理する Terraform リポジトリ。

## ディレクトリ構成

```
aws-rdb-iac/
├── root.hcl                    # 共通設定 (remote_state + generate blocks)
├── .github/
│   ├── workflows/
│   │   ├── plan.yml            # PR 時: validate + plan
│   │   └── apply.yml           # main マージ時: apply + destroy
│   ├── actions/
│   │   └── setup-terragrunt/   # Terraform/Terragrunt インストール
│   │       └── action.yml
│   └── scripts/
│       └── parse-labels.sh     # PR ラベルから対象ディレクトリ算出
├── modules/
│   ├── aurora-mysql/           # Aurora MySQL モジュール
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── rds-mysql-cluster/      # RDS MySQL Multi-AZ DB Cluster モジュール
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rds-mysql-instance/     # RDS MySQL Multi-AZ Instance モジュール
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── aurora-mysql/               # Aurora MySQL クラスタ定義
│   └── aurora-test001/
│       ├── terragrunt.hcl      # include のみ
│       └── main.tf
├── rds-mysql-cluster/          # RDS MySQL Multi-AZ DB Cluster 定義
│   └── rds-cluster-test001/
│       ├── terragrunt.hcl
│       └── main.tf
└── rds-mysql-instance/         # RDS MySQL Multi-AZ Instance 定義
    └── rds-instance-test001/
        ├── terragrunt.hcl
        └── main.tf
```

## モジュール

### modules/aurora-mysql

Aurora MySQL クラスタを作成する。`aws_rds_cluster` + `aws_rds_cluster_instance` (1 writer + N reader) 構成。

**主な変数:**

| 変数名 | 型 | 必須 | 説明 |
|--------|------|------|------|
| `cluster_identifier` | string | Yes | クラスタ識別子 |
| `region` | string | Yes | AWS リージョン |
| `db_cluster_instance_class` | string | Yes | インスタンスクラス |
| `engine_version` | string | Yes | エンジンバージョン (例: `8.0.mysql_aurora.3.10.3`) |
| `db_subnet_group_name` | string | Yes | DB サブネットグループ名 |
| `read_replica_count` | number | No | リードレプリカ数 (default: 1) |
| `db_parameters` | list(object) | No | クラスタパラメータグループのパラメータ |
| `backtrack_window` | number | No | バックトラックウィンドウ秒数 (default: 0) |
| `master_username` | string | No | マスターユーザー名 (default: "admin") |

**Outputs:** `cluster_endpoint`, `cluster_reader_endpoint`, `cluster_port`, `security_group_id`, `cluster_instances`, `parameter_group_name`

### modules/rds-mysql-cluster

RDS MySQL Multi-AZ DB クラスタ (1 writer + 2 reader 内蔵) を作成する。`aws_rds_cluster` を使用。`read_replica_count` で追加リードレプリカを作成可能。

**主な変数:**

| 変数名 | 型 | 必須 | 説明 |
|--------|------|------|------|
| `cluster_identifier` | string | Yes | クラスタ識別子 |
| `region` | string | Yes | AWS リージョン |
| `db_cluster_instance_class` | string | Yes | インスタンスクラス |
| `engine_version` | string | Yes | エンジンバージョン (例: `8.4.8`) |
| `db_subnet_group_name` | string | Yes | DB サブネットグループ名 |
| `allocated_storage` | number | Yes | 割り当てストレージ (GiB) |
| `iops` | number | Yes | プロビジョンド IOPS |
| `read_replica_count` | number | No | 追加リードレプリカ数 (default: 0) |
| `storage_type` | string | No | ストレージタイプ (default: "io1") |
| `master_username` | string | No | マスターユーザー名 (default: "admin") |

**Outputs:** `cluster_endpoint`, `cluster_reader_endpoint`, `cluster_port`, `security_group_id`, `parameter_group_name`, `read_replica_endpoints`

### modules/rds-mysql-instance

RDS MySQL Multi-AZ Instance (`aws_db_instance` + `multi_az=true`) を作成する。`read_replica_count` でリードレプリカを作成可能。

**主な変数:**

| 変数名 | 型 | 必須 | 説明 |
|--------|------|------|------|
| `db_identifier` | string | Yes | DB インスタンス識別子 |
| `region` | string | Yes | AWS リージョン |
| `instance_class` | string | Yes | インスタンスクラス (例: `db.t4g.medium`) |
| `engine_version` | string | Yes | エンジンバージョン (例: `8.0.35`, `8.4.8`) |
| `db_subnet_group_name` | string | Yes | DB サブネットグループ名 |
| `allocated_storage` | number | Yes | 割り当てストレージ (GiB) |
| `read_replica_count` | number | No | リードレプリカ数 (default: 0) |
| `storage_type` | string | No | ストレージタイプ (default: "gp3") |
| `iops` | number | No | プロビジョンド IOPS (default: null) |
| `storage_throughput` | number | No | ストレージスループット MiBps, gp3用 (default: null) |
| `master_username` | string | No | マスターユーザー名 (default: "admin") |

**Outputs:** `db_instance_endpoint`, `db_instance_address`, `db_instance_port`, `security_group_id`, `parameter_group_name`, `read_replica_endpoints`

## 前提条件

- Terraform >= 1.5.0
- Terragrunt >= 0.55.0
- AWS Provider ~> 5.0
- VPC / サブネット情報が SSM Parameter Store (`/shared/dev/vpc/*`) に登録済みであること
- DB サブネットグループが別リポジトリ (network-tf) で作成済みであること

### CI/CD 用 (GitHub Actions)

- GitHub Actions OIDC プロバイダーが AWS IAM に登録済みであること
- IAM ロールが作成済みであること (trust policy: `repo:<owner>/<repo>:*`)
- GitHub リポジトリ変数 `AWS_ROLE_ARN` にロール ARN が設定されていること

## 使い方

### 新しい DB インスタンスを追加する

1. 対応するディレクトリ配下にサブディレクトリを作成する

```bash
# Aurora MySQL の場合
mkdir -p aurora-mysql/<cluster-name>

# RDS MySQL Multi-AZ DB Cluster の場合
mkdir -p rds-mysql-cluster/<cluster-name>

# RDS MySQL Multi-AZ Instance の場合
mkdir -p rds-mysql-instance/<db-name>
```

2. `terragrunt.hcl` を作成する（全環境共通）

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

3. `main.tf` を作成してモジュールを呼び出す（`variables.tf` / `versions.tf` はルートの `root.hcl` が自動生成）

**Aurora MySQL の場合:**

```hcl
module "<cluster-name>" {
  source = "../../modules/aurora-mysql"

  cluster_identifier        = "<cluster-name>"
  db_subnet_group_name      = "shared-dev-rds-db-subnet-group"
  region                    = var.aws_region
  db_cluster_instance_class = "db.t4g.medium"
  engine_version            = "8.0.mysql_aurora.3.10.3"
  read_replica_count        = 1

  backup_retention_period      = 7
  preferred_backup_window      = "18:00-19:00"
  preferred_maintenance_window = "sun:19:00-sun:20:00"

  db_parameters = []
}
```

**RDS MySQL Multi-AZ DB Cluster の場合:**

```hcl
module "<cluster-name>" {
  source = "../../modules/rds-mysql-cluster"

  cluster_identifier        = "<cluster-name>"
  db_subnet_group_name      = "shared-dev-rds-db-subnet-group"
  region                    = var.aws_region
  db_cluster_instance_class = "db.t4g.medium"
  engine_version            = "8.4.8"

  storage_type      = "io1"
  allocated_storage = 100
  iops              = 3000

  backup_retention_period      = 7
  preferred_backup_window      = "18:00-19:00"
  preferred_maintenance_window = "sun:19:00-sun:20:00"

  db_parameters = []
}
```

**RDS MySQL Multi-AZ Instance の場合:**

```hcl
module "<db-name>" {
  source = "../../modules/rds-mysql-instance"

  db_identifier        = "<db-name>"
  db_subnet_group_name = "shared-dev-rds-db-subnet-group"
  region               = var.aws_region
  instance_class       = "db.t4g.medium"
  engine_version       = "8.4.8"

  storage_type      = "gp3"
  allocated_storage = 20

  backup_retention_period      = 7
  preferred_backup_window      = "18:00-19:00"
  preferred_maintenance_window = "sun:19:00-sun:20:00"

  db_parameters = []
}
```

4. PR を作成してマージする

```bash
git checkout -b add-<cluster-name>
git add <engine>/<cluster-name>/
git commit -m "Add <cluster-name>"
git push origin add-<cluster-name>
# PR を作成 → CI が自動で plan を実行 → レビュー後マージで apply が実行される
```

ローカルで手動実行する場合:

```bash
cd <engine>/<cluster-name>
terragrunt init
terragrunt plan
terragrunt apply
```

### DB を削除する

1. 対象のクラスタディレクトリごと削除する

```bash
git checkout -b delete-<cluster-name>
rm -rf <engine>/<cluster-name>
git add -A
git commit -m "Delete <cluster-name>"
git push origin delete-<cluster-name>
# PR を作成 → CI が plan -destroy を実行 → マージで destroy が実行される
```

## CI/CD

GitHub Actions による PR ベースのワークフローで Terraform の変更を自動化している。

### ワークフロー

| ワークフロー | トリガー | 内容 |
|-------------|---------|------|
| `plan.yml` | PR to `main` (opened / synchronize / reopened / labeled) | 変更対象検出 → validate + plan → PR コメント → ラベル付き PR は自動マージ |
| `apply.yml` | push to `main` | 変更対象検出 → destroy (削除分) → apply (変更分) |

### 変更対象の検出 (ラベルベース)

PR に以下のラベルが両方付与されている場合のみ、ラベルから対象ディレクトリを算出して plan / apply を実行する:

- `type:<engine>` — エンジン名 (`aurora-mysql` / `rds-mysql-cluster` / `rds-mysql-instance`)
- `cluster:<name>` — クラスタ / インスタンス名

例: `type:rds-mysql-instance` + `cluster:rds-instance-test001` → `rds-mysql-instance/rds-instance-test001`

ラベルがない PR は plan / apply を実行しない。

### 自動マージ

`type:*` と `cluster:*` ラベルが付いた PR は、すべてのチェック（plan）が成功した後に `gh pr merge --squash --auto` で自動マージされる。ラベルなしの PR は plan / apply / 自動マージいずれも実行されない。

**リポジトリ設定の前提条件:**

- リポジトリ設定で **"Allow auto-merge"** を有効にする
- ブランチ保護ルールで `summary` ジョブを required status check に設定する

### AWS 認証

OIDC を使用。リポジトリ変数 `AWS_ROLE_ARN` に IAM ロール ARN を設定する。

## 設計メモ

- **DB 認証**: `manage_master_user_password = true` で AWS Secrets Manager による自動管理
- **VPC ID**: 各モジュール内で SSM Parameter Store (`/shared/dev/vpc/vpc-id`) から取得
- **セキュリティグループ**: モジュールがクラスタ/インスタンスごとに作成 (ingress ルールは呼び出し元で追加)
- **パラメータグループ family**: `engine_version` から自動導出
- **削除保護**: `deletion_protection = true` がデフォルトで有効
