#!/usr/bin/env bash
# Render every Flux HelmRelease the way helm-controller would, per cluster, so
# chart upgrades that break our values fail on the PR instead of in-cluster.
#
# For each cluster under kubernetes/flux/clusters/<cluster>:
#   1. `flux build kustomization --dry-run` each Flux Kustomization, so the
#      cluster's own spec.patches (e.g. Traefik's loadBalancerIP) are applied.
#   2. `helm template` each HelmRelease's chart at its pinned version with its
#      values. This runs the chart's values.schema.json, which is where errors
#      like "additional properties 'type' not allowed" come from.
#   3. Fail on duplicate YAML keys in the output. helm-controller rejects them
#      ("mapping key ... already defined"), but helm template and kustomize both
#      silently keep the last one, so we check ourselves (see find_duplicate_keys).
#   4. Run the output through `kubectl kustomize` with the release's
#      postRenderers patches, as helm-controller always post-renders.
#
# Needs flux, helm, kubectl and jq on PATH, plus network access to chart repos.
# No cluster, Twingate or SOPS key needed: secrets are not decrypted and
# valuesFrom is not resolved (no HelmRelease currently uses it).
#
# Usage: scripts/validate-flux-helmreleases.sh [cluster ...]   (default: all)
# Env:   VALIDATE_JOBS=8   number of charts rendered in parallel

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTERS_DIR="$REPO_ROOT/kubernetes/flux/clusters"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export REPO_ROOT WORK

for tool in flux helm kubectl jq awk sha256sum; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found on PATH" >&2; exit 2; }
done

# Convert multi-document YAML to a JSON array of objects, without a cluster.
yaml_to_json() {
  KUBECONFIG=/dev/null kubectl annotate --local -f "$1" validate-flux-helmreleases=1 -o json |
    jq -s '[.[] | if .kind == "List" then .items[] else . end]'
}

