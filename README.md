# Lantern
Lantern is a Neovim plugin that provides CMake integration and project support.

Lantern makes use of the [CMake file API](https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html) to gather
information about projects, and exposes that information via a Lua API that can be used to set up autocommands, user
commands or mappings to provide the desired level of IDE-like functionality.

## Installation
Lantern can be installed using your preferred plugin management method. It does not require the invocation of a
`setup()` function, although one exists to allow for customization.

## Quickstart
```lua
  -- Load a project from a directory. Lantern can load any directory, but unless that directory is the root of a CMake
  -- project tree, the information Lantern discovers will be minimal.
  local lantern = require("lantern")
  lantern.load("/path/to/a/project")

  -- At this point, you can inspect the current project.
  vim.print(lantern.project())

  -- You can change the active configuration and target.
  lantern.set_configuration("Debug")
  lantern.set_target("UnitTests")

  -- The table for the current configuration and target can be inspected.
  vim.print(lantern.configuration())
  vim.print(lantern.target())

  -- You can also invoke build tasks (essentially, "cmake --build" and related) on the project.
  lantern.run("build")
```

See `:h lantern` for more details, including documentation of the project, configuration and target table structure.

