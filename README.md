# 16-bit ALU in Verilog

A 16-bit combinational ALU written in Verilog, with 16 operations and four status flags (carry, overflow, negative, zero). It is verified with a self-checking testbench that runs 21 directed edge-case tests and 5000 random tests.

This started as an 8-bit ALU with 8 operations and was extended to 16 bits. The extension added carry-in operations, arithmetic shifts, rotates, signed and unsigned compare, and proper status flags.

## Repository structure

```
alu16/
├── rtl/
│   └── alu16.v        # ALU design
├── tb/
│   └── tb_alu16.v     # self-checking testbench
├── docs/
│   └── waveform.png   # simulation waveform
└── README.md
```

## Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 16 | operand A |
| `b` | input | 16 | operand B (b[3:0] is also the shift amount) |
| `sel` | input | 4 | operation select |
| `cin` | input | 1 | carry-in for ADC, borrow-in for SBB |
| `y` | output | 16 | result |
| `carry` | output | 1 | carry / borrow / shifted-out bit |
| `overflow` | output | 1 | signed overflow |
| `negative` | output | 1 | MSB of result |
| `zero` | output | 1 | result is zero |

## Operations

| sel | Operation | Function |
|---|---|---|
| 0000 | ADD | y = a + b |
| 0001 | ADC | y = a + b + cin |
| 0010 | SUB | y = a - b |
| 0011 | SBB | y = a - b - cin |
| 0100 | AND | y = a & b |
| 0101 | OR | y = a \| b |
| 0110 | XOR | y = a ^ b |
| 0111 | NOT | y = ~a |
| 1000 | SLL | shift left logical by b[3:0] |
| 1001 | SRL | shift right logical by b[3:0] |
| 1010 | SRA | shift right arithmetic by b[3:0] (sign bit is copied in) |
| 1011 | ROL | rotate left by b[3:0] |
| 1100 | ROR | rotate right by b[3:0] |
| 1101 | SLT | y = 1 if a < b (signed), else 0 |
| 1110 | SLTU | y = 1 if a < b (unsigned), else 0 |
| 1111 | PASS B | y = b |

## Flags

| Flag | Meaning |
|---|---|
| zero | 1 when y = 0x0000 |
| negative | y[15] |
| carry | ADD/ADC: carry out of bit 15. SUB/SBB: borrow, so 1 when a < b. SLL: last bit shifted out of the MSB. SRL/SRA: last bit shifted out of the LSB. ROL/ROR: last bit rotated around. All other operations: 0 |
| overflow | ADD/ADC: operands have the same sign and the result has a different sign. SUB/SBB: operands have different signs and the result's sign differs from a. All other operations: 0 |

Note that on subtraction, carry = 1 means a borrow happened (the x86 convention). ARM uses the opposite convention.

### Example flag values

| Operation | a | b | y | carry | overflow | Reason |
|---|---|---|---|---|---|---|
| ADD | 7FFF | 0001 | 8000 | 0 | 1 | +32767 + 1 does not fit in signed 16 bits |
| ADD | FFFF | 0001 | 0000 | 1 | 0 | unsigned wrap-around; as signed, -1 + 1 = 0 |
| SUB | 8000 | 0001 | 7FFF | 0 | 1 | -32768 - 1 does not fit in signed 16 bits |
| SUB | 0001 | 0002 | FFFF | 1 | 0 | borrow, since 1 < 2 |
| SRA | 8000 | 0004 | F800 | 0 | 0 | sign bit copied into the top 4 bits |
| SLT | FFFF | 0001 | 0001 | 0 | 0 | -1 < 1 as signed |
| SLTU | FFFF | 0001 | 0000 | 0 | 0 | 65535 > 1 as unsigned |

## Design notes

- The design is fully combinational, using one `always @(*)` block with a `case` on `sel`.
- `y`, `carry`, `overflow` and the internal `temp` register get default values at the start of the always block, and the case has a `default` branch. Together these prevent latch inference.
- A 17-bit `temp` register holds the extra bit. For add and subtract, `temp = a + b` is evaluated at 17 bits, so `temp[16]` is the carry or borrow. For left shifts, the bit pushed past bit 15 lands in `temp[16]`. For right shifts, `a` is padded with a 0 on the right (`{a, 1'b0}`), so the bit pushed past bit 0 lands in `temp[0]`.
- Arithmetic right shift needs `$signed(...) >>> shift`. Without `$signed`, `>>>` fills with zeros exactly like `>>`.
- Signed compare uses `$signed(a) < $signed(b)`. A plain `a < b` on unsigned vectors gives the unsigned result.
- The zero and negative flags are taken from the result `y`, not from the inputs.

## Verification

The testbench `tb/tb_alu16.v` checks itself, so you never need to read the waveform to know whether it passed.

1. **Directed tests (21):** edge cases with hand-calculated answers, including overflow boundaries (7FFF, 8000), all-ones (FFFF), zero results, shift by 0 and by 15, and signed versus unsigned compare.
2. **Random tests (5000):** random `a`, `b`, `cin` and `sel` values, checked against a reference model inside the testbench.

The reference model does every shift and rotate one bit at a time in a `for` loop, unlike the RTL, which shifts in one step. Because the model is written differently from the design, the same mistake is unlikely to appear in both.

Every test compares all five outputs: `y`, carry, overflow, negative and zero. A mismatch prints the inputs together with the received and expected values.

### Result

```
fixed tests done: pass=21 fail=0
all tests done: pass=5021 fail=0
ALL TESTS PASSED
```

![Simulation waveform](docs/waveform.png)

## How to run

### Vivado
1. Add `rtl/alu16.v` as a design source.
2. Add `tb/tb_alu16.v` as a simulation source and set `tb_alu16` as the top.
3. Run Behavioral Simulation.
4. The testbench needs about 50.2 µs of simulation time, but Vivado stops at 1 µs by default. Run it fully with these commands in the Tcl console:
   ```
   restart
   run all
   ```
5. Check the Tcl console for the pass/fail summary.

### Icarus Verilog
```
iverilog -g2005 -o sim rtl/alu16.v tb/tb_alu16.v
vvp sim
gtkwave alu16.vcd
```

## Synthesis

Target: PYNQ-Z2 (xc7z020clg400-1)

| Resource | Used |
|---|---|
| LUTs | _fill in_ |
| Worst path delay | _fill in_ |

## Tools

- Xilinx Vivado
- Icarus Verilog
