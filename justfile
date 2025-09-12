run:
    mix mod.relocate

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