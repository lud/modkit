run:
    mix mod.relocate

install: reinstall

reinstall: uninstall
    mix deps.get
    mix test && mix archive.install --force

uninstall:
    rm -vf *ez
    mix archive.uninstall modkit --force