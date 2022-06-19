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
import std/strutils
import std/math

type
  Multiprog* = object
    curSlotIdx: int
    slots: seq[bool]
    isTotalCountGiven: bool
    totalCount: int
    doneCount: int
    f: File
    isFinished: bool
  JobId* = distinct int

template checkState(mp: Multiprog) =
  doAssert not mp.isFinished

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

proc cursorToSlot(mp: var Multiprog; slotIdx: int) =
  mp.f.cursorMoveLine(slotIdx - mp.curSlotIdx)
  mp.curSlotIdx = slotIdx

proc writeSlot(mp: var Multiprog; slotIdx: int; message: string) =
  mp.cursorToSlot(slotIdx)
  mp.f.eraseLine()
  mp.f.write(message)
  mp.f.flushFile()

proc writeProgressLine(mp: var Multiprog) =
  mp.cursorToSlot(-1)
  let
    doneCountStr = $mp.doneCount
    totalCountStr = $mp.totalCount
    rhsSize = 1 + doneCountStr.len + 1 + totalCountStr.len + 1
    size = terminalWidth() - rhsSize - 2
    ratio = mp.doneCount / mp.totalCount
    filledCount = floor(ratio * size.float).int
  mp.f.write("[")
  mp.f.write('#'.repeat(filledCount))
  mp.f.write(' '.repeat(size - filledCount))
  mp.f.write("]")
  mp.f.write(" ", doneCountStr, "/", totalCountStr)
  mp.f.flushFile()

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
  result.f.cursorUp(slotsCount)

proc `totalCount=`*(mp: var Multiprog; totalCount: Natural) =
  mp.totalCount = totalCount
  mp.isTotalCountGiven = true

proc finish*(mp: var Multiprog) =
  if not mp.isFinished:
    mp.isFinished = true
    for slotIdx in 0..mp.slots.high:
      mp.writeSlot(slotIdx, "")
    mp.cursorToSlot(-1)
    mp.f.writeLine("")

proc startJob*(mp: var Multiprog; message: string): JobId =
  mp.checkState()

  if not mp.isTotalCountGiven:
    inc mp.totalCount

  let slotIdx = mp.slots.find(false)
  mp.slots[slotIdx] = true

  mp.writeSlot(slotIdx, message)
  mp.writeProgressLine()

  JobId(slotIdx)

proc finishJob*(mp: var Multiprog; jobId: JobId; message: string) =
  mp.checkState()

  let slotIdx = jobId.int

  mp.writeSlot(slotIdx, message)

  mp.slots[slotIdx] = false
  inc mp.doneCount

  mp.writeProgressLine()

  if mp.isTotalCountGiven and mp.doneCount == mp.totalCount:
    mp.finish()
