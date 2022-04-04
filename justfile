run:
  mix mod.relocate

reinstall:
  yes | mix archive.uninstall modkit
  yes | mix archive.install

uninstall:
  yes | mix archive.uninstall modkit
