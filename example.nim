import pkg/multiprog
import pkg/asyncpools
import pkg/termstyle
import std/[
  asyncdispatch,
  math,
  random,
  sequtils,
  strformat,
  strutils,
  sugar,
]

func progressBar(width, doneCount, totalCount: int): string {.noInit.} =
  let text = (&"{doneCount} / {totalCount} ").align(width)
  let s = floor((doneCount / totalCount) * width.float).int
  text.substr(0, s - 1).bgWhite.black & text.substr(s).underline

when isMainModule:
  randomize()

  echo "About to do some stuff..."

  const
    Count = 20
    Interval = 250..750
  var
    inputs = (0..<Count).toSeq
    mp = Multiprog.init(totalCount = inputs.len, progressBar = progressBar)

  proc doStuff(n: int): Future[void] {.async.} =
    let jobId = mp.startJob(&"working on {n}...")
    await sleepAsync(rand(Interval))
    if n mod 2 == 0:
      mp.updateJob(jobId, "working on " & ($n).bold.blue & " still...")
    if n mod 3 == 0:
      mp.log("logging while " & "working".bold.red & &" on {n}.")
    await sleepAsync(rand(Interval))
    mp.finishJob(jobId, "done".italic.green & &" with {n}")

  waitFor asyncPool(inputs.mapIt(() => doStuff(it)), 4)
  mp.finish()

  echo "Done doing stuff."
