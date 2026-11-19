# Self-Tuning FPGA Wind Tunnel Controller

ECE 287 Digital System Design, Miami University. Team: **James Wood, Cale Smith**.
Demo: **December 11, 2026**.

A closed-loop fan speed controller for a 3D-printed desktop wind tunnel, written entirely in Verilog on a Terasic DE1-SoC (Cyclone V `5CSEMA5F31C6`). The FPGA drives a Noctua NF-P12 redux-1700 PWM fan, measures its speed from the tachometer, holds a target RPM with a fixed-point PID controller, runs step tests on itself, and tunes its own PID gains.

## Status

| Milestone | What | State |
|---|---|---|
| M1 | PWM fan control + live RPM on HEX | **Done: working on hardware** (fan curve in `data/`, plot in `docs/`) |
| M2 | VGA live graph | **Code complete, simulation passing.** Next: monitor test |
| M3 | PID closed-loop + mode FSM | Skeleton (`pid_controller.v`, `mode_fsm.v`) + Python model |
| M4 | Hardware step-test metrics | Skeleton (`step_test.v`) |
| M5 | Relay auto-tune | Skeleton (`autotune.v`) |

## Repository layout

```
rtl/                      Verilog design (all synthesizable)
  wind_tunnel_top.v       board top level (M1 + M2)
  pwm_gen.v               25 kHz PWM generator
  tach_period.v           tach synchronizer, glitch filter, revolution timer
  seq_divider.v           sequential 32-bit divider (Lab 11 style)
  rpm_meter.v             tach -> RPM (tach_period + seq_divider)
  four_decimal_vals.v     0..9999 on four 7-seg digits (from Lab 8 display)
  two_decimal_vals.v      0..99 on two 7-seg digits
  seven_segment.v         hex -> 7-seg decoder (Labs 3/8/11)
  vga_timing.v            640x480 @ 60 Hz sync generator
  stripchart.v            scrolling RPM graph (ring buffer in on-chip RAM)
  pid_controller.v        [skeleton M3]
  mode_fsm.v              [skeleton M3]
  step_test.v             [skeleton M4]
  autotune.v              [skeleton M5]
tb/                       testbenches (self-checking: print PASS/FAIL)
  fan_model.v             behavioral Noctua fan (simulation only)
wind_tunnel.qpf           Quartus project (open this)
wind_tunnel_top.qsf       Quartus settings + pin assignments
quartus/
  wind_tunnel_pins.qsf    original pin list (already imported)
  wind_tunnel.sdc         clock + timing constraints
data/                     measured data (m1_fan_curve.csv)
docs/                     plots and screenshots for the wiki
python/
  pid_model.py            bit-accurate PID + fan model, test-vector generator
```

## 1. Open the Quartus project

The project is already set up in the repo root. You need Quartus Prime Lite **23.1std** with **Cyclone V device support** (`cyclonev-23.1std.0.991.qdz`, install via Tools → Install Devices).

1. `git pull`, then in Quartus **File → Open Project** → `wind_tunnel.qpf` (repo root).
2. **Processing → Start Compilation.** In the Timing Analyzer, confirm the `CLOCK_50` clock exists and setup slack is positive. If it says "no clocks defined", add `quartus/wind_tunnel.sdc` under Assignments → Settings → Files.
3. **Tools → Programmer** → attach `output_files/wind_tunnel.sof` to the **5CSEMA5** device (not SOCVHPS) → Start.

Only commit `wind_tunnel.qpf` and `wind_tunnel_top.qsf` from Quartus, never `db/` or `output_files/`. Only one person changes Quartus settings at a time.

The skeleton modules compile but aren't instantiated in the top level yet, so Quartus will warn they're unused. That's expected.

## 2. Wiring (read before connecting anything)

Fan connector (standard 4-pin PWM): **1 = GND, 2 = +12 V, 3 = tach, 4 = PWM.** Identify pins by the connector key, not wire color.

DE1-SoC header JP1 (GPIO_0): **pin 1 = GPIO_0[0], pin 2 = GPIO_0[1], pin 11 = 5 V, pin 12 = GND, pin 29 = 3.3 V, pin 30 = GND.** Verify against the DE1-SoC User Manual's GPIO header figure before wiring.

| Fan pin | Goes to | Notes |
|---|---|---|
| 1 GND | 12 V supply GND **and** JP1 pin 12 | Common ground is required |
| 2 +12 V | 12 V supply + | **Never** near any FPGA pin |
| 3 Tach | JP1 pin 2 (`FAN_TACH`) | 10 kΩ pull-up from this wire to JP1 pin 29 (3.3 V). Never pull up to 5 V or 12 V |
| 4 PWM | JP1 pin 1 (`FAN_PWM`), **see step 2a** | |

### 2a. Measure the fan's PWM pin first (one-time, 1 minute)

Noctua's PWM spec says the fan pulls its PWM input up internally to **3.3 V or 5 V**, and recommends driving it push-pull. The FPGA's pins are 3.3 V only, so:

1. Power the fan from 12 V with **only** pins 1 and 2 connected. It runs at full speed (no PWM signal = full speed).
2. Measure fan pin 4 to ground with a multimeter.
3. **≤ 3.4 V:** connect pin 4 straight to JP1 pin 1. Keep `PWM_INVERT = 0` (default).
4. **≈ 5 V:** do **not** connect it to the FPGA directly. Use an N-MOSFET (2N7000) or NPN (2N3904 + 1 kΩ base resistor): FPGA pin → gate/base, drain/collector → fan pin 4, source/emitter → GND. Set `PWM_INVERT = 1` in `wind_tunnel_top.v`.

