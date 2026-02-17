# CLAUDE.md

## プロジェクト概要

RDS MySQL / Aurora MySQL を管理する Terraform リポジトリ。

## ディレクトリ構成ルール

- `root.hcl` - ルート Terragrunt 設定 (`remote_state` で `backend.tf`、`generate` で `versions.tf` / `variables.tf` を自動生成)
- `modules/` - 再利用可能な Terraform モジュール (直接 apply しない)
  - `aurora-mysql/` - Aurora MySQL モジュール
  - `rds-mysql-cluster/` - RDS MySQL Multi-AZ DB Cluster モジュール (`aws_rds_cluster`)
  - `rds-mysql-instance/` - RDS MySQL Multi-AZ Instance モジュール (`aws_db_instance`)
- `aurora-mysql/<cluster-name>/` - Aurora MySQL の各クラスタ定義 (ここで `terragrunt apply`)
- `rds-mysql-cluster/<cluster-name>/` - RDS MySQL Multi-AZ DB Cluster の各クラスタ定義 (ここで `terragrunt apply`)
- `rds-mysql-instance/<db-name>/` - RDS MySQL Multi-AZ Instance の各インスタンス定義 (ここで `terragrunt apply`)
- `.github/workflows/` - GitHub Actions CI/CD ワークフロー
- `.github/actions/setup-terragrunt/` - Terraform / Terragrunt インストール composite action
- `.github/scripts/` - CI/CD 補助スクリプト
  - `detect-changes.sh` - git diff ベースの変更検出（ラベルなし PR 用フォールバック）
  - `parse-labels.sh` - PR ラベルから対象ディレクトリを算出

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

ルートの `root.hcl` が以下を各クラスタディレクトリに自動生成する:
- `backend.tf` - `remote_state` ブロックで生成。state key は `aws-rdb-iac/${path_relative_to_include()}/terraform.tfstate` でクラスタごとに一意
- `versions.tf` - `generate "versions"` で生成 (`required_version`, `required_providers`, `provider`)
- `variables.tf` - `generate "variables"` で生成 (`aws_region`, `environment`)

各クラスタディレクトリには `main.tf`（クラスタ固有）と `terragrunt.hcl`（`include` のみ）を配置する。`variables.tf` / `versions.tf` / `backend.tf` / `terraform.tfvars` を手動で作成・コピーする必要はない。

## 新しい DB を追加する手順

1. `aurora-mysql/<name>/`、`rds-mysql-cluster/<name>/`、または `rds-mysql-instance/<name>/` ディレクトリを作成
2. `terragrunt.hcl` を作成（`include "root" { path = find_in_parent_folders("root.hcl") }` のみ）
3. `main.tf` でモジュールを `source = "../../modules/aurora-mysql"` (または `rds-mysql-cluster` / `rds-mysql-instance`) で呼び出す
4. PR を作成 → CI が自動で `terragrunt plan` を実行 → マージで `terragrunt apply` が実行される

## DB を削除する手順

1. 対象のクラスタディレクトリごと削除する PR を作成
2. CI が `terragrunt plan -destroy` を実行し、PR コメントに破壊計画を表示
3. マージで `terragrunt destroy` が自動実行される

## CI/CD ワークフロー

- **plan.yml** (PR 時): 変更対象検出 → `terragrunt validate` + `terragrunt plan` → 結果を PR コメントに投稿 → ラベル付き PR は plan 成功後に自動マージ
- **apply.yml** (main マージ時): 変更対象検出 → 削除クラスタの `terragrunt destroy` → 変更クラスタの `terragrunt apply`
- AWS 認証: OIDC (`vars.AWS_ROLE_ARN`)

### 変更対象の検出 (ラベルベース + git diff フォールバック)

1. **ラベルベース** (`parse-labels.sh`): PR に `type:<engine>` と `cluster:<name>` ラベルが付与されている場合、ラベルから対象ディレクトリを算出する。外部構成管理ツールからの自動 PR はこのパスを通る
2. **git diff フォールバック** (`detect-changes.sh`): ラベルがない場合は従来どおり git diff で変更を検出する。モジュール変更・手動編集 PR はこのパスを通る

### 自動マージ

- `type:*` + `cluster:*` ラベルが付いた PR は、plan 成功後に `gh pr merge --squash --auto` で自動マージされる
- ラベルなし PR は自動マージされない（手動レビュー＋マージが必要）
- 前提: リポジトリ設定で **"Allow auto-merge"** を有効にし、ブランチ保護ルールで `summary` を required status check に設定する

## 検証コマンド

```bash
cd <engine>/<cluster-name>
terragrunt init
terragrunt validate
terragrunt plan
```
