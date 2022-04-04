run:
  mix mod.relocate

retry:
  yes | mix archive.uninstall modkit
  yes | mix archive.install
  mix mod.relocate
