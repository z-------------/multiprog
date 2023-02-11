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
    progressBar: proc (width, doneCount, totalCount: int): string
    trimMessages: bool
  JobId* = distinct int

template checkState(mp: Multiprog) =
  assert not mp.isFinished

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
  let message = block:
    let message =
      if mp.trimMessages:
        message.substr(0, terminalWidth() - 2)
      else:
        message
    let newlineIdx = message.find(Newlines)
    if newlineIdx != -1:
      message[0 ..< newlineIdx]
    else:
      message

  mp.slots[slotIdx] = message
  mp.cursorToSlot(slotIdx)
  when erase:
    mp.f.eraseLine()
  mp.f.write(message)
  mp.f.flushFile()

func defaultProgressBar*(width, doneCount, totalCount: int): string {.noInit.} =
  let
    rhs = " " & $doneCount & "/" & $totalCount
    size = width - rhs.len - 2
    ratio = doneCount / totalCount
    filledCount = floor(ratio * size.float).int
  result = newStringOfCap(width)
  result.add("[")
  result.add('#'.repeat(filledCount))
  result.add(' '.repeat(size - filledCount))
  result.add("]")
  result.add(rhs)

proc writeProgressLine(mp: var Multiprog) =
  let line = mp.progressBar(terminalWidth() - 1, mp.doneCount, mp.totalCount)
  mp.writeSlot(ProgressSlotIdx, line, erase = false)

proc initMultiprog*(
  jobsCount: int;
  totalCount = -1;
  outFile = stdout;
  progressBar = defaultProgressBar;
  trimMessages = true;
): Multiprog =
  let slotsCount = jobsCount + 1

  result.jobs = newSeq[bool](jobsCount)
  result.slots = newSeq[string](slotsCount)
  result.f = outFile
  result.progressBar = progressBar
  result.trimMessages = trimMessages

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
  for line in message.splitLines:
    mp.f.eraseLine()
    mp.f.writeLine(line)
  for line in mp.slots:
    mp.f.eraseLine()
    mp.f.writeLine(line)
  mp.curSlotIdx = mp.slots.len
