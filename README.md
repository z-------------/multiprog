
# API: multiprog

```nim
import multiprog
```

## **type** Multiprog


```nim
Multiprog = object
 curSlotIdx: int
 jobs: seq[bool]
 slots: seq[string]
 isTotalCountGiven: bool
 totalCount: int
 doneCount: int
 f: File
 isFinished: bool
 progressBar: proc (width, doneCount, totalCount: int): string
```

## **type** JobId


```nim
JobId = distinct int
```

## **proc** defaultProgressBar


```nim
func defaultProgressBar(width, doneCount, totalCount: int): string {.noInit, raises: [].}
```

## **proc** initMultiprog


```nim
proc initMultiprog(jobsCount: int; totalCount = -1; outFile = stdout;
 progressBar = defaultProgressBar): Multiprog {.raises: [IOError, OSError], tags: [WriteIOEffect, RootEffect].}
```

## **proc** totalCount=


```nim
proc totalCount=(mp: var Multiprog; totalCount: Natural)
```

## **proc** finish


```nim
proc finish(mp: var Multiprog) {.raises: [OSError, IOError], tags: [RootEffect, WriteIOEffect].}
```

## **proc** startJob


```nim
proc startJob(mp: var Multiprog; message: string): JobId {.raises: [OSError, IOError, Exception], tags: [RootEffect, WriteIOEffect].}
```

## **proc** updateJob


```nim
proc updateJob(mp: var Multiprog; jobId: JobId; message: string) {.raises: [OSError, IOError], tags: [RootEffect, WriteIOEffect].}
```

## **proc** finishJob


```nim
proc finishJob(mp: var Multiprog; jobId: JobId; message: string) {.raises: [OSError, IOError, Exception], tags: [RootEffect, WriteIOEffect].}
```

## **proc** log


```nim
proc log(mp: var Multiprog; message: string) {.raises: [OSError, IOError], tags: [RootEffect, WriteIOEffect].}
```
