"""Synthesize every sound of Sea Battle with numpy (no downloads): python scripts/tools/make_audio.py
Writes 16-bit mono WAVs (44.1 kHz) into assets/audio/. Music is a procedural loop."""
import os
import wave
import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)


def save(name, x, stereo=False):
    x = np.asarray(x, np.float32)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * 0.89
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("audio", name, round(len(x) / SR / (2 if stereo else 1), 2), "s")


def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(int(SR * d))


def lowpass(x, cutoff):
    """One-pole low-pass, cutoff in Hz (array or scalar)."""
    a = np.exp(-2 * np.pi * np.broadcast_to(cutoff, x.shape) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff):
    """FFT brick-ish low-pass for long static filters."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def hp_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 - 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def env(d, attack, decay_pow=3.0):
    tt = t(d)
    e = np.minimum(1, tt / max(attack, 1e-4)) * (1 - tt / d) ** decay_pow
    return e


def cannon():
    d = 2.2
    tt = t(d)
    thump = np.sin(2 * np.pi * (55 * tt - 20 * tt ** 2)) * np.exp(-tt * 6)
    crack = hp_fast(noise(d), 800) * np.exp(-tt * 40)
    rumble = lp_fast(noise(d), 300) * env(d, 0.005, 2.5)
    return thump * 1.0 + crack * 0.5 + rumble * 1.4


def explosion():
    d = 3.0
    tt = t(d)
    body = lp_fast(noise(d), 900) * env(d, 0.004, 3.0)
    sub = np.sin(2 * np.pi * (45 * tt - 10 * tt ** 2)) * np.exp(-tt * 3.5)
    crackle = hp_fast(noise(d), 2500) * (rng.random(len(tt)) > 0.997) * np.exp(-tt * 1.2) * 4
    debris = hp_fast(noise(d), 1500) * np.exp(-((tt - 0.9) ** 2) / 0.2) * 0.15
    return body * 1.3 + sub * 1.0 + crackle + debris


def splash():
    d = 1.8
    tt = t(d)
    burst = hp_fast(lp_fast(noise(d), 4000), 300) * env(d, 0.01, 2.0)
    plop = np.sin(2 * np.pi * (180 * tt - 60 * tt ** 2)) * np.exp(-tt * 12) * 0.5
    rain = hp_fast(noise(d), 2000) * np.exp(-((tt - 0.7) ** 2) / 0.12) * 0.35
    return burst + plop + rain


def whistle():
    d = 1.2
    tt = t(d)
    f = 1400 - 700 * tt / d
    ph = 2 * np.pi * np.cumsum(f) / SR
    air = lp_fast(noise(d), 3000) * 0.3
    return (np.sin(ph) * 0.4 + air) * np.minimum(1, tt / 0.2) * np.minimum(1, (d - tt) / 0.1)


def click():
    d = 0.08
    tt = t(d)
    return np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 70) + np.sin(2 * np.pi * 900 * tt) * np.exp(-tt * 50)


def hover():
    d = 0.05
    tt = t(d)
    return np.sin(2 * np.pi * 2600 * tt) * np.exp(-tt * 90) * 0.4


def place():
    d = 0.35
    tt = t(d)
    clank = np.sin(2 * np.pi * 320 * tt) * np.exp(-tt * 18) + np.sin(2 * np.pi * 517 * tt) * np.exp(-tt * 22) * 0.6
    water = lp_fast(noise(d), 1200) * np.exp(-tt * 14) * 0.5
    return clank + water


def sonar():
    d = 2.4
    tt = t(d)
    ping = np.sin(2 * np.pi * 1250 * tt) * np.exp(-tt * 2.2) * np.minimum(1, tt / 0.005)
    echo = np.zeros_like(ping)
    sh = int(0.45 * SR)
    echo[sh:] = ping[:-sh] * 0.35
    return ping + echo


def plane():
    d = 4.0
    tt = t(d)
    f0 = 95 * (1 + 0.15 * np.tanh((2.0 - tt) * 2))  # doppler-ish drop
    ph = 2 * np.pi * np.cumsum(f0) / SR
    buzz = np.sign(np.sin(ph)) * 0.3 + np.sin(ph * 2) * 0.3
    buzz = lp_fast(buzz, 1200)
    wind = lp_fast(noise(d), 600) * 0.4
    loud = np.exp(-((tt - 2.0) ** 2) / 0.9)
    return (buzz + wind) * loud


def torpedo():
    d = 2.5
    tt = t(d)
    launch = lp_fast(noise(d), 500) * np.exp(-tt * 8) * 1.5
    run = np.sin(2 * np.pi * 70 * tt) * 0.2 + lp_fast(noise(d), 2500) * 0.25
    return launch + run * np.minimum(1, tt / 0.3) * np.minimum(1, (d - tt) / 0.4)


def alarm():
    d = 1.4
    tt = t(d)
    f = np.where((tt * 2.5) % 1 < 0.5, 620, 470)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sign(np.sin(ph)) * 0.25 * lp_fast(np.ones_like(tt), 50) * np.minimum(1, (d - tt) / 0.1)


def chord(freqs, d, wave_=0.6):
    tt = t(d)
    x = np.zeros_like(tt)
    for f in freqs:
        ph = 2 * np.pi * f * tt
        x += np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.18 * np.sin(3 * ph) * wave_
    return x


def victory():
    notes = [(392, 0.18), (523, 0.18), (659, 0.18), (784, 0.5), (659, 0.18), (784, 1.2)]
    out = []
    for f, d in notes:
        x = chord([f, f * 1.26, f * 1.5], d) * env(d, 0.02, 0.6)
        out.append(x)
    return np.concatenate(out)


def defeat():
    notes = [(392, 0.5), (370, 0.5), (349, 0.5), (262, 1.6)]
    out = []
    for f, d in notes:
        out.append(chord([f, f * 1.19, f * 1.5], d) * env(d, 0.03, 0.8))
    return lp_fast(np.concatenate(out), 1800)


def sea_loop():
    """30 s seamless ambience: surf swells + gulls-free wind. Crossfaded ends."""
    d = 30.0
    tt = t(d)
    n = lp_fast(noise(d), 700)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 7.5) * np.sin(2 * np.pi * tt / 5.0 + 1)
    wash = hp_fast(lp_fast(noise(d), 3500), 500) * np.clip(np.sin(2 * np.pi * tt / 7.5 + 0.6), 0, 1) ** 3 * 0.5
    x = n * swell + wash
    fade = int(SR * 2)
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    return x[:-fade]


def music_loop():
    """32-bar adventurous loop in D minor: pad chords, plucked arpeggio, low drums. ~64 s at 120 bpm."""
    bpm = 120
    beat = 60 / bpm
    bar = beat * 4
    prog = [[146.8, 174.6, 220.0], [116.5, 146.8, 174.6], [130.8, 164.8, 196.0], [110.0, 138.6, 164.8]]  # Dm Bb C A
    bars = 16
    total = int(SR * bar * bars)
    x = np.zeros(total)
    for b in range(bars):
        ch = prog[b % 4]
        s0 = int(SR * bar * b)
        d = bar
        tt = t(d)
        pad = sum(np.sin(2 * np.pi * f * tt + np.sin(2 * np.pi * 0.3 * tt) * 0.5) for f in ch)
        pad += sum(0.3 * np.sin(2 * np.pi * f * 2.003 * tt) for f in ch)
        pad *= np.minimum(1, tt / 0.3) * np.minimum(1, (d - tt) / 0.3) * 0.18
        x[s0:s0 + len(pad)] += pad[:total - s0]
        # arpeggio eighths
        arp = [ch[0] * 2, ch[1] * 2, ch[2] * 2, ch[1] * 2, ch[0] * 4, ch[2] * 2, ch[1] * 2, ch[2] * 2]
        if b >= 4:
            for k, f in enumerate(arp):
                s = s0 + int(SR * beat / 2 * k)
                dd = beat / 2 * 1.6
                tt2 = t(dd)
                note = (np.sin(2 * np.pi * f * tt2) + 0.4 * np.sin(4 * np.pi * f * tt2)) * np.exp(-tt2 * 7) * 0.22
                e = min(total, s + len(note))
                x[s:e] += note[:e - s]
        # bass
        bass_f = ch[0] / 2
        for k in range(4):
            s = s0 + int(SR * beat * k)
            dd = beat * 0.9
            tt2 = t(dd)
            note = np.sin(2 * np.pi * bass_f * tt2) * np.exp(-tt2 * 3) * 0.5
            e = min(total, s + len(note))
            x[s:e] += note[:e - s]
        # drums from bar 8: kick on 1 and 3, low tom fill at the end of every 4th bar
        if b >= 8:
            for k in (0, 2, 2.5):
                s = s0 + int(SR * beat * k)
                dd = 0.4
                tt2 = t(dd)
                kick = np.sin(2 * np.pi * (90 * tt2 - 90 * tt2 ** 2)) * np.exp(-tt2 * 10) * 0.9
                e = min(total, s + len(kick))
                x[s:e] += kick[:e - s]
            for k in (1, 3):
                s = s0 + int(SR * beat * k)
                dd = 0.25
                sn = hp_fast(noise(dd), 1500) * np.exp(-t(dd) * 18) * 0.25
                e = min(total, s + len(sn))
                x[s:e] += sn[:e - s]
    return x


if __name__ == "__main__":
    for name, fn in [("cannon", cannon), ("explosion", explosion), ("splash", splash), ("whistle", whistle),
                     ("click", click), ("hover", hover), ("place", place), ("sonar", sonar), ("plane", plane),
                     ("torpedo", torpedo), ("alarm", alarm), ("victory", victory), ("defeat", defeat),
                     ("sea_loop", sea_loop)]:  # music: CC0 tracks in assets/music (see CREDITS)
        save(name, fn())
    print("DONE")
