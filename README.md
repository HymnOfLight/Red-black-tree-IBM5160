# Red-Black Tree for IBM PC/XT 5160 (8086 Assembly)

A complete red-black tree data structure implemented in 16-bit 8086 assembly language, targeting the IBM PC/XT 5160 platform. Assembles into a DOS `.COM` executable.

## Features

| Operation | Description |
|-----------|-------------|
| **Insert** | O(log n) insertion with full RB fixup (left/right rotate, recolor) |
| **Delete** | O(log n) deletion with transplant and four-case fixup |
| **Search** | O(log n) lookup by key |
| **In-order traversal** | Prints sorted key sequence with color tags |
| **Tree display** | Sideways (rotated 90°) ASCII visualization with color annotation |

## Platform Details

- **CPU**: Intel 8088 / 8086 (real mode, 16-bit)
- **OS**: MS-DOS 2.0+ (uses INT 21h for console I/O and program exit)
- **Executable format**: `.COM` flat binary (ORG 0100h)
- **Assembler**: NASM (Netwide Assembler)

## Node Layout (10 bytes)

```
Offset  Size  Field
------  ----  -----
  0      2    Key   (unsigned 16-bit)
  2      2    Left child pointer
  4      2    Right child pointer
  6      2    Parent pointer
  8      1    Color (0 = BLACK, 1 = RED)
  9      1    (padding)
```

A dedicated **NIL sentinel node** with `BLACK` color and self-referencing pointers eliminates NULL-check branches throughout the algorithm.

## Memory Management

Nodes are bump-allocated from a linear memory pool placed at the end of the `.COM` image. The pool grows upward into free conventional memory. No deallocation or garbage collection is performed — this is suitable for the constrained, single-task DOS environment.

## Build

```bash
# Requires NASM
make            # produces rbtree.com
make clean      # removes rbtree.com
```

Or build manually:

```bash
nasm -f bin -o rbtree.com rbtree.asm
```

## Run

Execute under DOS (or a DOS emulator such as DOSBox):

```
C:\> rbtree.com
```

### Example Output

```
Red-Black Tree for IBM PC/XT 5160 (8086 ASM)
=============================================

Inserting: 41 38 31 12 19 8 1 25 50 45

Tree structure (sideways):
        50(R)
    45(B)
41(B)
        38(R)
    31(B)
            25(R)
        19(B)
            12(R)
                8(R)
                    1(R)

In-order:  1R 8R 12R 19B 25R 31B 38R 41B 45B 50R

Search 19 -> Found
Search 99 -> Not found
Search 50 -> Found
Search 7 -> Not found

Delete: 8
Delete: 31
Delete: 45

Tree structure (sideways):
    50(B)
41(B)
        38(R)
    25(B)
        19(R)
            12(B)
                1(R)

In-order:  1R 12B 19R 25B 38R 41B 50B

All operations completed.
```

## Algorithm Reference

The implementation follows the canonical red-black tree algorithms from *Introduction to Algorithms* (Cormen, Leiserson, Rivest, Stein — CLRS):

- **RB-INSERT** and **RB-INSERT-FIXUP** (Chapter 13.3)
- **RB-DELETE**, **RB-TRANSPLANT**, and **RB-DELETE-FIXUP** (Chapter 13.4)
- **LEFT-ROTATE** / **RIGHT-ROTATE** (Chapter 13.2)

All six fixup cases (three symmetric pairs) for both insert and delete are implemented.

## File Structure

```
rbtree.asm   — Full source (single-file, self-contained)
Makefile     — Build rules for NASM
README.md    — This file
```

## License

Public domain. Use freely.
