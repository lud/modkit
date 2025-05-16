run:
    mix mod.relocate

install: reinstall

reinstall: uninstall test
    mix clean
    mix deps.get
    mix compile --force
    mix test && mix archive.install --force

uninstall:
    rm -vf *ez
    mix archive.uninstall modkit --force

regen-cli:
  mix cli.embed Modkit.CLI lib/modkit/cli --no-moduledoc -f -y
  mix do clean + format

test:
    mix test