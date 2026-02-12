# aws-rdb-iac

RDS MySQL / Aurora MySQL を管理する Terraform リポジトリ。

## ディレクトリ構成

```
jimaoka-db/
├── root.hcl                    # 共通設定 (generate blocks で versions.tf / variables.tf を自動生成)
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

4. 適用する

```bash
cd <engine>/<cluster-name>
terragrunt init
terragrunt plan
terragrunt apply
```

## 設計メモ

- **DB 認証**: `manage_master_user_password = true` で AWS Secrets Manager による自動管理
- **VPC ID**: 各モジュール内で SSM Parameter Store (`/shared/dev/vpc/vpc-id`) から取得
- **セキュリティグループ**: モジュールがクラスタ/インスタンスごとに作成 (ingress ルールは呼び出し元で追加)
- **パラメータグループ family**: `engine_version` から自動導出
- **削除保護**: `deletion_protection = true` がデフォルトで有効
