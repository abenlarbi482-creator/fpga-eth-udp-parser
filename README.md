# FPGA Ethernet/UDP Frame Parser → AXI-Stream

A VHDL pipeline that receives raw RMII signals, reassembles bytes, parses Ethernet/IPv4/UDP headers, extracts the UDP payload, verifies frame integrity via CRC32, and exposes the result as a standard AXI-Stream interface (`TDATA`/`TVALID`/`TLAST`/`TREADY`) across an asynchronous clock domain.

This project implements the core building blocks found in low-latency market data feed handlers: RMII frame reception, Ethernet/IP/UDP header parsing, payload extraction, CRC-based integrity verification, and a clock-domain-crossing bridge to a downstream AXI-Stream consumer.



`rmii_rx` reassembles 2-bit RMII nibbles into bytes. `eth_parser` walks through the frame (preamble/SFD, Ethernet header, IP header, UDP header, payload), filters on EtherType (IPv4), IP protocol (UDP), and destination port, and streams out the payload. `crc32` runs a running CRC32 over the frame in parallel, continuing through the received FCS itself; `eth_parser` compares the final register value against the expected magic residue (`0xDEBB20E3`) and asserts `frame_validated` or `frame_damaged` accordingly.

The payload byte stream, still in the `ETH_REFCLK` domain, is written into `asynchronous_FIFO`, a dual-clock FIFO (Gray-coded pointers, 2-stage synchronizers) that crosses into the `READ_CLK` domain. Because the FIFO is not First-Word-Fall-Through (its `data_out` register updates one cycle after `read` is asserted), `top_level` implements a small valid/ready bridge (`rd_en` / `out_valid`) on the read side to turn the FIFO's `empty` flag into a proper AXI-Stream `TVALID`/`TREADY` handshake, holding `TDATA`/`TLAST` stable whenever the downstream consumer deasserts `TREADY`.

`top_level` wires all modules together, handles reset sequencing on power-up (`ETH_RSTN` release delay), double-flops `ETH_CRSDV`/`ETH_RXD` for metastability, and exposes the final AXI-Stream output alongside `payload_length`, `frame_validated`, `frame_error`, and `frame_damaged`.

## Project structure

```
.
├── src/
│   ├── rmii_rx.vhd
│   ├── eth_parser.vhd
│   ├── crc32.vhd
│   ├── asynchronous_FIFO.vhd
│   └── top_level.vhd
├── tb/
│   ├── tb_rmii_rx.vhd
│   ├── tb_eth_parser.vhd
│   ├── tb_crc32.vhd
│   ├── tb_asynchronous_FIFO.vhd
│   └── tb_top_level.vhd
└── README.md
```

## Files

### `src/`

| File | Description |
|------|-------------|
| `rmii_rx.vhd` | Receives raw RMII signals (2 bits/cycle) and reassembles them into 8-bit bytes with a valid pulse. |
| `eth_parser.vhd` | State machine that parses Ethernet, IPv4, and UDP headers, filters by EtherType/protocol/port, extracts the UDP payload, and validates the frame against the CRC32 residue. |
| `crc32.vhd` | Computes a running CRC32 (Ethernet polynomial, reflected, no final inversion) over the frame including the received FCS, producing a fixed residue for a valid frame. |
| `asynchronous_FIFO.vhd` | Dual-clock FIFO (Gray-code pointer synchronization) bridging the `ETH_REFCLK` write domain to the `READ_CLK` read domain. Non-FWFT: `data_out` is valid one cycle after `read` is asserted. |
| `top_level.vhd` | Top-level module wiring `rmii_rx`, `eth_parser`, `crc32`, and `asynchronous_FIFO` together, and implementing the FIFO-to-AXI-Stream valid/ready bridge. |

### `tb/`

| File | Description |
|------|-------------|
| `tb_rmii_rx.vhd` | Standalone testbench for `rmii_rx` — sends bytes via clock-aligned RMII nibbles and checks correct byte reassembly and `byte_valid` timing. |
| `tb_eth_parser.vhd` | Standalone testbench for `eth_parser` — drives `byte_in`/`byte_valid`/`crc_in` directly to test valid frames, CRC mismatches, and EtherType/protocol/port filtering. |
| `tb_crc32.vhd` | Standalone testbench for `crc32` — checks reset behavior, accumulation gating (`preamble_out`/`byte_valid`/`CRS_DV`), and the final residue against a reference frame. |
| `tb_asynchronous_FIFO.vhd` | Standalone testbench for `asynchronous_FIFO` — checks write/read across independent clocks, `empty`/`full` flag behavior, and data integrity through the CDC. |
| `tb_top_level.vhd` | Integration testbench for the full pipeline — drives raw RMII bits through a reference frame, consumes the AXI-Stream output with a simulated backpressure pattern, and asserts frame status, `payload_length`, per-byte payload content, and `TLAST` placement. |