Use the bench supply or a 12 V adapter rated ≥ 0.2 A (the fan draws about 0.08 A).

## 3. M1 hardware test

1. Program the board. Press KEY0 (reset).
2. `SW[6:0]` = duty % in binary (e.g. `0110010` = 50%). `SW[9]` = full speed. HEX5:HEX4 show the duty %, HEX3–HEX0 show RPM.
3. Expected readings (Noctua spec, ±10–20%): 100% ≈ 1700 RPM, 20% ≈ 550 RPM, roughly linear in between.
4. LEDR0 flickers with the tach, LEDR1 = no tach signal, LEDR2 toggles on each new measurement.
5. **Record a duty → RPM table** (20%, 30%, ... 100%). It's the fan's real curve, it goes in the report, and it calibrates `python/pid_model.py`.
6. If RPM reads 0 with the fan spinning: check the tach pull-up and common ground, then put `FAN_TACH` and `u_rpm/u_tach/clean` in Signal Tap.

**Result (Nov 19, 2026):** 379 RPM at 20% up to 1630 RPM at 100% (`data/m1_fan_curve.csv`, `docs/m1_fan_curve.png`). Full speed is within 4% of Noctua's 1700 RPM spec; the low end runs well below spec and the curve bends (≈20 RPM per % at low duty, ≈12.5 at high duty).

## 3b. M2 hardware test (VGA)

Connect a VGA monitor to the board's VGA port. Program, press KEY0.

| Step | Do | Pass if |
|---|---|---|
| a | **SW[7] up** (test pattern) | 8 vertical bars: white, yellow, cyan, green, magenta, red, blue, black, with a thin white border on all four edges |
| b | SW[7] down, fan at 50% | Green line scrolls left at ~row 230; 1000 RPM reference line just above it |
| c | Change duty 50% → 90% → 30% | Line steps up and down with a visible lag curve |
| d | **SW[8] up** (pause) | Graph freezes; HEX still updates |

Graph scale: 1 px = 4 RPM, 0 RPM on the bright bottom axis, grid every 200 RPM (brighter line = 1000 RPM), 32 s across the screen. Simulated screenshots: `docs/sim_testpattern.png`, `docs/sim_graph.png`.

If the left or right white border is missing in step (a), the picture is shifted. If the monitor says "no signal" or "out of range", check VGA_HS/VGA_VS pins in the Pin Planner.

## 4. Simulation

All testbenches are self-checking: they print `PASS` or `FAIL` lines.

| Testbench | Checks | Run time |
|---|---|---|
| `tb_pwm_gen.v` | Period = 2000 clocks; high time = duty at 0, 1, 20%, 50%, 100%, over-range | < 1 s |
| `tb_seq_divider.v` | 508 divisions vs. Verilog `/` and `%`, incl. the real RPM numbers | < 1 s |
| `tb_four_decimal_vals.v` | Digit decode, leading-zero blanking, 9999 clamp | < 1 s |
| `tb_rpm_meter.v` | 1700/1000/550/1200 RPM within ±2 with noise spikes + 3% pole asymmetry; stall → 0 | ~1.5 min |
| `tb_top.v` | Whole design + simulated fan at 50/90/25% duty; RPM within 2%; HEX shows duty | ~2.5 min |
| `tb_vga_timing.v` | 2 frames: 800×525 total, 640×480 active, hsync 96 px @656, vsync 2 lines @490 | ~5 s |
| `tb_stripchart.v` | Picture aligned to syncs (16/96/48 porches), bar edges on exact pixels, trace at correct row, scrolling, pause; writes `sim_*.ppm` screenshots | ~20 s |

**Questa / ModelSim (from the labs):** add the testbench plus `rtl/*.v` (and `tb/fan_model.v` for `tb_top`), compile, simulate, run -all.

**Icarus Verilog (optional, free):**
```
iverilog -g2005 -o sim.vvp tb/tb_rpm_meter.v rtl/*.v && vvp sim.vvp
iverilog -g2005 -o sim.vvp tb/tb_top.v tb/fan_model.v rtl/*.v && vvp sim.vvp
```

**PID model:** `python python/pid_model.py` compares P, PI, and PID on the simulated fan and writes test vectors with `--vectors pid_vectors.txt`. The fan model uses our measured curve. With the default gains, P-only control settles ~260–340 RPM short of the setpoint; PI gets within ~1 RPM. That result is the core argument for the PID design.

## Conventions

- Sequential logic: `always @(posedge clk or negedge rst)`, active-low reset on KEY0 (course convention).
- One module per file, file name = module name.
- Every new module gets a self-checking testbench before it goes into the top level.
- Asynchronous inputs (switches, keys, tach) go through a 2-flip-flop synchronizer.
- Signed math: declare `reg signed` everywhere and sign-extend explicitly.
- Tag each working milestone in git (`m1-working`, `m2-working`, ...) and record a short video clip.

## Citations

- Noctua PWM specifications white paper (PWM/tach electrical spec, 2 pulses per revolution).
- Noctua NF-P12 redux-1700 PWM specifications (1700 RPM max, 550 RPM at 20% PWM).
- Terasic DE1-SoC User Manual (pin assignments, GPIO header).
- `seven_segment.v` and the decimal display structure come from the ECE 287 lab skeletons (Labs 3, 8, 11).
- First drafts of the Verilog and testbenches were written with AI assistance (Claude) and reviewed, tested, and modified by the team.
