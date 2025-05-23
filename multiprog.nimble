# Package

version       = "0.0.15"
author        = "Zack Guard"
description   = "Show progress for multiple concurrent tasks in the terminal"
license       = "GPL-3.0-or-later"
srcDir        = "."

# Dependencies

requires "nim >= 2.0.6"
requires "unicodedb"

feature "example":
  requires "termstyle"
  requires "https://github.com/z-------------/asyncpools"
