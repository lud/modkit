run:
  mix mod.relocate

deps:
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

_mix_format:
  mix format

_mix_check:
  mix check

docs:
  mix docs

_git_status:
  git status

check: deps _mix_format _mix_check docs _git_status