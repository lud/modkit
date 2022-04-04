run:
  mix mod.relocate

reinstall:
  yes | mix archive.uninstall modkit
  yes | mix archive.install
  mix mod.relocate
