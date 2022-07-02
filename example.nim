import multiprog
import pkg/asyncpools
import std/sequtils
import std/sugar
import std/random
import std/strutils
import std/math

randomize()

echo "About to do some stuff..."

const
  PoolSize = 4
  Count = 20
var
  inputs = (0..<Count).toSeq
  mp = initMultiprog(PoolSize, inputs.len)

proc doStuff(n: int): Future[void] {.async.} =
  let jobId = mp.startJob("working on " & $n & "...")
  await sleepAsync(rand(250..750))
  if n mod 3 == 0:
    mp.log("logging while working on " & $n & ".")
  await sleepAsync(rand(250..750))
  mp.finishJob(jobId, "done with " & $n)

waitFor asyncPool(inputs.mapIt(() => doStuff(it)), PoolSize)

echo "Done doing stuff."
