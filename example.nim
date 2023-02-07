import multiprog
import pkg/asyncpools
import std/[
  asyncdispatch,
  random,
  sequtils,
  strformat,
  strutils,
  sugar,
]

randomize()

echo "About to do some stuff..."

const
  PoolSize = 4
  Count = 20
  Interval = 250..750
var
  inputs = (0..<Count).toSeq
  mp = initMultiprog(PoolSize, inputs.len)

proc doStuff(n: int): Future[void] {.async.} =
  let jobId = mp.startJob(&"working on {n}...")
  await sleepAsync(rand(Interval))
  if n mod 2 == 0:
    mp.updateJob(jobId, &"working on {n} still...")
  if n mod 3 == 0:
    mp.log(&"logging while working on {n}.")
  await sleepAsync(rand(Interval))
  mp.finishJob(jobId, &"done with {n}")

waitFor asyncPool(inputs.mapIt(() => doStuff(it)), PoolSize)

echo "Done doing stuff."
