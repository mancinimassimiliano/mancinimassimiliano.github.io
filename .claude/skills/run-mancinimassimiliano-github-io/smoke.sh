#!/usr/bin/env bash
# Build the Jekyll site, serve it, and curl-check the key pages.
# See ../SKILL.md (../../../SKILL.md relative to repo root) for context.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

# --- toolchain: Homebrew Ruby 3.3 (system Ruby is 2.6 and too old for
# this Gemfile; plain Homebrew `ruby` is 4.0+ and drops `ostruct`,
# which jekyll-twitter-plugin still needs) + pip-installed jupyter
# (needed only because assets/jupyter/blog.ipynb gets converted at
# build time) ---
export PATH="/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$HOME/Library/Python/3.9/bin:$PATH"
# bibliography entries contain non-ASCII author names; without a UTF-8
# locale bibtex-ruby raises "invalid byte sequence in US-ASCII"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

PORT="${PORT:-4444}"
HOST=127.0.0.1

command -v bundle >/dev/null || { echo "Homebrew ruby@3.3 not found on PATH - see Prerequisites in SKILL.md"; exit 1; }

if [ ! -d vendor/bundle ]; then
  bundle config set --local path 'vendor/bundle'
  bundle install
fi

echo "== jekyll build =="
bundle exec jekyll build --trace

echo "== jekyll serve on :$PORT =="
bundle exec jekyll serve --port="$PORT" --host="$HOST" --skip-initial-build \
  > /tmp/jekyll_smoke_serve.log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  curl -sf "http://$HOST:$PORT" >/dev/null && break
  sleep 1
done

check() { # path, expected-substring
  local path="$1" needle="$2" body status
  body="$(curl -s "http://$HOST:$PORT$path")"
  status="$(curl -s -o /dev/null -w '%{http_code}' "http://$HOST:$PORT$path")"
  if [ "$status" != "200" ]; then
    echo "FAIL $path -> HTTP $status"; return 1
  fi
  if ! grep -qF "$needle" <<<"$body"; then
    echo "FAIL $path -> missing '$needle'"; return 1
  fi
  echo "OK   $path (contains '$needle')"
}

check "/"             "Massimiliano Mancini"
check "/publications/" "publications by categories"
check "/cv/"           "General Information"
check "/bio/"          "Massimiliano"
check "/news/"         "news"

echo "== all checks passed =="
