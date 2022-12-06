# Modkit

This library contains a small set of tool to work with Elixir modules files.


## Installation

    mix archive.install hex modkit


## `mix mod.new`


Creates a new module in the current project.


### Usage

    mix mod.new [options] <module>


### Options

* `-d`, `--dynamic-supervisor` - use DynamicSupervisor and define base functions
* `-g`, `--gen-server` - use GenServer and define base functions
* `-o`, `--overwrite` - Overwrite the file if it exists. Always prompt.
* `-p`, `--path` - The path of the module to write. Unnecessary if the module prefix is mounted.
* `-s`, `--supervisor` - use Supervisor and define base functions.


## `mix mod.relocate`

Moves modules to correct paths according to their name.


### Usage

    mix mod.relocate [options]


### Options

* `-f`, `--force` - This flag will make the command actually relocate the files.
* `-i`, `--interactive` - This flag will make the command prompt for confirmation whenever a file can be relocated. Takes precedences over `--force`.
