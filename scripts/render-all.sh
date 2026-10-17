#!/usr/bin/env bash
# Lint and render every example environment, plus any extra values files passed
# as arguments (e.g. the values/ directories of consuming service repos).
#
#   ./scripts/render-all.sh
#   ./scripts/render-all.sh ../platform-order-service/values/*/values.yaml
set -euo pipefail

cd "$(dirname "$0")/.."
chart=$(pwd)
out=$(mktemp -d)
base="examples/inventory-service/values/base.yaml"
status=0

echo "==> helm lint (defaults)"
helm lint "$chart" --set image.repository=example/app

for env in local dev prod; do
  echo "==> examples/inventory-service: $env"
  if ! helm template inventory-service "$chart" -f "$base" \
      -f "examples/inventory-service/values/$env.yaml" > "$out/$env.yaml"; then
    status=1
    continue
  fi
  printf '    %s objects\n' "$(grep -c '^kind:' "$out/$env.yaml")"
done

for values in "$@"; do
  name=$(basename "$(dirname "$(dirname "$(dirname "$values")")")" | sed 's/^platform-//')
  echo "==> $values (release: $name)"
  if ! helm template "$name" "$chart" -f "$values" > "$out/$name.yaml"; then
    status=1
    continue
  fi
  printf '    %s objects\n' "$(grep -c '^kind:' "$out/$name.yaml")"
done

echo "rendered manifests: $out"
exit "$status"
