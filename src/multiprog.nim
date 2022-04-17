# Copyright (C) 2022 Zack Guard
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import std/terminal
import std/options
import std/strutils
import std/math

type
  Multiprog* = object
    curLine: int
    slots: seq[bool]
    isTotalCountGiven: bool
    totalCount: int
    doneCount: int
    f: File
    isFinished: bool
  JobId* = distinct int

template checkState(mp: Multiprog) =
  assert not mp.isFinished

proc cursorMoveLine(f: File; count: int) =
  if count == 0:
    discard
  else:
    try:
      if count < 0:
        f.cursorUp(-count)
      else:
        f.cursorDown(count)
      f.setCursorXPos(0)
    except OSError:
      discard

template reprSize(n: Natural): int =
  if n == 0:
    1
  else:
    log10(n.float).int + 1

proc writeProgressLine(mp: Multiprog) =
  let downCount = mp.slots.len - mp.curLine
  mp.f.cursorMoveLine(downCount)

  let
    rhsSize = 1 + reprSize(mp.doneCount) + 1 + reprSize(mp.totalCount) + 1
    size = terminalWidth() - rhsSize - 2
    ratio = mp.doneCount / mp.totalCount
    filledCount = floor(ratio * size.float).int
  mp.f.write("[")
  mp.f.write('#'.repeat(filledCount))
  mp.f.write(' '.repeat(size - filledCount))
  mp.f.write("]")
  mp.f.write(" ", mp.doneCount, "/", mp.totalCount)

  mp.f.cursorMoveLine(-downCount)

proc initMultiprog*(slotsCount: int; totalCount = -1; outFile = stdout): Multiprog =
  result.slots = newSeq[bool](slotsCount)
  result.f = outFile

  if totalCount == -1:
    result.totalCount = 0
  else:
    result.totalCount = totalCount
    result.isTotalCountGiven = true

  for _ in 0 ..< slotsCount + 1:
    result.f.writeLine("")
  result.f.cursorUp(slotsCount + 1)

proc `totalCount=`*(mp: var Multiprog; totalCount: Natural) =
  mp.totalCount = totalCount
  mp.isTotalCountGiven = true

proc finish*(mp: var Multiprog) =
  if not mp.isFinished:
    mp.isFinished = true
    mp.f.cursorDown(mp.slots.len - mp.curLine)
    mp.f.writeLine("")

proc startJob*(mp: var Multiprog; message: string): JobId =
  mp.checkState()

  if not mp.isTotalCountGiven:
    inc mp.totalCount

  let slotIdx = mp.slots.find(false)
  mp.slots[slotIdx] = true

  mp.f.cursorMoveLine(slotIdx - mp.curLine)
  mp.curLine = slotIdx
  mp.f.eraseLine()
  mp.f.write(message)
  mp.writeProgressLine()

  JobId(slotIdx)

proc finishJob*(mp: var Multiprog; jobId: JobId; message: string) =
  mp.checkState()

  let slotIdx = jobId.int

  mp.f.cursorMoveLine(slotIdx - mp.curLine)
  mp.curLine = slotIdx
  mp.f.eraseLine()
  mp.f.write(message)

  mp.slots[slotIdx] = false
  inc mp.doneCount

  mp.writeProgressLine()

  if mp.isTotalCountGiven and mp.doneCount == mp.totalCount:
    mp.finish()
