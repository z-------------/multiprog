import pkg/unicodedb/widths
import std/unicode

const
  EscapeStart = Rune('\e'.ord)
  EscapeEnd = Rune('m'.ord)

proc printedLen(r: Rune): int =
  case r.unicodeWidth
  of uwdtAmbiguous, uwdtHalf, uwdtNarrow, uwdtNeutral: 1
  of uwdtFull, uwdtWide: 2

proc trim*(s: string; len: int): string =
  let runes = s.toRunes
  var
    i = runes.low
    prevI = 0
    printedLen = 0
  while i <= runes.high:
    let r = runes[i]
    if r == EscapeStart:
      # skip to end of escape sequence
      while runes[i] != EscapeEnd:
        inc i
    else:
      printedLen += r.printedLen
      if printedLen > len:
        break
    prevI = i
    inc i
  if printedLen > len:
    s.runeSubStr(0, prevI + 1)
  else:
    s
