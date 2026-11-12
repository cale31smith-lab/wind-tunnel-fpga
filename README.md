# Self-Tuning FPGA Wind Tunnel Controller

ECE 287 Digital System Design, Miami University. Team: **James Wood, Cale Smith**.
Demo: **December 11, 2026**.

A closed-loop fan speed controller for a 3D-printed desktop wind tunnel, written entirely in Verilog on a Terasic DE1-SoC (Cyclone V `5CSEMA5F31C6`). The FPGA drives a Noctua NF-P12 redux-1700 PWM fan, measures its speed from the tachometer, holds a target RPM with a fixed-point PID controller, runs step tests on itself, and tunes its own PID gains.

## Status

| Milestone | What | State |
|---|---|---|
| M1 | PWM fan control + live RPM on HEX | **Code complete, simulation passing.** Next: hardware test |
| M2 | VGA strip chart | Skeleton (`vga_timing.v`, `stripchart.v`) |
| M3 | PID closed-loop + mode FSM | Skeleton (`pid_controller.v`, `mode_fsm.v`) + Python model |
| M4 | Hardware step-test metrics | Skeleton (`step_test.v`) |
| M5 | Relay auto-tune | Skeleton (`autotune.v`) |

## Repository layout

```
rtl/                      Verilog design (all synthesizable)
  wind_tunnel_top.v       board top level (M1 functionality)
  pwm_gen.v               25 kHz PWM generator
  tach_period.v           tach synchronizer, glitch filter, revolution timer
  seq_divider.v           sequential 32-bit divider (Lab 11 style)
  rpm_meter.v             tach -> RPM (tach_period + seq_divider)
  four_decimal_vals.v     0..9999 on four 7-seg digits (from Lab 8 display)
  two_decimal_vals.v      0..99 on two 7-seg digits
  seven_segment.v         hex -> 7-seg decoder (Labs 3/8/11)
  vga_timing.v            [skeleton M2]
  stripchart.v            [skeleton M2]
  pid_controller.v        [skeleton M3]
  mode_fsm.v              [skeleton M3]
  step_test.v             [skeleton M4]
  autotune.v              [skeleton M5]
tb/                       testbenches (self-checking: print PASS/FAIL)
  fan_model.v             behavioral Noctua fan (simulation only)
quartus/
  wind_tunnel_pins.qsf    pin assignments - import into the project
  wind_tunnel.sdc         50 MHz clock constraint
python/
  pid_model.py            bit-accurate PID + fan model, test-vector generator
```

## 1. Create the Quartus project (fresh project, not a copy of a lab)

1. **File → New Project Wizard.** Directory: this repo's `quartus/` folder. Name: `wind_tunnel`. Top-level entity: `wind_tunnel_top`.
2. Add files: everything in `rtl/` and `quartus/wind_tunnel.sdc`.
3. Device: Cyclone V, `5CSEMA5F31C6`.
4. **Assignments → Import Assignments** → `quartus/wind_tunnel_pins.qsf`. Check the Pin Planner shows locations for `FAN_PWM` and `FAN_TACH`.
5. **Processing → Start Compilation.** In the Timing Analyzer, confirm the `CLOCK_50` constraint is applied and there are no failing paths.

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

## 4. Simulation

All testbenches are self-checking: they print `PASS` or `FAIL` lines.

| Testbench | Checks | Run time |
|---|---|---|
| `tb_pwm_gen.v` | Period = 2000 clocks; high time = duty at 0, 1, 20%, 50%, 100%, over-range | < 1 s |
| `tb_seq_divider.v` | 508 divisions vs. Verilog `/` and `%`, incl. the real RPM numbers | < 1 s |
| `tb_four_decimal_vals.v` | Digit decode, leading-zero blanking, 9999 clamp | < 1 s |
| `tb_rpm_meter.v` | 1700/1000/550/1200 RPM within ±2 with noise spikes + 3% pole asymmetry; stall → 0 | ~1.5 min |
| `tb_top.v` | Whole M1 design + simulated fan at 50/90/25% duty; RPM within 2%; HEX shows duty | ~2.5 min |

**Questa / ModelSim (from the labs):** add the testbench plus `rtl/*.v` (and `tb/fan_model.v` for `tb_top`), compile, simulate, run -all.

**Icarus Verilog (optional, free):**
```
iverilog -g2005 -o sim.vvp tb/tb_rpm_meter.v rtl/*.v && vvp sim.vvp
iverilog -g2005 -o sim.vvp tb/tb_top.v tb/fan_model.v rtl/*.v && vvp sim.vvp
```

**PID model:** `python python/pid_model.py` compares P, PI, and PID on the simulated fan and writes test vectors with `--vectors pid_vectors.txt`. With the default gains, P-only control settles ~300 RPM short of the setpoint; PI removes the error. That result is the core argument for the PID design.

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
