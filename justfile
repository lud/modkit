run:
  mix mod.relocate

_mix_deps:
  out=$(mix deps.get) && echo "all dependencies fetched" || { echo "$out"; exit 1; }

install: reinstall

reinstall: uninstall
  mix compile --force
  mix archive.install --force

uninstall:
  rm -vf *ez
  mix archive.uninstall modkit --force

regen-cli:
  mix cli.embed Modkit.CLI lib/modkit/cli --no-moduledoc -f -y
  mix do clean + format

test:
  mix test

format:
  mix format --migrate

readmix:
  mix rdmx.update README.md

_libdev_check:
  mix libdev.check

docs:
  mix docs

_git_status:
  git status

check: _mix_deps format readmix _libdev_check _git_status

release bump:
  #!/usr/bin/env bash
  set -euo pipefail
  notes=tmp/release-notes.md
  if [ -f "$notes" ]; then
    mix version --{{bump}} --confirm --annotation-file "$notes"
    mv "$notes" "tmp/release-notes.$(date +%Y%m%dT%H%M%S).md"
  else
    mix version --{{bump}} --confirm
  fi

push-release:
  #!/usr/bin/env bash
  set -euo pipefail
  git push --follow-tags
  tag=$(git describe --tags --abbrev=0)
  gh release create "$tag" --title "$tag" --notes "$(git cliff --latest --strip all)"
