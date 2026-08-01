# FPGA Ethernet/UDP Frame Parser

🇫🇷 [Version française](README.fr.md)

A VHDL pipeline that receives raw RMII signals, reassembles bytes, parses Ethernet/IPv4/UDP headers, extracts the UDP payload, and verifies frame integrity via CRC32.

This project implements the core building blocks found in low-latency market data feed handlers: RMII frame reception, Ethernet/IP/UDP header parsing, payload extraction, and CRC-based integrity verification.

## Architecture

```
RXD (2 bits/cycle)
      │
      ▼
 ┌───────────┐   byte_out    ┌─────────────┐   payload_byte
 │ rmii_rx   │──────────────▶│ eth_parser  │──────────────────▶
 │           │  byte_valid   │             │   payload_valid
 └───────────┘──────────────▶│             │──────────────────▶
                              │             │   frame_error
                       ┌─────▶│             │──────────────────▶
                       │      └─────────────┘
                       │             │ preamble_out
                       │             ▼
                  ┌────┴────┐
                  │ crc32   │
                  └─────────┘
```

`rmii_rx` reassembles 2-bit RMII nibbles into bytes. `eth_parser` walks through the frame (preamble/SFD, Ethernet header, IP header, UDP header, payload), filters on EtherType (IPv4), IP protocol (UDP), and destination port, and streams out the payload. `crc32` runs a running CRC32 over the frame in parallel; `eth_parser` compares the final value against the expected magic residue (`0xDEBB20E3`) to flag `frame_error`.

`top_level` wires the three modules together and handles reset sequencing on power-up.

## Files

| File | Description |
|------|-------------|
| `rmii_rx.vhd` | Receives raw RMII signals (2 bits/cycle) and reassembles them into 8-bit bytes with a valid pulse. |
| `eth_parser.vhd` | State machine that parses Ethernet, IPv4, and UDP headers, filters by EtherType/protocol/port, and extracts the UDP payload. |
| `crc32.vhd` | Computes a running CRC32 over the frame (Ethernet CRC-32 polynomial) to verify frame integrity. |
| `top_level.vhd` | Top-level module that wires `rmii_rx`, `eth_parser`, and `crc32` together and handles reset sequencing. |
| `tb_rmii_rx.vhd` | Standalone testbench for `rmii_rx` — sends full bytes via clock-aligned RMII nibbles and asserts correct byte reassembly, single-cycle `byte_valid` pulse, and reset behavior when `CRS_DV` drops mid-byte. |
| `tb_eth_parser.vhd` | Standalone testbench for `eth_parser` — drives `byte_in`/`byte_valid`/`crc_in` directly to test valid frames, CRC mismatches, and EtherType filtering. |
| `tb_crc32.vhd` | Standalone testbench for `crc32` — verifies reset behavior, correct accumulation gating (`preamble_out`/`byte_valid`/`CRS_DV`), and the final CRC residue against a reference frame. |
| `tb_top_level.vhd` | Integration testbench for the full `top_level` module — drives raw RMII bits through the complete pipeline with a valid reference frame and checks `frame_error` stays low end-to-end. |

## Frame format expected

- **EtherType**: `0x0800` (IPv4) — other types are dropped.
- **IP protocol**: `0x11` (UDP) — other protocols are dropped.
- **UDP destination port**: `0x04D2` (1234) — other ports are dropped.
- **IP header**: fixed 20-byte header assumed (no IP options / variable IHL support).

## Running the testbenches

Each `tb_*.vhd` file is self-contained and can be simulated independently (e.g. in Vivado, ModelSim, or GHDL) against its corresponding module. Testbenches use VHDL `assert` statements, so a simulator will report a clear `error` severity message if any check fails, rather than requiring manual waveform inspection.

Example with GHDL:
```bash
ghdl -a rmii_rx.vhd tb_rmii_rx.vhd
ghdl -e tb_rmii_rx
ghdl -r tb_rmii_rx
```

## Known limitations

- Fixed 20-byte IP header assumed — frames with IP options (IHL > 5) will be parsed incorrectly.
- No AXI-Stream-style backpressure — `payload_valid` is a raw pulse, not a ready/valid handshake.
- No VLAN tag (802.1Q) support.
- Latency and resource utilization have not yet been characterized on hardware.
