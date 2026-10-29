:Namespace qr
⍝ User command ]TOOLS.QR: display text as a QR code.

    ∇ r←List
      r←⎕NS''
      r.Name←'QR'
      r.Group←'TOOLS'
      r.Desc←'Display text as a QR code'
      r.Parse←'1L -level=L M Q H'
    ∇

    ∇ r←Run(Cmd Input);level
      level←'M'
      :If 0≢Input.level ⋄ level←Input.level ⋄ :EndIf
      :Trap 10 11
          r←level QR⊃Input.Arguments
      :Else
          ⎕DMX.EM ⎕SIGNAL ⎕DMX.EN
      :EndTrap
    ∇

    ∇ r←level Help Cmd
      r←⊂'Display text as a QR code'
      r,←⊂'    ]',Cmd,' <text> [-level=L|M|Q|H]'
      :If 0=level
          r,←'' (']',Cmd,' -??   ⍝ for more information')
      :Else
          r,←''
          r,←⊂'<text>    the rest of the line, encoded as UTF-8 unless it is all digits or'
          r,←⊂'          all in the QR alphanumeric set (0-9 A-Z space $%*+-./:)'
          r,←⊂'-level=   error correction level: L 7%, M 15% (default), Q 25%, H 30%'
          r,←''
          r,←⊂'Each character holds two modules, top and bottom; filled is dark. The quiet'
          r,←⊂'zone is not included. On a dark background the code appears inverted.'
          r,←''
          r,←⊂'Example:  ]',Cmd,' https://www.dyalog.com -level=Q'
      :EndIf
    ∇

    ∇ r←{level}QR text;⎕IO;⎕ML;ecl;AN;mode;cnt;payload;v;na;raw;totcw;ECC;BLK;dcw;cc;need;ver;cap;bits;data;exp;log;xor;mul;gen;rsrem;nb;eb;ns;k;blocks;g;final;s;M;F;c;fp;ap;pos;ctr;i;j;p;rt;up;coords;db;masks;bch;vbits;fpos;pen;C;best;fmt
      ⍝ Encode text as a QR code (ISO/IEC 18004, model 2, versions 1-40).
      ⍝ level: error correction level, one of 'L' 'M' 'Q' 'H' (default 'M').
      ⍝ text:  character vector. Encoded in numeric, alphanumeric or byte mode,
      ⍝        whichever is the most compact single mode for the whole text.
      ⍝        Byte mode uses UTF-8.
      ⍝ r:     character matrix of ' ▀▄█'. Each character holds two vertically
      ⍝        stacked modules (top half, bottom half); a filled half is a dark
      ⍝        module. The quiet zone is not included.
      ⎕IO←0 ⋄ ⎕ML←1
      :If 900⌶⍬ ⋄ level←'M' ⋄ :EndIf
      :If (1≠≢,level)∨0≠10|⎕DR level
          'Left argument must be one of L M Q H'⎕SIGNAL 11
      :EndIf
      ecl←'LMQH'⍳1 ⎕C⊃,level
      :If ecl=4 ⋄ 'Left argument must be one of L M Q H'⎕SIGNAL 11 ⋄ :EndIf
      :If (1<⍴⍴text)∨0≠10|⎕DR text
          'Right argument must be a character vector'⎕SIGNAL 11
      :EndIf
      text←,text

      ⍝ Data segment: mode index (numeric, alphanumeric, byte), character count, payload bits.
      AN←'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:'
      :If (0<≢text)∧∧/text∊⎕D
          mode←0 ⋄ c←⎕D⍳text ⋄ cnt←≢c ⋄ k←⌊cnt÷3
          payload←,⍉(10⍴2)⊤10⊥⍉(k,3)⍴c
          c←(3×k)↓c
          :If 0<≢c ⋄ payload,←((1+3×≢c)⍴2)⊤10⊥c ⋄ :EndIf
      :ElseIf (0<≢text)∧∧/text∊AN
          mode←1 ⋄ c←AN⍳text ⋄ cnt←≢c ⋄ k←⌊cnt÷2
          payload←(,⍉(11⍴2)⊤45⊥⍉(k,2)⍴c),,⍉(6⍴2)⊤(2×k)↓c
      :Else
          mode←2 ⋄ c←'UTF-8'⎕UCS text ⋄ cnt←≢c
          payload←,⍉(8⍴2)⊤c
      :EndIf

      ⍝ Symbol capacity. Rows of ECC and BLK are levels L M Q H, columns are versions 1-40:
      ⍝ error correction codewords per block, and number of blocks.
      ECC←4 40⍴0
      ECC[0;]←7 10 15 20 26 18 20 24 30 18 20 24 26 30 22 24 28 30 28 28 28 28 30 30 26 28 30 30 30 30 30 30 30 30 30 30 30 30 30 30
      ECC[1;]←10 16 26 18 24 16 18 22 22 26 30 22 22 24 24 28 28 26 26 26 26 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28 28
      ECC[2;]←13 22 18 26 18 24 18 22 20 24 28 26 24 20 30 24 28 28 26 30 28 30 30 30 30 28 30 30 30 30 30 30 30 30 30 30 30 30 30 30
      ECC[3;]←17 28 22 16 22 28 26 26 24 28 24 28 22 24 24 30 28 28 26 28 30 24 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30 30
      BLK←4 40⍴0
      BLK[0;]←1 1 1 1 1 2 2 2 2 4 4 4 4 4 6 6 6 6 7 8 8 9 9 10 12 12 12 13 14 15 16 17 18 19 19 20 21 22 24 25
      BLK[1;]←1 1 1 2 2 4 4 4 5 5 5 8 9 9 10 10 11 13 14 16 17 17 18 20 21 23 25 26 28 29 31 33 35 37 38 40 43 45 47 49
      BLK[2;]←1 1 2 2 4 4 6 6 8 8 8 10 12 16 12 17 16 18 21 20 23 23 25 27 29 34 34 35 38 40 43 45 48 51 53 56 59 62 65 68
      BLK[3;]←1 1 2 4 4 4 5 6 8 8 11 11 16 16 18 16 19 21 25 25 25 34 30 32 35 37 40 42 45 48 51 54 57 60 63 66 70 74 77 81
      v←1+⍳40
      na←2+⌊v÷7                                      ⍝ alignment pattern positions per axis
      raw←(64+v×128+16×v)-((v≥2)×(na×¯10+25×na)-55)+36×v≥7  ⍝ data and EC modules
      totcw←⌊raw÷8
      dcw←(4 40⍴totcw)-ECC×BLK

      ⍝ Smallest version whose data capacity holds mode, count and payload.
      cc←3 3⍴10 12 14 9 11 13 8 16 16              ⍝ count bits by mode, version class
      need←4+(≢payload)+cc[mode;+/v∘.>9 26]
      :If ~∨/need≤8×dcw[ecl;]
          'Text too long for a QR code at this error correction level'⎕SIGNAL 10
      :EndIf
      ver←1+⊃⍸need≤8×dcw[ecl;]
      cap←8×dcw[ecl;ver-1]

      bits←(,(4⍴2)⊤1 2 4[mode]),((cc[mode;+/ver>9 26]⍴2)⊤cnt),payload
      bits,←(4⌊cap-≢bits)⍴0                          ⍝ terminator
      bits,←(8|-≢bits)⍴0
      data←2⊥⍉(8,⍨(≢bits)÷8)⍴bits
      data,←((cap÷8)-≢data)⍴236 17

      ⍝ Reed-Solomon over GF(256), primitive polynomial x^8+x^4+x^3+x^2+1.
      xor←{2⊥((8⍴2)⊤⍺+0×⍵)≠(8⍴2)⊤⍵+0×⍺}
      exp←,1
      :While 255>≢exp
          g←2×⊃⌽exp
          :If g≥256 ⋄ g←(g-256)xor 29 ⋄ :EndIf
          exp,←g
      :EndWhile
      log←256⍴0 ⋄ log[exp]←⍳255
      mul←{(⍺≠0)×(⍵≠0)×exp[255|log[⍺]+log[⍵]]}
      eb←ECC[ecl;ver-1]
      gen←(-eb)↑1                                    ⍝ monic generator, leading term omitted
      :For i :In ⍳eb
          gen←(gen mul exp[i])xor 1↓gen,0
      :EndFor
      rsrem←{⊃{(1↓⍵,0)xor gen mul ⍺ xor⊃⍵}/(⌽⍵),⊂eb⍴0}

      ⍝ Split into blocks (short blocks first, the rest one data codeword longer) and interleave.
      nb←BLK[ecl;ver-1]
      ns←nb-nb|totcw[ver-1]
      k←(⌊totcw[ver-1]÷nb)-eb
      blocks←(1+(k+ns≤⍳nb)/⍳nb)⊆data
      final←((,⍉↑{⍵,(1+k-≢⍵)⍴¯1}¨blocks)~¯1),,⍉↑rsrem¨blocks

      ⍝ Function patterns. M holds module colours (1 dark), F marks function modules.
      s←17+4×ver
      M←s s⍴0 ⋄ F←s s⍴0
      M[6;]←M[;6]←0=2|⍳s ⋄ F[6;]←F[;6]←1           ⍝ timing patterns
      c←|3-⍳7 ⋄ fp←2≠c∘.⌈c                          ⍝ finder pattern
      M[⍳8;⍳8]←0 ⋄ M[⍳7;⍳7]←fp ⋄ F[⍳8;⍳8]←1
      M[⍳8;s-8-⍳8]←0 ⋄ M[⍳7;s-7-⍳7]←fp ⋄ F[⍳8;s-8-⍳8]←1
      M[s-8-⍳8;⍳8]←0 ⋄ M[s-7-⍳7;⍳7]←fp ⋄ F[s-8-⍳8;⍳8]←1
      :If ver≥2
          pos←6,⌽(s-7)-(2×⌊(5+(8×ver)+3×na[ver-1])÷4×na[ver-1]-1)×⍳na[ver-1]-1
          c←|2-⍳5 ⋄ ap←1≠c∘.⌈c                      ⍝ alignment pattern
          p←(≢pos)-1
          :For ctr :In (,⍳2⍴≢pos)~(0 0)(0 p)(p 0)
              M[pos[ctr[0]]+¯2+⍳5;pos[ctr[1]]+¯2+⍳5]←ap
              F[pos[ctr[0]]+¯2+⍳5;pos[ctr[1]]+¯2+⍳5]←1
          :EndFor
      :EndIf
      F[8;⍳9]←F[⍳9;8]←1 ⋄ F[8;s-8-⍳8]←F[s-8-⍳8;8]←1  ⍝ format information
      M[s-8;8]←1                                     ⍝ dark module

      ⍝ BCH code: data bits followed by the remainder modulo generator ⍺.
      bch←{⍵,⍺{(≢⍵)<≢⍺:⍵ ⋄ ⍺∇1↓⍵≠(≢⍵)↑⍺×⊃⍵}⍵,(¯1+≢⍺)⍴0}
      :If ver≥7
          vbits←⌽1 1 1 1 1 0 0 1 0 0 1 0 1 bch(6⍴2)⊤ver ⍝ least significant bit first
          i←⍳18
          M[(⌊i÷3),¨s-11-3|i]←vbits ⋄ F[(⌊i÷3),¨s-11-3|i]←1
          M[(s-11-3|i),¨⌊i÷3]←vbits ⋄ F[(s-11-3|i),¨⌊i÷3]←1
      :EndIf

      ⍝ Data placement: two-module-wide columns from the right, alternating upwards
      ⍝ and downwards, skipping the vertical timing column.
      rt←((s-1)-2×⍳(s-7)÷2),5 3 1
      up←0=2|⌊(rt+1)÷2
      coords←⊃,/{,((⌽⍣(⍵[1]))⍳s)∘.,⍵[0]-0 1}¨↓⍉↑rt up
      coords←coords/⍨~F[coords]
      db←,⍉(8⍴2)⊤final
      M[(≢db)↑coords]←db

      ⍝ Masks, indexed by row i and column j.
      i←(⍳s)∘.⊣⍳s ⋄ j←(⍳s)∘.⊢⍳s ⋄ p←i×j
      masks←(0=2|i+j)(0=2|i)(0=3|j)(0=3|i+j)(0=2|(⌊i÷2)+⌊j÷3)(0=(2|p)+3|p)(0=2|(2|p)+3|p)(0=2|(2|i+j)+3|p)

      ⍝ Format information positions, least significant bit first: two copies.
      fpos←((0 1 2 3 4 5 7 8 8 8 8 8 8 8 8),¨8 8 8 8 8 8 8 8 7 5 4 3 2 1 0),((8⍴8),¨s-1+⍳8),(s-7-⍳7),¨8

      ⍝ Penalty score: runs of five or more, 2x2 blocks, finder-like patterns, dark balance.
      ⍝ Each candidate is scored with its format information in place. A finder-like
      ⍝ pattern is 1 0 1 1 1 0 1 with four light modules on either side, where modules
      ⍝ beyond the symbol edge count as light.
      pen←{
          run←{l←(1↓b,≢⍵)-b←⍸1,2≠/⍵ ⋄ +/(l≥5)×l-2}
          n1←+/run¨(↓⍵),↓⍉⍵
          n2←3×+/,(2∧/2∧⌿⍵)∨2∧/2∧⌿~⍵
          fl←{P←(s,s+8)↑(s,-s+4)↑⍵ ⋄ W←(1 4⍴0)⍷P
              +/,((1 7⍴1 0 1 1 1 0 1)⍷P)∧((-⍴W)↑0 ¯4↓W)∨(⍴W)↑0 7↓W}
          n3←40×(fl ⍵)+fl⍉⍵
          n4←10×⌊(10×|(s×s)-2×+/,⍵)÷s×s
          n1+n2+n3+n4
      }
      C←⍬ ⋄ best←⍬
      :For k :In ⍳8
          fmt←⌽1 0 1 0 1 0 0 0 0 0 1 0 0 1 0≠1 0 1 0 0 1 1 0 1 1 1 bch(,(2⍴2)⊤1 0 3 2[ecl]),(3⍴2)⊤k
          g←M≠(~F)∧k⊃masks
          g[fpos]←fmt,fmt
          C,←⊂g ⋄ best,←pen g
      :EndFor
      M←C⊃⍨best⍳⌊/best

      C←((2÷⍨s+1),2,s)⍴M⍪0                          ⍝ pairs of rows
      r←' ▀▄█'[C[;0;]+2×C[;1;]]
    ∇

:EndNamespace
