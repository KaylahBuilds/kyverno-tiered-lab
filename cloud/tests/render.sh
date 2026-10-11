#!/usr/bin/env bash
# No cluster connection: verify a reviewed chart archive, then render both profiles.
set -euo pipefail
cd "$(dirname "$0")/../.."
command -v helm >/dev/null
mkdir -p .tools
render_dir=$(mktemp -d)
trap 'rm -f "$render_dir/aks.yaml" "$render_dir/eks.yaml"; rmdir "$render_dir"' EXIT
chart=.tools/kyverno-3.9.1.tgz
curl --fail --location --proto '=https' --tlsv1.2 \
  https://kyverno.github.io/kyverno/kyverno-3.9.1.tgz --output "$chart"
printf '%s  %s\n' 7b7fe51a431b5b133b0ce7eb9dcb222b6a37fb967c163223cf480054ad14d752 "$chart" | sha256sum --check -
for platform in aks eks; do
  helm template kyverno "$chart" --namespace kyverno --include-crds \
    --kube-version 1.33.0 \
    --values cloud/addons/values-common.yaml \
    --values "cloud/$platform/values.yaml" > "$render_dir/$platform.yaml"
  python cloud/tests/check_render.py "$platform" "$render_dir/$platform.yaml"
done
