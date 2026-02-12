# CLAUDE.md

## プロジェクト概要

RDS MySQL / Aurora MySQL を管理する Terraform リポジトリ。

## ディレクトリ構成ルール

- `root.hcl` - ルート Terragrunt 設定 (`generate` ブロックで `versions.tf` / `variables.tf` を自動生成)
- `modules/` - 再利用可能な Terraform モジュール (直接 apply しない)
  - `aurora-mysql/` - Aurora MySQL モジュール
  - `rds-mysql-cluster/` - RDS MySQL Multi-AZ DB Cluster モジュール (`aws_rds_cluster`)
  - `rds-mysql-instance/` - RDS MySQL Multi-AZ Instance モジュール (`aws_db_instance`)
- `aurora-mysql/<cluster-name>/` - Aurora MySQL の各クラスタ定義 (ここで `terragrunt apply`)
- `rds-mysql-cluster/<cluster-name>/` - RDS MySQL Multi-AZ DB Cluster の各クラスタ定義 (ここで `terragrunt apply`)
- `rds-mysql-instance/<db-name>/` - RDS MySQL Multi-AZ Instance の各インスタンス定義 (ここで `terragrunt apply`)

## コーディング規約

- Terraform >= 1.5.0, AWS Provider ~> 5.0
- リージョン: ap-northeast-1
- default_tags: `Environment`, `ManagedBy = "Terraform"`
- 変数名: snake_case
- リソース名の self-reference: `"this"` (例: `aws_rds_cluster.this`)

## VPC / ネットワーク情報の取得パターン

VPC ID は SSM Parameter Store から取得する (モジュール内で直接参照):

```hcl
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/dev/vpc/vpc-id"
}
```

DB サブネットグループは network-tf リポジトリで管理されており、名前を変数 `db_subnet_group_name` で受け取る。

## Terragrunt 構成

ルートの `root.hcl` が `generate` ブロックで `versions.tf` と `variables.tf` を各クラスタディレクトリに自動生成する。各クラスタディレクトリには `main.tf`（クラスタ固有）と `terragrunt.hcl`（`include` のみ）を配置する。`variables.tf` / `versions.tf` / `terraform.tfvars` を手動で作成・コピーする必要はない。

## 新しい DB を追加する手順

1. `aurora-mysql/<name>/`、`rds-mysql-cluster/<name>/`、または `rds-mysql-instance/<name>/` ディレクトリを作成
2. `terragrunt.hcl` を作成（`include "root" { path = find_in_parent_folders("root.hcl") }` のみ）
3. `main.tf` でモジュールを `source = "../../modules/aurora-mysql"` (または `rds-mysql-cluster` / `rds-mysql-instance`) で呼び出す

## 検証コマンド

```bash
cd <engine>/<cluster-name>
terragrunt init
terragrunt validate
terragrunt plan
```
