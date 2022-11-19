# Package

version       = "0.0.6"
author        = "Zack Guard"
description   = "Show progress for multiple concurrent tasks in the terminal"
license       = "GPL-3.0-or-later"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.4"

# Tasks

task tag, "Create a git annotated tag with the current nimble version":
  let tagName = "v" & version
  exec "git tag -a " & tagName & " -m " & tagName
