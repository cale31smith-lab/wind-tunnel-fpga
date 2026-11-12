"""
pid_model.py - bit-accurate fixed-point PID model + simulated Noctua fan.

ECE 287 Final Project - Self-Tuning FPGA Wind Tunnel Controller

Purpose
  1. Try gains on a laptop in seconds instead of recompiling Quartus.
  2. Generate test vectors that pid_controller.v must match EXACTLY
     (same integer math, same shifts, same clamps).

Formats (keep in sync with rtl/pid_controller.v):
  setpoint, measured : unsigned 16-bit RPM
  e                  : signed, setpoint - measured
  kp, ki, kd         : unsigned Q8.8 (256 = 1.0)
  integ              : signed sum of e, clamped to +/- INTEG_MAX
  u = (kp*e + ki*integ + kd*(e - e_prev)) >> 8      (arithmetic shift)
  duty = DUTY_BIAS + u, clamped to [DUTY_MIN, DUTY_MAX]
  Anti-windup: skip integ += e when the output is saturated and e pushes
  it further into saturation.

Usage
  python pid_model.py                      # run default step test
  python pid_model.py --kp 128 --ki 4 --kd 0 --vectors pid_vectors.txt
"""
import argparse

DUTY_MIN, DUTY_MAX, DUTY_BIAS = 400, 2000, 1000
INTEG_MAX = 200_000
TICK_S = 0.01                       # 100 Hz control loop


class FixedPID:
    def __init__(self, kp, ki, kd):
        self.kp, self.ki, self.kd = kp, ki, kd
        self.integ = 0
        self.e_prev = 0
        self.duty = DUTY_BIAS

    def step(self, setpoint, measured):
        e = setpoint - measured
        de = e - self.e_prev

        # conditional integration (anti-windup)
        sat_hi = self.duty >= DUTY_MAX and e > 0
        sat_lo = self.duty <= DUTY_MIN and e < 0
        if not (sat_hi or sat_lo):
            self.integ = max(-INTEG_MAX, min(INTEG_MAX, self.integ + e))

        acc = self.kp * e + self.ki * self.integ + self.kd * de
        u = acc >> 8                # Python >> on negatives floors, like Verilog >>>
        self.duty = max(DUTY_MIN, min(DUTY_MAX, DUTY_BIAS + u))
        self.e_prev = e
        return self.duty, e, self.integ


class NoctuaFan:
    """First-order model of the NF-P12 redux-1700 PWM (same as tb/fan_model.v)."""

    def __init__(self, tau_s=0.6, rpm=0.0):
        self.tau_s = tau_s
        self.rpm = rpm

    @staticmethod
    def target(duty):
        frac = duty / 2000.0
        if frac >= 0.2:
            return 550.0 + (frac - 0.2) * (1700.0 - 550.0) / 0.8
        return 550.0 * frac / 0.2

    def step(self, duty, dt=TICK_S):
        self.rpm += (self.target(duty) - self.rpm) * dt / self.tau_s
        return self.rpm


def simulate(kp, ki, kd, sp_low=800, sp_high=1400, seconds=8.0, vectors=None):
    pid = FixedPID(kp, ki, kd)
    fan = NoctuaFan(rpm=sp_low)
    rows = []
    n = int(seconds / TICK_S)
    for k in range(n):
        sp = sp_low if k < n // 4 else sp_high          # step at 25% of the run
        meas = int(fan.rpm)                              # FPGA sees an integer RPM
        duty, e, integ = pid.step(sp, meas)
        fan.step(duty)
        rows.append((k, sp, meas, e, integ, duty))

    if vectors:
        with open(vectors, "w") as f:
            f.write(f"# kp={kp} ki={ki} kd={kd} (Q8.8)\n")
            f.write("# tick setpoint measured e integ duty\n")
            for r in rows:
                f.write(" ".join(str(v) for v in r) + "\n")
    return rows


def metrics(rows, sp_low, sp_high):
    step_k = next(i for i, r in enumerate(rows) if r[1] == sp_high)
    after = rows[step_k:]
    span = sp_high - sp_low
    peak = max(r[2] for r in after)
    overshoot = max(0.0, 100.0 * (peak - sp_high) / span)

    def first_cross(level):
        return next((i for i, r in enumerate(after) if r[2] >= level), None)

    t10, t90 = first_cross(sp_low + 0.1 * span), first_cross(sp_low + 0.9 * span)
    rise = (t90 - t10) * TICK_S if t10 is not None and t90 is not None else None

    band = 0.05 * span
    last_out = max((i for i, r in enumerate(after) if abs(r[2] - sp_high) > band), default=-1)
    settle = (last_out + 1) * TICK_S
    sse = abs(sp_high - sum(r[2] for r in after[-50:]) / 50)
    return rise, overshoot, settle, sse


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kp", type=int, default=128, help="Q8.8 (128 = 0.5)")
    ap.add_argument("--ki", type=int, default=4, help="Q8.8 per 10 ms tick")
    ap.add_argument("--kd", type=int, default=0, help="Q8.8")
    ap.add_argument("--vectors", default=None, help="write test vectors to this file")
    args = ap.parse_args()

    for label, (kp, ki, kd) in {
        "P only": (args.kp, 0, 0),
        "PI": (args.kp, args.ki, 0),
        "PID": (args.kp, args.ki, args.kd),
    }.items():
        rows = simulate(kp, ki, kd, vectors=args.vectors if label == "PID" else None)
        rise, os_, settle, sse = metrics(rows, 800, 1400)
        rise_s = f"{rise:.2f} s" if rise is not None else "never"
        print(f"{label:7s} kp={kp:4d} ki={ki:3d} kd={kd:3d} | rise {rise_s:>7s} | "
              f"overshoot {os_:5.1f}% | settle {settle:5.2f} s | steady error {sse:5.1f} RPM")
    if args.vectors:
        print(f"wrote {args.vectors}")


if __name__ == "__main__":
    main()
