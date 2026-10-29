# QR codes in the Dyalog APL session

Single self-contained APL function and user command wrapper implementing QR Code model 2 (ISO/IEC 18004), versions 1 to 40, with all four error correction levels, drawing with the block characters ` ▀▄█`:

```
      ]QR https://github.com/abrudz/qr -level=Q
█▀▀▀▀▀█ ▀ ▀▄███▀   ▀█ █▀▀▀▀▀█
█ ███ █  █ ██▄██ ▄▀ ▄ █ ███ █
█ ▀▀▀ █ █▀▀▄▀▄█▀▄▄█▀█ █ ▀▀▀ █
▀▀▀▀▀▀▀ ▀ ▀▄▀▄▀▄█ █ ▀ ▀▀▀▀▀▀▀
 ▀██▀▀▀▀ █▀██▄  █▄███ ▄██▄▄ █
▄▀▄ ▄▀▀▀▀▄▄▀▄▄█ ▄ █▄███ ▄▀ ▄
█ ▀█ ▀▀▄▀█ ▀ ▀▀ ▀█ █▄█▄▀▄▄▀██
 ▀▄█▄▄▀██    ▀▀█▄█▄▄█  ▀▄▄  ▄
█▄█▄▄█▀▄█▄█▀█▄▄▄▀ ▄▄ ▄▄█▄██▄█
█ █▄▄▄▀▄█ ▀▀▀▄██▀  ▄  █ ▄█▀▄
▀ ▀ ▀ ▀ █▀ ▄▀▄ ▀▄▀▄▀█▀▀▀█▄▀▄█
█▀▀▀▀▀█ █▀▀▄▀ ▀▀▄ ▀██ ▀ █▄  ▄
█ ███ █ █▀██▄█ ▄▄ ▀▄██▀█▀▀▀▀
█ ▀▀▀ █ █▀ ▀▀▄▄ ▄▀███▀▀▀██ █
▀▀▀▀▀▀▀      ▀▀  ▀▀▀ ▀  ▀ ▀
```

## Quick start

Download the namespace into the active session, ready to use as a function:

```
      ]get github.com/abrudz/qr/blob/main/qr.dyalog
#.qr
      qr.QR 'Hello, world'
```

Save it to your user command folder to install the user command; it is available immediately, and in every later session:

```
      ]save qr [HOME]MyUCMDs/ -m
      ]QR Hello, world
```

## Requirements

Dyalog APL 18.0 or later, Unicode edition.

## Installation

As an alternative to the quick start, place [`qr.dyalog`](qr.dyalog) in a folder that Dyalog searches for user commands. The default user folder is `MyUCMDs` in your documents folder on Windows and in your home directory on macOS and Linux. Alternatively, add the folder containing this repository to the search path and reset the user commands:

```
      ]settings cmddir ,/path/to/qr -permanent
      ]ureset
```

## Usage

### User command

```
      ]TOOLS.QR <text> [-level=L|M|Q|H]
```

The text is the rest of the line, apart from the `-level` modifier. Enclose it in double quotes to preserve runs of spaces or to include text that would otherwise be parsed as a modifier; the quotes are not encoded. The group name can be omitted (`]QR`) when no other user command is called `QR`.

`]QR -?` and `]QR -??` show help.

### Function

The function `QR` can be used on its own, without installing the user command:

```
      ⎕FIX'file://path/to/qr.dyalog'
      r←'H' qr.QR 'Hello, world'
      ⍴r
13 25
```

`QR` is ambivalent; the optional left argument is the error correction level, a character `'L'`, `'M'`, `'Q'` or `'H'` (default `'M'`). The right argument is a character vector or scalar. The result is a character matrix.

### Error correction levels

| Level | Recoverable codewords |
|-------|-----------------------|
| L     | about 7%              |
| M     | about 15% (default)   |
| Q     | about 25%             |
| H     | about 30%             |

Higher levels survive more damage at the cost of a larger symbol.

## Behaviour

- The text is encoded in a single segment using the most compact mode that covers all of it: numeric (digits only), alphanumeric (`0-9`, `A-Z`, space and `$%*+-./:`) or byte. Byte mode carries the text as UTF-8, without an ECI header; common readers detect UTF-8 automatically.
- The smallest version (symbol size) that holds the data at the requested level is chosen. The largest texts that fit are 7089 digits, 4296 alphanumeric characters or 2953 bytes at level L, and 3057, 1852 or 1273 at level H. Longer text signals `LIMIT ERROR`; an invalid argument signals `DOMAIN ERROR`.
- Of the eight data masks, the one with the lowest ISO/IEC 18004 penalty score is used, scoring each candidate with its format information in place.
- Each character represents two vertically adjacent modules: the upper half shows the top module and the lower half the bottom one, and a filled half is a dark module. The symbol has an odd number of rows, so the bottom half of the last row is always light.
- The quiet zone (the light margin a scanner needs around the symbol) is not part of the result. On a light background, the surrounding page or window provides it. On a dark background the symbol appears with its colours inverted, which not all scanners accept.

## Testing

[`tests/verify.py`](tests/verify.py) checks the encoder against two independent implementations: the [segno](https://github.com/heuer/segno) encoder and the [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp) decoder. It encodes several hundred texts covering every level and mode, all 40 versions and the exact capacity limits, and requires that

- every symbol decodes to the original text at the requested level,
- every ASCII symbol is identical, module for module, to segno's symbol with the same mask, and
- the chosen version, or the capacity error, matches segno for every length.

The test runs `dyalogscript`, which must be on the path:

```
python -m venv .venv
.venv/bin/pip install -r tests/requirements.txt
.venv/bin/python tests/verify.py
```
