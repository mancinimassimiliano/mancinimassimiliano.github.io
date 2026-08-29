---
name: run-mancinimassimiliano-github-io
description: Build, serve, and smoke-test this al-folio Jekyll academic site. Use when asked to run the site, start the Jekyll dev server, build it, verify a content change (news item, publication, CV entry), or screenshot a page.
---

This is a Jekyll static site (the [al-folio](https://github.com/alshedivat/al-folio)
academic-homepage theme) with no client-side app to speak of - "running" it
means building with Jekyll, serving the static output, and checking that
pages return the expected HTML. Drive it with
`.claude/skills/run-mancinimassimiliano-github-io/smoke.sh`, which does
exactly that and `curl`-checks five representative pages. For a visual
check, open the served URL in a browser tool (Playwright/`chromium-cli`/the
Claude Code browser pane) after the smoke script's build step.

All paths below are relative to the repo root.

## Prerequisites

The macOS system Ruby (2.6, at `/usr/bin/ruby`) is too old for this
Gemfile's `jekyll 4.4.1`. Plain Homebrew `ruby` (4.0+) is new enough but
**breaks the build** because it demoted `ostruct` out of default gems and
`jekyll-twitter-plugin` still does a bare `require "ostruct"`. Use
Homebrew's `ruby@3.3` instead - it's keg-only so it won't fight a
system/other Homebrew Ruby:

```bash
brew install ruby@3.3
```

Building `assets/jupyter/blog.ipynb` (via `jekyll-jupyter-notebook`) needs
a `jupyter` binary on PATH. There's no Homebrew `jupyter` formula that
just works standalone; pip install it for the user instead:

```bash
pip3 install --user nbconvert jupyter_client ipykernel
```

## Setup

```bash
export PATH="/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$HOME/Library/Python/3.9/bin:$PATH"
bundle config set --local path 'vendor/bundle'
bundle install
```

`bundle config set --local path 'vendor/bundle'` keeps gems project-local
(no `sudo`, doesn't touch system Ruby). `vendor/`, `.bundle/`, and
`Gemfile.lock` are already gitignored.

The bibliography (`_bibliography/`) has non-ASCII author names.
`bibtex-ruby` reads files honoring `$LANG`/`$LC_ALL`, so building under
the default macOS shell locale (`C`/`US-ASCII`) crashes with
`invalid byte sequence in US-ASCII`. Always export a UTF-8 locale first:

```bash
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

(`en_US.UTF-8` is present out of the box on macOS - confirmed with
`locale -a`.)

## Build

```bash
bundle exec jekyll build --trace
```

Exit 0 and a populated `_site/` means it worked. `--trace` is worth
keeping on: this Gemfile pulls in enough plugins (scholar, imagemagick,
jupyter-notebook, twitter) that a broken toolchain piece fails deep in a
plugin, not in Jekyll itself, and the stack trace is what tells you which.

## Run (agent path)

```bash
.claude/skills/run-mancinimassimiliano-github-io/smoke.sh
```

This builds the site, serves it on `127.0.0.1:4444` (override with
`PORT=...`), polls until it responds, `curl`-checks `/`, `/publications/`,
`/cv/`, `/bio/`, and `/news/` for a 200 status and an expected substring,
prints `OK`/`FAIL` per page, and kills the server on exit (including on
failure, via `trap`). Exit code is non-zero if any check fails or the
build fails (`set -euo pipefail`). Re-run it after any content or layout
change to confirm the site still builds and serves.

For a visual check on top of the smoke script (e.g. after a CSS or layout
change), build first, then serve manually and point a browser tool at it:

```bash
bundle exec jekyll build
bundle exec jekyll serve --port=4444 --host=127.0.0.1 --skip-initial-build &
```

then navigate a browser tool to `http://127.0.0.1:4444/<page>/` and
screenshot. Verified pages and what they should show: `/` (about page,
headshot, news list), `/publications/` (jekyll-scholar bibliography with
thumbnails, author lists, ABS/BIB/HTML/PDF badges), `/cv/` (side nav +
General Information / Education / ... cards, generated from
`_data/cv.yml`).

## Run (human path)

```bash
bundle exec jekyll serve --watch --livereload
```

Opens on `http://127.0.0.1:4000` by default, rebuilds on file changes.
`Ctrl-C` to stop. Not useful for an agent (blocks the terminal, no
built-in way to know the current page rendered correctly) - use the
smoke script instead.

## Test

There is no separate test suite - the smoke script above (build +
serve + content checks) is the verification loop for this project.

---

## Gotchas

- **Don't use plain `brew install ruby`.** It installs Ruby 4.x, which
  drops `ostruct` from default gems; `jekyll-twitter-plugin` (a Gemfile
  dependency, always loaded) does a bare `require "ostruct"` and the
  build dies with `cannot load such file -- ostruct` before rendering
  anything. `ruby@3.3` still bundles it.
- **Locale matters more than it looks.** The `invalid byte sequence in
US-ASCII` failure happens deep in `bibtex-ruby`'s lexer while parsing
  `_bibliography/*.bib`, not at startup - easy to mistake for a corrupt
  bib file. It's purely `$LANG`/`$LC_ALL` being unset/`C`.
- **`bundle exec jekyll serve &` backgrounding doesn't `kill` cleanly
  with a bare `$!`.** In practice here `kill "$SERVER_PID"` from the
  script did stop the right process (unlike an `npm run dev` wrapper),
  but if you background it manually and `$!` doesn't die on `kill`,
  fall back to `lsof -ti:4444 -sTCP:LISTEN | xargs -r kill`.
- **ImageMagick `convert` warnings during build are expected here and
  harmless.** `jekyll-imagemagick` shells out to `convert` to generate
  responsive `.webp` variants; if ImageMagick isn't installed
  (`brew install imagemagick` to fix) it logs
  `sh: convert: command not found` per image but still exits 0 - the
  site serves fine with the originals, just without the generated
  `-480/-800/-1400.webp` sizes.
- **The publications page throws `$ is not defined` in the browser
  console** (image-load-error handler expects jQuery that isn't loaded
  on that page) and 404s on a few thumbnails that depend on the
  ImageMagick step above. Pre-existing/cosmetic, not something the
  build introduces - don't chase it as a regression unless it's what
  you were asked to fix.

## Troubleshooting

- **`cannot load such file -- ostruct (LoadError)`**: you're on
  Homebrew's default `ruby` (4.x). Put `ruby@3.3`'s bin dir first on
  `PATH` (see Prerequisites) and re-run `bundle install` after removing
  `vendor/bundle` and `Gemfile.lock` (they're Ruby-version-specific).
- **`Liquid Exception: invalid byte sequence in US-ASCII in
.../_layouts/about.liquid`**: `LANG`/`LC_ALL` not set to a UTF-8
  locale. Export `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` and rebuild.
- **`Conversion error: ... No such file or directory - jupyter`**:
  `jupyter` isn't on `PATH`. Either
  `pip3 install --user nbconvert jupyter_client ipykernel` and add
  `~/Library/Python/3.9/bin` (or whatever `pip3 --version` reports) to
  `PATH`, or remove/skip `assets/jupyter/blog.ipynb` if you don't need
  notebook rendering for the change you're making.
- **`bundle: command not found` / it resolves to Ruby 2.6's bundler**:
  `/opt/homebrew/opt/ruby@3.3/bin` isn't first on `PATH` - macOS ships
  `/usr/bin/bundle` for system Ruby and it wins otherwise.
