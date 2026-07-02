run:
  mix mod.relocate

_mix_deps:
  mix deps.get

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