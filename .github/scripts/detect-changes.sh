#!/usr/bin/env bash
set -euo pipefail

# Detect modified and deleted cluster directories between two refs.
# Usage: detect-changes.sh <base_ref> <head_ref>
#
# Outputs (via GITHUB_OUTPUT):
#   modified    - JSON array of modified cluster directories
#   deleted     - JSON array of deleted cluster directories
#   has_modified - "true" or "false"
#   has_deleted  - "true" or "false"

BASE_REF="${1:?BASE_REF is required}"
HEAD_REF="${2:?HEAD_REF is required}"

ENGINES=("aurora-mysql" "rds-mysql-cluster" "rds-mysql-instance")

# ---------- helper ----------
list_cluster_dirs_at_ref() {
  local ref="$1"
  local engine="$2"
  git ls-tree --name-only -d "${ref}" "${engine}/" 2>/dev/null || true
}

# ---------- initial push (000...0) ----------
is_initial_push() {
  [[ "${BASE_REF}" =~ ^0+$ ]]
}

if is_initial_push; then
  all_clusters=()
  for engine in "${ENGINES[@]}"; do
    while IFS= read -r dir; do
      [[ -n "${dir}" ]] && all_clusters+=("${dir}")
    done < <(list_cluster_dirs_at_ref "${HEAD_REF}" "${engine}")
  done

  modified_json=$(printf '%s\n' "${all_clusters[@]}" | jq -R . | jq -sc .)
  deleted_json="[]"
else
  # ---------- changed files ----------
  changed_files=$(git diff --name-only "${BASE_REF}...${HEAD_REF}")

  modified_clusters=()
  affected_engines=()

  for engine in "${ENGINES[@]}"; do
    # Direct cluster changes: <engine>/<cluster>/...
    while IFS= read -r dir; do
      [[ -n "${dir}" ]] && modified_clusters+=("${dir}")
    done < <(echo "${changed_files}" | grep -oP "^${engine}/[^/]+" | sort -u)

    # Module or root.hcl changes → add all clusters of the engine
    if echo "${changed_files}" | grep -qE "^modules/${engine}/|^root\.hcl$"; then
      affected_engines+=("${engine}")
    fi
  done

  # Expand affected engines to all their clusters at HEAD
  for engine in "${affected_engines[@]}"; do
    while IFS= read -r dir; do
      [[ -n "${dir}" ]] && modified_clusters+=("${dir}")
    done < <(list_cluster_dirs_at_ref "${HEAD_REF}" "${engine}")
  done

  # ---------- detect deleted directories ----------
  deleted_clusters=()
  for engine in "${ENGINES[@]}"; do
    base_dirs=$(list_cluster_dirs_at_ref "${BASE_REF}" "${engine}")
    head_dirs=$(list_cluster_dirs_at_ref "${HEAD_REF}" "${engine}")
    while IFS= read -r dir; do
      [[ -z "${dir}" ]] && continue
      if ! echo "${head_dirs}" | grep -qxF "${dir}"; then
        deleted_clusters+=("${dir}")
      fi
    done <<< "${base_dirs}"
  done

  # ---------- remove deleted from modified ----------
  if [[ ${#deleted_clusters[@]} -gt 0 ]]; then
    declare -A deleted_set
    for d in "${deleted_clusters[@]}"; do deleted_set["${d}"]=1; done
    filtered=()
    for m in "${modified_clusters[@]}"; do
      [[ -z "${deleted_set[${m}]+_}" ]] && filtered+=("${m}")
    done
    modified_clusters=("${filtered[@]}")
  fi

  # ---------- deduplicate ----------
  if [[ ${#modified_clusters[@]} -gt 0 ]]; then
    modified_json=$(printf '%s\n' "${modified_clusters[@]}" | sort -u | jq -R . | jq -sc .)
  else
    modified_json="[]"
  fi

  if [[ ${#deleted_clusters[@]} -gt 0 ]]; then
    deleted_json=$(printf '%s\n' "${deleted_clusters[@]}" | sort -u | jq -R . | jq -sc .)
  else
    deleted_json="[]"
  fi
fi

# ---------- output ----------
has_modified="false"
has_deleted="false"
[[ "${modified_json}" != "[]" ]] && has_modified="true"
[[ "${deleted_json}" != "[]" ]] && has_deleted="true"

echo "modified=${modified_json}" >> "${GITHUB_OUTPUT}"
echo "deleted=${deleted_json}" >> "${GITHUB_OUTPUT}"
echo "has_modified=${has_modified}" >> "${GITHUB_OUTPUT}"
echo "has_deleted=${has_deleted}" >> "${GITHUB_OUTPUT}"

echo "::group::Detected changes"
echo "Modified: ${modified_json}"
echo "Deleted:  ${deleted_json}"
echo "::endgroup::"