# Print "file:line: message" for each duplicate mapping key in a YAML file, and
# exit non-zero if there were any.
#
# This is a deliberately small checker for the block-style YAML that
# `helm template` emits, not a full YAML parser. It tracks the keys seen at
# each indentation level of the current mapping and:
#   - starts a fresh document at every `---`
#   - starts a fresh mapping at every list item (`- key: ...`)
#   - forgets deeper levels when indentation goes back out
#   - skips the body of block scalars (`key: |`, `key: >-`, ...), which is
#     where embedded config files live
find_duplicate_keys() {
  # Written for POSIX awk (mawk on Ubuntu runners), hence no gawk extensions.
  awk -v file="$1" -v q="'" '
    # keys[column SUBSEP key] = line number where that key was first seen.
    # Forget every key at or deeper than the given column.
    function forget_from(min_col,   k, part) {
      for (k in keys) { split(k, part, SUBSEP); if (part[1] + 0 >= min_col) delete keys[k] }
    }

    # Return the mapping key at the start of s, or "" if s is not a "key: ..." line.
    # Sets rest to whatever follows the colon.
    function parse_key(s,   c, end, key) {
      c = substr(s, 1, 1)
      if (c == "\"" || c == q) {
        end = index(substr(s, 2), c)                      # closing quote
        if (end == 0) return ""
        key = substr(s, 2, end - 1)
        rest = substr(s, end + 2)
        if (substr(rest, 1, 1) != ":") return ""
        rest = substr(rest, 2)
      } else {
        if (index("#{[|>&*!%@`", c)) return ""
        end = index(s, ": ")
        if (end) { key = substr(s, 1, end - 1); rest = substr(s, end + 1) }
        else if (substr(s, length(s)) == ":") { key = substr(s, 1, length(s) - 1); rest = "" }
        else return ""
      }
      if (rest != "" && substr(rest, 1, 1) != " ") return ""
      return key == "" ? "" : key
    }

    BEGIN { block_col = -1; dups = 0 }
    {
      match($0, /^ */); col = RLENGTH
      body = substr($0, col + 1)

      # Inside a block scalar: skip anything indented deeper than its parent.
      if (block_col >= 0) {
        if (body == "" || col > block_col) next
        block_col = -1
      }
      if (body ~ /^---/) { split("", keys); next }  # new document
      if ($0 ~ /^# Source: /) source = substr($0, 11) # helm names the template here
      if (body == "" || substr(body, 1, 1) == "#") next

      if (body ~ /^- / || body == "-") {
        # A list item starts a fresh mapping at the column of its content.
        dash_col = col
        sub(/^- */, "", body)
        col = length($0) - length(body)
        forget_from(col)
        if (body ~ /^[|>][-+0-9]* *(#.*)?$/) { block_col = dash_col; next }   # "- |"
      } else {
        forget_from(col + 1)
      }

      key = parse_key(body)
      if (key == "") next
      if ((col, key) in keys) {
        printf "%s: mapping key \"%s\" defined twice (output lines %d and %d)\n",
          (source != "" ? source : file), key, keys[col, key], NR
        dups++
      } else {
        keys[col, key] = NR
      }
      if (rest ~ /^ +[|>][-+0-9]* *(#.*)?$/) block_col = col                 # "key: |"
    }
    END { exit (dups > 0) }
  ' "$1"
}

# Print the `helm template` chart arguments for a job, one per line.
chart_args() {
  jq -r '
    .release as $hr | .sources as $src
    | ($hr.metadata.namespace) as $ns
    | def source($ref): $src[$ref.kind + "/" + ($ref.namespace // $ns) + "/" + $ref.name]
        // error("source \($ref.kind)/\($ref.name) not found");
    if $hr.spec.chartRef then
      source($hr.spec.chartRef) as $s
      | if $hr.spec.chartRef.kind != "OCIRepository" then error("chartRef kind \($hr.spec.chartRef.kind) not supported") else . end
      | $s.spec.url, (($s.spec.ref.tag // $s.spec.ref.semver) // empty | "--version", .)
    else
      $hr.spec.chart.spec as $c | source($c.sourceRef) as $s
      | if $c.sourceRef.kind != "HelmRepository" then error("sourceRef kind \($c.sourceRef.kind) not supported") else . end
      | ($s.spec.url | rtrimstr("/")) as $url
      | (if $s.spec.type == "oci" then "\($url)/\($c.chart)" else $c.chart, "--repo", $url end),
        ($c.version // empty | "--version", tostring)
    end
  ' "$1"
}

# Render one HelmRelease job file. Writes <job>.log, and <job>.ok on success.
render_job() {
  local job="$1" dir
  dir="$(mktemp -d "$WORK/render.XXXXXX")"
  exec >"$job.log" 2>&1

  local name namespace release_name
  name="$(jq -r '.release.metadata.name' "$job")"
  namespace="$(jq -r '.release.spec.targetNamespace // .release.metadata.namespace' "$job")"
  release_name="$(jq -r '.release.spec.releaseName // .release.metadata.name' "$job")"

  if jq -e '.release.spec.valuesFrom' "$job" >/dev/null; then
    echo "warning: valuesFrom is not resolved; rendering with inline values only"
  fi

  local args=()
  mapfile -t args < <(chart_args "$job") || return 1
  [[ ${#args[@]} -gt 0 ]] || return 1
  if jq -e '.release.spec.install.disableSchemaValidation or .release.spec.upgrade.disableSchemaValidation' "$job" >/dev/null; then
    args+=(--skip-schema-validation)
  fi

  # JSON is valid YAML, so values can be handed to helm as-is.
  jq '.release.spec.values // {}' "$job" >"$dir/values.yaml"
  helm template "$release_name" "${args[@]}" --namespace "$namespace" \
    --values "$dir/values.yaml" >"$dir/rendered.yaml" || return 1
  find_duplicate_keys "$dir/rendered.yaml" || return 1

  # Post-render: one kustomize pass per postRenderers entry (at least one).
  local count i input="$dir/rendered.yaml"
  count="$(jq '[.release.spec.postRenderers // [] | .[]] | length' "$job")"
  for ((i = 0; i < (count > 0 ? count : 1); i++)); do
    mkdir "$dir/post-render-$i"
    cp "$input" "$dir/post-render-$i/resources.yaml"
    jq --argjson i "$i" '
      (.release.spec.postRenderers // [])[$i].kustomize // {}
      | {resources: ["resources.yaml"]} + with_entries(select(.key | IN("patches", "patchesStrategicMerge", "patchesJson6902", "images")))
    ' "$job" >"$dir/post-render-$i/kustomization.yaml"
    kubectl kustomize "$dir/post-render-$i" >"$dir/post-render-$i.yaml" || return 1
    input="$dir/post-render-$i.yaml"
  done
  find_duplicate_keys "$input" || return 1

  echo "rendered $namespace/$name"
  touch "$job.ok"
}
export -f render_job chart_args find_duplicate_keys

# Build one cluster's Flux Kustomizations and write a job file per HelmRelease.
# Identical releases across clusters share a job (same hash) and are rendered once.
collect_jobs() {
  local cluster="$1" file name path out="$WORK/$cluster"
  mkdir -p "$out" "$WORK/jobs"
  : >"$out/build.yaml"

  for file in "$CLUSTERS_DIR/$cluster"/*.yaml; do
    [[ "$file" == *.sops.yaml ]] && continue
    while IFS=$'\t' read -r name path; do
      echo "---" >>"$out/build.yaml"
      if ! (cd "$REPO_ROOT" && flux build kustomization "$name" --path "$path" \
              --kustomization-file "$file" --dry-run >>"$out/build.yaml" 2>"$out/flux-error.log"); then
        echo "[$cluster] flux build $name failed: $(cat "$out/flux-error.log")" >>"$WORK/failures.log"
      fi
    done < <(yaml_to_json "$file" |
      jq -r '.[] | select(.kind == "Kustomization" and (.apiVersion | startswith("kustomize.toolkit.fluxcd.io/")))
                 | [.metadata.name, .spec.path] | @tsv')
  done

  yaml_to_json "$out/build.yaml" >"$out/build.json"
  jq -c '
    (map(select(.apiVersion | startswith("source.toolkit.fluxcd.io/")))
      | map({key: "\(.kind)/\(.metadata.namespace // "flux-system")/\(.metadata.name)", value: .}) | from_entries) as $sources
    | .[] | select(.kind == "HelmRelease" and (.apiVersion | startswith("helm.toolkit.fluxcd.io/")) and (.spec.suspend | not))
    | {release: ., sources: $sources}
  ' "$out/build.json" >"$out/jobs.jsonl"

  echo "[$cluster] $(wc -l <"$out/jobs.jsonl") HelmReleases" \
    "($(jq '[.[] | select(.kind == "HelmRelease" and .spec.suspend)] | length' "$out/build.json") suspended, skipped)"
  local job hash
  while IFS= read -r job; do
    # Hash only what affects rendering, so per-cluster noise does not split jobs.
    hash="$(jq -cS '{ns: .release.metadata.namespace, name: .release.metadata.name,
                     spec: (.release.spec | del(.interval, .timeout))}' <<<"$job" | sha256sum | cut -c1-16)"
    [[ -f "$WORK/jobs/$hash.json" ]] || jq '.release |= del(.metadata.annotations["validate-flux-helmreleases"])' <<<"$job" >"$WORK/jobs/$hash.json"
    echo "$cluster" >>"$WORK/jobs/$hash.json.clusters"
  done <"$out/jobs.jsonl"
}

main() {
  local clusters=("$@")
  if [[ ${#clusters[@]} -eq 0 ]]; then
    mapfile -t clusters < <(find "$CLUSTERS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  fi
  : >"$WORK/failures.log"

  local cluster
  for cluster in "${clusters[@]}"; do
    [[ -d "$CLUSTERS_DIR/$cluster" ]] || { echo "error: no cluster dir $CLUSTERS_DIR/$cluster" >&2; exit 2; }
    collect_jobs "$cluster"
  done

  local jobs=("$WORK"/jobs/*.json)
  [[ -e "${jobs[0]}" ]] || jobs=()
  if [[ ${#jobs[@]} -gt 0 ]]; then
    printf '%s\0' "${jobs[@]}" | xargs -0 -n1 -P "${VALIDATE_JOBS:-8}" bash -c 'render_job "$1" || true' _
  fi

  local job label
  for job in "${jobs[@]}"; do
    label="$(jq -r '.release.metadata | "\(.namespace)/\(.name)"' "$job") [$(paste -sd, "$job.clusters")]"
    if [[ -f "$job.ok" ]]; then
      echo "  ok    $label"
    else
      echo "  FAIL  $label"
      { echo "- $label:"; sed 's/^/    /' "$job.log"; echo; } >>"$WORK/failures.log"
    fi
  done

  echo
  echo "Rendered ${#jobs[@]} unique HelmReleases across ${#clusters[@]} clusters."
  if [[ -s "$WORK/failures.log" ]]; then
    echo
    echo "Failures:"
    cat "$WORK/failures.log"
    exit 1
  fi
}

main "$@"
