## Copied and modified from cligen/textUt, which is Copyright (c) 2015,2016,2017,2018,2019,2020,2021 Charles L. Blake.

type NoCSI_OSC = object  ## Call-to-call state used by the noCSI_OSC iterator
  inCSI, inOSC, postEsc: bool

var nc0: NoCSI_OSC        ## A default `nc` which is all 0/false

iterator noCSI_OSC(a: openArray[char], nc: var NoCSI_OSC = nc0): (int, char) =
  ## Iterate over chars in `a` skipping CSI/OSC term escape seqs (`"\e[..m"`,
  ## `"\e]..\e\\"`). See en.wikipedia.org/wiki/ANSI_escape_code "Fe Escape".
  ## To aid buffered use, if provided, `nc` can propagate parser state.
  var i = 0
  while i < a.len:
    let c = a[i]
    if nc.inCSI:
      if ord(c) in 0x40..0x7E: nc.inCSI = false
    elif nc.inOSC:
      if c == '\e':
        if (i + 1) < a.len and a[i + 1] == '\\':
          nc.inOSC = false
          inc i
      elif c == '\a':
        nc.inOSC = false
    elif nc.postEsc:
      if   c == '[': nc.inCSI = true
      elif c == ']': nc.inOSC = true
      else:
        yield (i, '\e')
        yield (i, c)
      nc.postEsc = (c == '\e')
    elif c == '\e':
      nc.postEsc = true
    else: yield (i, c)
    inc i

proc trim*(a: string; len: int): string =
  # Adapted from printedLen.
  # TODO doesn't seem to correctly estimate the width of JKC characters
  var skip = 0
  var prevI = 0
  var printedLen = 0
  for (i, c) in a.noCSI_OSC:
    if skip > 0: dec skip
    else:
      inc printedLen
      if printedLen > len:
        break
      skip = if   c.uint <= 127: 0
             elif c.uint shr 5 == 0b110:     1
             elif c.uint shr 4 == 0b1110:    2
             elif c.uint shr 3 == 0b11110:   3
             elif c.uint shr 2 == 0b111110:  4
             elif c.uint shr 1 == 0b1111110: 5
             else: 0
    prevI = i
  if printedLen <= len:
    a
  else:
    a.substr(0, prevI - 1)
