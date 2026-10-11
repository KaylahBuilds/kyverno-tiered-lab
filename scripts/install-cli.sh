#!/usr/bin/env bash
# Linux x86_64 only. Download a reviewed official release into the caller's .tools/.
set -euo pipefail
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "This helper supports Linux x86_64. See README for other platforms." >&2
  exit 1
fi
version="v1.19.1"
asset="kyverno-cli_${version}_linux_x86_64.tar.gz"
expected="b38228f367fc0fdc2b08f4c83ea50ac5f16c60ff8d62d76a66157c33c47b70ae"
# Reviewed against the official release asset digest on 2026-10-10:
# https://github.com/kyverno/kyverno/releases/expanded_assets/v1.19.1
mkdir -p .tools
temp_dir="$(mktemp -d .tools/download.XXXXXX)"
curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  --output "$temp_dir/$asset" \
  "https://github.com/kyverno/kyverno/releases/download/$version/$asset"
printf '%s  %s\n' "$expected" "$temp_dir/$asset" | sha256sum --check --strict
tar -xzf "$temp_dir/$asset" -C "$temp_dir" kyverno
install -m 0755 "$temp_dir/kyverno" .tools/kyverno
.tools/kyverno version
echo "Verified CLI installed locally at .tools/kyverno. Download retained in $temp_dir."
