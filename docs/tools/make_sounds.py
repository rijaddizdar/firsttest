"""Penny's three sounds, synthesised so they are ours outright.

README section 3 is specific: a short happy chime when an answer is right, a
soft "boop" when it isn't — never a buzzer — and a celebration on the Yay!
screen. Kids Category rules make bought or downloaded audio a licence question,
so these are generated from pure tones instead.
"""
import wave, struct, math

RATE = 44100

def tone(freq, seconds, volume=0.5, start=0.0, harmonics=(1.0, 0.35, 0.12)):
    """One bell-ish note: a sine plus two quiet overtones, with a soft attack
    and an exponential decay so nothing ever clicks or sounds harsh."""
    n = int(RATE * seconds)
    out = []
    attack = int(RATE * 0.012)
    for i in range(n):
        t = i / RATE
        env = math.exp(-3.2 * t / seconds)
        if i < attack:
            env *= i / attack
        s = sum(a * math.sin(2 * math.pi * freq * h * t)
                for h, a in enumerate(harmonics, start=1))
        out.append((start + t, volume * env * s / sum(harmonics)))
    return out

def mix(layers, seconds):
    buf = [0.0] * int(RATE * seconds)
    for layer in layers:
        for t, v in layer:
            i = int(t * RATE)
            if 0 <= i < len(buf):
                buf[i] += v
    peak = max(1e-9, max(abs(v) for v in buf))
    return [v / peak * 0.72 for v in buf]      # headroom, never clipping

def write(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767))
                               for s in samples))
    print(f"  {path}  {len(samples)/RATE:.2f}s")

# Right: two rising notes, bright and quick. C6 then E6.
write("App/Resources/Sounds/right.wav", mix([
    tone(1046.50, 0.34, 0.55, start=0.00),
    tone(1318.51, 0.40, 0.55, start=0.09),
], 0.55))

# Not-right: one soft, low, gently falling note. Quiet, round, no buzz.
write("App/Resources/Sounds/wrong.wav", mix([
    tone(349.23, 0.26, 0.42, start=0.00, harmonics=(1.0, 0.18)),
    tone(293.66, 0.30, 0.34, start=0.10, harmonics=(1.0, 0.18)),
], 0.45))

# Celebrate: a little rising arpeggio, C-E-G-C.
write("App/Resources/Sounds/celebrate.wav", mix([
    tone(1046.50, 0.30, 0.50, start=0.00),
    tone(1318.51, 0.30, 0.50, start=0.10),
    tone(1567.98, 0.34, 0.50, start=0.20),
    tone(2093.00, 0.60, 0.55, start=0.32),
], 1.00))
