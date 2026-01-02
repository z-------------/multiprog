# Copyright (C) 2022-2024 Zack Guard
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

import pkg/textslots
import std/math
import std/strutils
import std/terminal

const
  ProgressSlotIdx = 0
  StatusSlotStartIdx = 1

func defaultProgressBar(width, doneCount, totalCount: int): string {.raises: [].}

type
  ProgressBarProc* = proc (width, doneCount, totalCount: int): string {.noSideEffect, gcsafe, raises: [].}
  Multiprog* = object
    ts: Textslots
    isTotalCountGiven: bool
    totalCount: int
    doneCount: int
    isFinished: bool
    eraseProgressBar: bool
    progressBar {.requiresInit.}: ProgressBarProc = defaultProgressBar
    slotStates: seq[bool]
  JobId* = distinct int

template checkState(mp: Multiprog) =
  assert not mp.isFinished

template jobSlotIdx[T: JobId or int](jobId: T): int =
  StatusSlotStartIdx + jobId.int

func defaultProgressBar(width, doneCount, totalCount: int): string =
  let
    rhs = " " & $doneCount & "/" & $totalCount
    size = width - rhs.len - 2
    ratio =
      if totalCount <= 0:
        0.0
      else:
        doneCount / totalCount
    filledCount = floor(ratio * size.float).int
  result = newStringOfCap(width)
  result.add("[")
  result.add('#'.repeat(filledCount))
  result.add(' '.repeat(size - filledCount))
  result.add("]")
  result.add(rhs)

proc writeProgressLine(mp: var Multiprog) =
  let line = mp.progressBar(terminalWidth() - 1, mp.doneCount, mp.totalCount)
  mp.ts.writeSlot(ProgressSlotIdx, line, erase = false)

proc init*(
  _: typedesc[Multiprog];
  totalCount = -1;
  outFile = stdout;
  trimMessages = true;
  eraseProgressBar = false;
  progressBar: ProgressBarProc = nil;
): Multiprog =
  result = Multiprog(
    ts: Textslots.init(outFile, trimMessages),
    eraseProgressBar: eraseProgressBar,
  )
  if progressBar != nil:
    result.progressBar = progressBar

  if totalCount == -1:
    result.totalCount = 0
  else:
    result.totalCount = totalCount
    result.isTotalCountGiven = true

  result.writeProgressLine()

proc `totalCount=`*(mp: var Multiprog; totalCount: Natural) =
  mp.totalCount = totalCount
  mp.isTotalCountGiven = true

proc finish*(mp: var Multiprog) =
  if not mp.isFinished:
    mp.isFinished = true
    let firstIdx =
      if mp.eraseProgressBar:
        0
      else:
        1
    mp.ts.clearSlots(firstIdx .. mp.ts.slots.high)
    mp.ts.cursorToSlot(1)

proc startJob*(mp: var Multiprog; message: string): JobId =
  mp.checkState()

  if not mp.isTotalCountGiven:
    inc mp.totalCount

  let jobIdx = block:
    let freeJobIdx = mp.slotStates.find(false)
    if freeJobIdx != -1:
      # use existing free job
      mp.slotStates[freeJobIdx] = true
      freeJobIdx
    else:
      mp.ts.addSlot()
      mp.slotStates.add(true)
      mp.ts.slots.high - 1

  mp.ts.writeSlot(jobSlotIdx(jobIdx), message)
  mp.writeProgressLine()

  JobId(jobIdx)

proc updateJob*(mp: var Multiprog; jobId: JobId; message: string) =
  mp.checkState()
  mp.ts.writeSlot(jobSlotIdx(jobId), message)

proc finishJob*(mp: var Multiprog; jobId: JobId; message: string) =
  mp.checkState()

  mp.updateJob(jobId, message)

  mp.slotStates[jobId.int] = false
  inc mp.doneCount

  mp.writeProgressLine()

proc log*(mp: var Multiprog; message: string) =
  mp.ts.log(message)
