
# API: multiprog

```nim
import multiprog
```

## **type** Multiprog


```nim
Multiprog[T] = object
```

## **type** JobId


```nim
JobId = distinct int
```

## **proc** init


```nim
proc init(__553648190: typedesc[Multiprog]; totalCount = -1; outFile = stdout;
 trimMessages = true; tag: typedesc = DefaultTag): Multiprog[tag]
```

## **proc** totalCount=


```nim
proc totalCount=(mp: var Multiprog; totalCount: Natural)
```

## **proc** finish


```nim
proc finish(mp: var Multiprog)
```

## **proc** startJob


```nim
proc startJob(mp: var Multiprog; message: string): JobId
```

## **proc** updateJob


```nim
proc updateJob(mp: var Multiprog; jobId: JobId; message: string)
```

## **proc** finishJob


```nim
proc finishJob(mp: var Multiprog; jobId: JobId; message: string)
```

## **proc** log


```nim
proc log(mp: var Multiprog; message: string)
```
