#!/usr/bin/env bash
set -euo pipefail

# Parse PR labels to determine target cluster directories.
# Usage: parse-labels.sh '<JSON array of label strings>'
#
# Example: parse-labels.sh '["type:aurora-mysql","cluster:aurora-test001"]'
#
# Outputs (via GITHUB_OUTPUT):
#   has_labels   - "true" if both type: and cluster: labels are present
#   modified     - JSON array of target directories
#   deleted      - JSON array (always [])
#   has_modified - "true" or "false"
#   has_deleted  - "false"

LABELS_JSON="${1:?LABELS_JSON is required}"

VALID_ENGINES=("aurora-mysql" "rds-mysql-cluster" "rds-mysql-instance")

# ---------- extract labels ----------
engine=""
cluster=""

for label in $(echo "${LABELS_JSON}" | jq -r '.[]'); do
  case "${label}" in
    type:*)    engine="${label#type:}" ;;
    cluster:*) cluster="${label#cluster:}" ;;
  esac
done

# ---------- check if both labels exist ----------
if [[ -z "${engine}" || -z "${cluster}" ]]; then
  echo "has_labels=false" >> "${GITHUB_OUTPUT}"
  echo "modified=[]" >> "${GITHUB_OUTPUT}"
  echo "deleted=[]" >> "${GITHUB_OUTPUT}"
  echo "has_modified=false" >> "${GITHUB_OUTPUT}"
  echo "has_deleted=false" >> "${GITHUB_OUTPUT}"

  echo "::group::Label parsing"
  echo "type: and/or cluster: labels not found — skipping label-based detection"
  echo "::endgroup::"
  exit 0
fi

# ---------- validate engine ----------
valid=false
for e in "${VALID_ENGINES[@]}"; do
  if [[ "${engine}" == "${e}" ]]; then
    valid=true
    break
  fi
done

if [[ "${valid}" != "true" ]]; then
  echo "::error::Invalid engine type '${engine}'. Must be one of: ${VALID_ENGINES[*]}"
  exit 1
fi

# ---------- build target directory ----------
target_dir="${engine}/${cluster}"

# ---------- detect create/modify vs delete ----------
if [[ -d "${target_dir}" ]]; then
  modified_json="[\"${target_dir}\"]"
  deleted_json="[]"
  has_modified="true"
  has_deleted="false"
else
  modified_json="[]"
  deleted_json="[\"${target_dir}\"]"
  has_modified="false"
  has_deleted="true"
fi

# ---------- output ----------
echo "has_labels=true" >> "${GITHUB_OUTPUT}"
echo "modified=${modified_json}" >> "${GITHUB_OUTPUT}"
echo "deleted=${deleted_json}" >> "${GITHUB_OUTPUT}"
echo "has_modified=${has_modified}" >> "${GITHUB_OUTPUT}"
echo "has_deleted=${has_deleted}" >> "${GITHUB_OUTPUT}"

echo "::group::Label parsing"
echo "Engine:  ${engine}"
echo "Cluster: ${cluster}"
echo "Target:  ${target_dir}"
echo "Modified: ${modified_json}"
echo "Deleted:  ${deleted_json}"
echo "::endgroup::"
