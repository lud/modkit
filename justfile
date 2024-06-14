run:
    mix mod.relocate

install: reinstall

reinstall: uninstall test
    mix deps.get
    mix test && mix archive.install --force

uninstall:
    rm -vf *ez
    mix archive.uninstall modkit --force

test:
    mix test