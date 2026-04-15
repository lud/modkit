# Modkit

A set of Mix tasks to work with Elixir module files.


## Installation

    mix archive.install hex modkit


## `mix mod.new`

Creates a new module in the current project.

### Usage

    mix mod.new [options] module

### Options

* `-t`, `--template <string>` - Use the given template for the module code. Accepts a path to an .eex file or a built-in template: `Base`, `DynamicSupervisor`, `GenServer`, `Mix.Task`, `Supervisor`.
* `-u`, `--test` - Create a unit test module for the generated module. Defaults to false.
* `-U`, `--test-only` - Create the unit test only, without generating the module. Defaults to false.
* `-p`, `--path <string>` - The path of the module file to write (must end with .ex). Only applies to the module file; when --test/--test-only is given, the test file path is derived from it. Unnecessary if the module prefix is mounted.
* `-o`, `--overwrite` - Overwrite existing files. Defaults to false.


## `mix mod.relocate`

Moves modules to correct paths according to their name.

### Usage

    mix mod.relocate [options] [module]

### Arguments

* `module` - A single module to relocate. Defaults to all modules.

### Options

* `-i`, `--interactive` - Prompt for confirmation whenever a file can be relocated. Takes precedence over `--force`. Defaults to false.
* `-f`, `--force` - Actually relocate the files. Defaults to false.
* `-v`, `--verbose` - Print all discovered modules and their current paths before relocating. Defaults to false.
