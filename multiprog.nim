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
import std/sequtils

const
  ProgressSlotIdx = 0
  StatusSlotStartIdx = 1

type
  ProgressBarProc* = proc (width, doneCount, totalCount: int): string {.noSideEffect, gcsafe, raises: [].}
  Multiprog* = object
    ts: Textslots
    isTotalCountGiven: bool
    totalCount: int
    doneCount: int
    isFinished: bool
    eraseProgressBar: bool
    progressBar {.requiresInit.}: ProgressBarProc
    slotStates: seq[bool]
    useCustomProgress: bool
    customProgresses: seq[tuple[done, total: int]]
  JobId* = distinct int

template checkState(mp: Multiprog) =
  assert not mp.isFinished

template jobSlotIdx[T: JobId or int](jobId: T): int =
  StatusSlotStartIdx + jobId.int

func defaultProgressBar*(formatCount: proc (count: int): string {.noSideEffect, gcsafe, raises: [].} = nil): ProgressBarProc =
  proc (width, doneCount, totalCount: int): string =
    let
      rhs =
        if formatCount != nil:
          " " & formatCount(doneCount) & "/" & formatCount(totalCount)
        else:
          " " & $doneCount & "/" & $totalCount
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
): Multiprog =
  result = Multiprog(
    ts: Textslots.init(outFile, trimMessages),
    eraseProgressBar: eraseProgressBar,
    progressBar: defaultProgressBar(),
  )

  if totalCount == -1:
    result.totalCount = 0
  else:
    result.totalCount = totalCount
    result.isTotalCountGiven = true

  result.writeProgressLine()

proc `progressBar=`*(mp: var Multiprog; progressBar: ProgressBarProc) =
  mp.progressBar = progressBar

proc `totalCount=`*(mp: var Multiprog; totalCount: Natural) =
  mp.totalCount = totalCount
  mp.isTotalCountGiven = true

proc `useCustomProgress=`*(mp: var Multiprog; useCustomProgress: bool) =
  mp.useCustomProgress = useCustomProgress 

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

  if not mp.isTotalCountGiven and not mp.useCustomProgress:
    inc mp.totalCount

  let jobIdx = block:
    let freeJobIdx = mp.slotStates.find(false)
    if freeJobIdx != -1:
      # use existing free job
      mp.slotStates[freeJobIdx] = true
      mp.customProgresses[freeJobIdx] = (0, 0)
      freeJobIdx
    else:
      mp.ts.addSlot()
      mp.slotStates.add(true)
      mp.customProgresses.add((0, 0))
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
  if mp.useCustomProgress:
    mp.customProgresses[jobId.int].done = mp.customProgresses[jobId.int].total
    mp.doneCount = mp.customProgresses.foldl(a + b.done, 0)
  else:
    inc mp.doneCount

  mp.writeProgressLine()

proc log*(mp: var Multiprog; message: string) =
  mp.ts.log(message)

proc updateJobProgress*(mp: var Multiprog; jobId: JobId; done, total: int) =
  if not mp.useCustomProgress:
    raise newException(ValueError, "not allowed unless useCustomProgress is true")
  mp.customProgresses[jobId.int] = (done, total)
  mp.doneCount = mp.customProgresses.foldl(a + b.done, 0)
  mp.totalCount = mp.customProgresses.foldl(a + b.total, 0)
  mp.writeProgressLine()
