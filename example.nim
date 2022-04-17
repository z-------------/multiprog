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
  PoolSize = 8
  Count = 50
var
  inputs = collect(for i in 0..<Count: i)
  mp = initMultiprog(PoolSize, inputs.len)

proc doStuff(n: int): Future[void] {.async.} =
  let jobId = mp.startJob("working on " & $n & "...")
  await sleepAsync(rand(500..1500))
  mp.finishJob(jobId, "done with " & $n)

waitFor asyncPool(inputs.mapIt(() => doStuff(it)), PoolSize)

echo "Done doing stuff."
