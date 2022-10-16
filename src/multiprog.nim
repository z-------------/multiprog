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

import std/math
import std/strutils
import std/terminal

const
  ProgressSlotIdx = 0
  StatusSlotStartIdx = 1

type
  Multiprog* = object
    curSlotIdx: int
    jobs: seq[bool]
    slots: seq[string]
    isTotalCountGiven: bool
    totalCount: int
    doneCount: int
    f: File
    isFinished: bool
  JobId* = distinct int

template checkState(mp: Multiprog) =
  doAssert not mp.isFinished

template jobSlotIdx[T: JobId or int](jobId: T): int =
  StatusSlotStartIdx + jobId.int

proc cursorMoveLine(f: File; count: int) =
  try:
    if count < 0:
      f.cursorUp(-count)
    elif count > 0:
      f.cursorDown(count)
    f.setCursorXPos(0)
  except OSError:
    discard

proc cursorToSlot(mp: var Multiprog; slotIdx: int) =
  mp.f.cursorMoveLine(slotIdx - mp.curSlotIdx)
  mp.curSlotIdx = slotIdx

proc writeSlot(mp: var Multiprog; slotIdx: int; message: string; erase: static bool = true) =
  mp.slots[slotIdx] = message
  mp.cursorToSlot(slotIdx)
  when erase:
    mp.f.eraseLine()
  mp.f.write(message)
  mp.f.flushFile()

func buildProgressLine(mp: Multiprog; width: int): string =
  let
    doneCountStr = $mp.doneCount
    totalCountStr = $mp.totalCount
    rhsSize = 1 + doneCountStr.len + 1 + totalCountStr.len + 1
    size = width - rhsSize - 2
    ratio = mp.doneCount / mp.totalCount
    filledCount = floor(ratio * size.float).int
  result.add("[")
  result.add('#'.repeat(filledCount))
  result.add(' '.repeat(size - filledCount))
  result.add("]")
  result.add(" " & doneCountStr & "/" & totalCountStr)

proc writeProgressLine(mp: var Multiprog) =
  let line = mp.buildProgressLine(terminalWidth())
  mp.writeSlot(ProgressSlotIdx, line, erase = false)

proc initMultiprog*(jobsCount: int; totalCount = -1; outFile = stdout): Multiprog =
  let slotsCount = jobsCount + 1

  result.jobs = newSeq[bool](jobsCount)
  result.slots = newSeq[string](slotsCount)
  result.f = outFile

  if totalCount == -1:
    result.totalCount = 0
  else:
    result.totalCount = totalCount
    result.isTotalCountGiven = true

  for _ in 0 ..< slotsCount:
    result.f.writeLine("")
  result.f.cursorUp(slotsCount)

proc `totalCount=`*(mp: var Multiprog; totalCount: Natural) =
  mp.totalCount = totalCount
  mp.isTotalCountGiven = true

proc finish*(mp: var Multiprog) =
  if not mp.isFinished:
    mp.isFinished = true
    for jobIdx in 0..mp.jobs.high:
      mp.writeSlot(jobSlotIdx(jobIdx), "")
    mp.cursorToSlot(ProgressSlotIdx)
    mp.f.writeLine("")

proc startJob*(mp: var Multiprog; message: string): JobId =
  mp.checkState()

  if not mp.isTotalCountGiven:
    inc mp.totalCount

  let jobIdx = mp.jobs.find(false)
  mp.jobs[jobIdx] = true

  mp.writeSlot(jobSlotIdx(jobIdx), message)
  mp.writeProgressLine()

  JobId(jobIdx)

proc updateJob*(mp: var Multiprog; jobId: JobId; message: string) =
  mp.checkState()
  mp.writeSlot(jobSlotIdx(jobId), message)

proc finishJob*(mp: var Multiprog; jobId: JobId; message: string) =
  mp.checkState()

  mp.updateJob(jobId, message)

  mp.jobs[jobId.int] = false
  inc mp.doneCount

  mp.writeProgressLine()

  if mp.isTotalCountGiven and mp.doneCount == mp.totalCount:
    mp.finish()

proc log*(mp: var Multiprog; message: string) =
  mp.checkState()

  mp.cursorToSlot(0)
  mp.f.eraseLine()
  mp.f.writeLine(message)
  for line in mp.slots:
    mp.f.eraseLine()
    mp.f.writeLine(line)
  mp.curSlotIdx = mp.slots.len
