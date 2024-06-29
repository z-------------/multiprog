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

import ./multiprog/textUt
import std/math
import std/strutils
import std/terminal

const
  ProgressSlotIdx = 0
  StatusSlotStartIdx = 1

type
  Multiprog*[T] = object
    curSlotIdx: int
    jobs: seq[bool] ## the state of each job
    slots: seq[string] ## the latest contents of each slot, including the progress bar
    isTotalCountGiven: bool
    totalCount: int
    doneCount: int
    f: File
    isInitialized: bool
    isFinished: bool
    trimMessages: bool
  JobId* = distinct int
  DefaultTag = object

template checkState(mp: Multiprog) =
  assert mp.isInitialized
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
        message.trim(terminalWidth() - 1)
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

func progressBar(_: typedesc[DefaultTag]; width, doneCount, totalCount: int): string {.noInit.} =
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

proc writeProgressLine[T](mp: var Multiprog[T]) =
  mixin progressBar
  let line = progressBar(T, terminalWidth() - 1, mp.doneCount, mp.totalCount)
  mp.writeSlot(ProgressSlotIdx, line, erase = false)

proc init*(
  _: typedesc[Multiprog];
  totalCount = -1;
  outFile = stdout;
  trimMessages = true;
  tag: typedesc = DefaultTag;
): Multiprog[tag] =
  result.jobs = newSeq[bool]()
  result.slots = newSeq[string](1)
  result.f = outFile
  result.trimMessages = trimMessages

  if totalCount == -1:
    result.totalCount = 0
  else:
    result.totalCount = totalCount
    result.isTotalCountGiven = true

  # reserve space for the progress bar
  result.f.writeLine("")
  result.f.cursorUp(1)
  result.writeProgressLine()

  result.isInitialized = true

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

  let jobIdx = block:
    let freeJobIdx = mp.jobs.find(false)
    if freeJobIdx >= 0:
      # use existing free job
      mp.jobs[freeJobIdx] = true
      freeJobIdx
    else:
      # make new job and slot
      mp.cursorToSlot(mp.slots.high)
      for _ in 1..2:
        # twice because we want to have one empty line under the last slot (why?)
        mp.f.writeLine("")
      mp.curSlotIdx += 2
      mp.slots.add("")
      mp.jobs.add(true)
      mp.jobs.high

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