## Interfaces

### Inputs
| Signal | Width | Description |
|--------|-------|-------------|
| `ETH_REFCLK` | 1 | RMII reference clock (write-side clock domain). |
| `READ_CLK` | 1 | AXI-Stream consumer clock (read-side clock domain, asynchronous to `ETH_REFCLK`). |
| `rst` / `READ_RESET` | 1 | Asynchronous resets for the write and read domains respectively. |
| `ETH_CRSDV` / `ETH_RXD` | 1 / 2 | Raw RMII carrier-sense/data-valid and data signals. |
| `MY_MAC` | 48 | Local MAC address used for destination filtering (broadcast and multicast also accepted). |
| `TREADY` | 1 | Downstream AXI-Stream consumer ready signal. |

### Outputs
| Signal | Width | Description |
|--------|-------|-------------|
| `ETH_RSTN` | 1 | Released after a fixed startup delay following `rst`. |
| `payload_length` | 16 | UDP payload length in bytes, valid once the frame reaches the payload state. |
| `frame_validated` | 1 | Pulses when the frame passed all filters and the CRC32 residue check. |
| `frame_error` | 1 | Asserted when the frame is dropped due to a filter mismatch (MAC, EtherType, protocol, or port). |
| `frame_damaged` | 1 | Asserted when the frame passed all filters but failed the CRC32 check. |
| `TDATA` / `TVALID` / `TLAST` | 8 / 1 / 1 | AXI-Stream payload output, `READ_CLK` domain. |

## Frame format expected

- **EtherType**: `0x0800` (IPv4) — other types are dropped.
- **IP protocol**: `0x11` (UDP) — other protocols are dropped.
- **UDP destination port**: `0x04D2` (1234) — other ports are dropped.
- **IP header**: fixed 20-byte header assumed (no IP options / variable IHL support).
- **Destination MAC**: `MY_MAC`, broadcast (`FF:FF:FF:FF:FF:FF`), or multicast (LSB of first octet set) are accepted.

## Running the testbenches
if you modify the reference frame's MAC address, payload, or header fields in `tb_top_level.vhd`, the FCS bytes must be recomputed — the CRC covers the destination MAC through the end of the payload. See the comment above the FCS bytes in the file for the recomputation method.

## Synthesis results

Synthesized for a Xilinx Artix-7 (`xc7a100tcsg324-1`) with Vivado 2025.2:

| Resource | Used | Available | Utilization |
|----------|------|-----------|--------------|
| Slice LUTs | 212 | 63,400 | 0.33% |
| Slice Registers | 205 | 126,800 | 0.16% |
| Block RAM (RAMB18E1) | 1 | 270 | 0.37% |
| DSPs | 0 | 240 | 0% |
| BUFG | 2 | 32 | 6.25% |

The FIFO's behavioral `array` description infers correctly to a single Block RAM tile without synthesis directives. Figures are post-synthesis (pre-place & route); final implemented utilization is typically lower.

## Latency

End-to-end latency (first bit on `ETH_CRSDV` to first valid AXI-Stream beat) was measured at **~4.58 µs** in simulation, using waveform markers between the two events. This is consistent with the theoretical minimum for RMII: at 2 bits/cycle @ 50 MHz (80 ns/byte), the 42 bytes of Ethernet/IP/UDP header preceding the payload alone account for ~3.4 µs, before any FIFO/CDC latency is added.

RMII is the dominant latency contributor by a wide margin — it is not suited for low-latency applications. A production low-latency feed handler would use GMII/RGMII (1 Gbps) or SGMII/XGMII (10 Gbps) instead, reducing header reception time by one to two orders of magnitude.

The FIFO/CDC bridge itself adds a small, variable latency (2–3 `READ_CLK` cycles) due to the Gray-code pointer synchronizers — this is jitter, not a fixed delay, and its magnitude depends on the phase relationship between `ETH_REFCLK` and `READ_CLK`.

## Known limitations

- Fixed 20-byte IP header assumed — frames with IP options (IHL > 5) will be parsed incorrectly.
- No VLAN tag (802.1Q) support.
- `asynchronous_FIFO` silently drops writes on overflow (`full`) with no error/count exposed to the top level.
- RMII limits end-to-end latency to the microsecond range; not representative of a production low-latency path (see Latency section above).
- Timing closure (max `Fmax` per clock domain) has not yet been characterized via `report_timing_summary`.
