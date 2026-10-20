#!/usr/bin/env python3
"""Procedurally generate the project's sound effects.

Everything is synthesised so the repo carries no licensed audio. Re-run this
from the project root to regenerate res://audio/*.wav:

    python3 tools/make_audio.py

The gun loop is built so that its length is an exact whole number of firing
pulses, which is what lets Godot loop it without an audible seam.
"""

import os
import struct
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")

rng = np.random.default_rng(1974)  # the year the Phalanx entered testing


def periodic_noise(n):
    """White noise that is exactly periodic over n samples (loops cleanly)."""
    spec = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    spec[0] = 0.0
    out = np.fft.irfft(spec, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def band(sig, lo, hi, soft=1.0):
    """Zero-phase band shaping via FFT. Keeps loops seamless."""
    n = len(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.ones_like(f)
    if lo > 0:
        g *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-6)) ** (2 * soft))
    if hi > 0:
        g *= 1.0 / (1.0 + (np.maximum(f, 1e-6) / hi) ** (2 * soft))
    return np.fft.irfft(np.fft.rfft(sig) * g, n)


def shelf(sig, f_lo, f_hi, gain_db):
    """High shelf via FFT. Used to set the overall tilt of a finished sound
    without touching its density - the difference between 'muffled' and
    'present' is mostly this, not the transient shape."""
    n = len(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = 1.0 + (10.0 ** (gain_db / 20.0) - 1.0) * np.clip((f - f_lo) / (f_hi - f_lo), 0.0, 1.0)
    return np.fft.irfft(np.fft.rfft(sig) * g, n)


def norm(sig, peak=0.92):
    m = np.max(np.abs(sig))
    return sig * (peak / m) if m > 1e-9 else sig


def write_wav(name, sig):
    os.makedirs(OUT, exist_ok=True)
    data = np.clip(sig, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name}: {len(data) / SR:.3f}s  {os.path.getsize(path) / 1024:.0f} KiB")


# ---------------------------------------------------------------------------
# 1. Gun loop - 4500 rpm = 75 pulses/second
# ---------------------------------------------------------------------------

def gun_loop(presence=3.0, drive=7.5, tilt_db=22.0):
    """4500 rpm rip.

    The real thing is not a series of crisp cracks - at 75 rounds a second the
    shots fuse into one continuous low roar, and what makes it frightening is
    weight plus harmonic richness, not transient sharpness. So:

      * long overlapping tails, so pulses blur into a drone rather than a
        machine-gun rattle,
      * real low-end per round for the chest weight,
      * a strong 1.2-5 kHz presence layer - the absence of THIS is what makes a
        loud low sound read as dull and muffled,
      * asymmetric saturation, which adds even harmonics (throat) where tanh
        alone only adds odd ones (fizz),
      * alternate rounds slightly hotter, putting a 37.5 Hz growl under the
        75 Hz pulse rate.

    No clean sine whine: that was what made the earlier version sound
    synthetic. All the harmonic motion here comes from noise and saturation.
    """
    rpm = 4500.0
    pulses_per_sec = rpm / 60.0                 # 75
    period = int(round(SR / pulses_per_sec))    # 588 samples exactly
    n_pulses = 60                               # 0.8 s loop
    n = period * n_pulses

    out = np.zeros(n)
    tail = period * 10                          # long overlap -> continuous roar
    t = np.arange(tail) / SR

    for i in range(n_pulses):
        amp = (1.12 if i % 2 == 0 else 0.88) * (1.0 + rng.normal(0.0, 0.045))

        # Weight: the part that makes it daunting.
        thump = np.sin(2 * np.pi * 61.0 * t + rng.uniform(0, 6.28)) * np.exp(-t * 52.0)
        thump += np.sin(2 * np.pi * 94.0 * t) * np.exp(-t * 78.0) * 0.75
        thump += np.sin(2 * np.pi * 148.0 * t) * np.exp(-t * 105.0) * 0.4

        # Rip: the low-mid tearing body.
        body = periodic_noise(tail) * np.exp(-t * 105.0)
        body = band(body, 110, 950)

        # Presence: the fix for "dull". Broad, loud, slightly slower decay so
        # it sustains between rounds instead of only ticking on the attack.
        pres = periodic_noise(tail) * np.exp(-t * 210.0)
        pres = band(pres, 1200, 5200, soft=1.1)

        # Air: a little top so it is not a blanket, but kept well back.
        air = periodic_noise(tail) * np.exp(-t * 460.0)
        air = band(air, 5200, 9500)

        # Breech ring.
        ring = np.sin(2 * np.pi * 1880.0 * t) * np.exp(-t * 190.0) * 0.16
        ring += np.sin(2 * np.pi * 3120.0 * t) * np.exp(-t * 260.0) * 0.10

        pulse = (thump * 1.0
                 + body * 1.0
                 + pres * 0.95 * presence
                 + air * 0.22
                 + ring) * amp

        start = i * period
        idx = (np.arange(tail) + start) % n     # wrap so the loop is seamless
        out[idx] += pulse

    # Presence shelf BEFORE the saturator. This is the control that decides
    # whether the loop reads as menacing-and-loud or as muffled. It has to go
    # in front of the clip: applied afterwards it just adds peaks, the
    # normalise pulls the whole loop down, and the density is lost.
    out = norm(out, 1.0)
    out = shelf(out, 900.0, 4200.0, tilt_db)
    out = norm(out, 1.0)
    # Asymmetric soft clip: even + odd harmonics, and it squashes the crest so
    # the loop reads as one continuous roar rather than a rattle.
    out = np.tanh(drive * out + 0.30 * drive * out * out)
    out = out - out.mean()
    # Keep the weight, roll off the brittle top.
    out = band(out, 40, 10500, soft=1.0)
    return norm(out, 0.97)


# ---------------------------------------------------------------------------
# 2. Barrel spin-up whine (looping bed, pitch-shifted at runtime)
# ---------------------------------------------------------------------------

def spin_loop():
    n = SR  # 1.000 s -> every integer frequency loops cleanly
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for h, a in ((72.0, 0.5), (144.0, 0.32), (216.0, 0.18), (288.0, 0.12),
                 (576.0, 0.07), (1152.0, 0.035)):
        sig += np.sin(2 * np.pi * h * t) * a
    sig += band(periodic_noise(n), 400, 5000) * 0.25
    return norm(sig, 0.6)


# ---------------------------------------------------------------------------
# 3. Kill explosion
# ---------------------------------------------------------------------------

def explosion():
    dur = 1.6
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = rng.normal(size=n)
    body = band(noise, 40, 1400, soft=1.0) * np.exp(-t * 3.4)
    crack = band(noise, 1200, 9000) * np.exp(-t * 26.0) * 0.8
    # Descending sub thump.
    sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(120.0, 34.0, n)) / SR)
    sub = sweep * np.exp(-t * 4.2) * 0.9
    # Debris rattle.
    rattle = band(rng.normal(size=n), 900, 6000) * np.exp(-t * 6.0) \
        * (rng.random(n) < 0.02) * 2.0
    sig = body * 1.0 + crack + sub + rattle * 0.5
    # Short fade-in so there is no click.
    sig[:64] *= np.linspace(0, 1, 64)
    return norm(sig, 0.95)


# ---------------------------------------------------------------------------
# 4. Round impact
# ---------------------------------------------------------------------------

def impact():
    dur = 0.13
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = rng.normal(size=n)
    sig = band(noise, 1500, 11000) * np.exp(-t * 90.0)
    for f in (2100.0, 3350.0, 4870.0):
        sig += np.sin(2 * np.pi * f * t) * np.exp(-t * 70.0) * 0.25
    sig += band(noise, 150, 700) * np.exp(-t * 45.0) * 0.4
    sig[:24] *= np.linspace(0, 1, 24)
    return norm(sig, 0.85)


# ---------------------------------------------------------------------------
# 5. Missile launch
# ---------------------------------------------------------------------------

def missile_launch():
    dur = 2.2
    n = int(SR * dur)
    t = np.arange(n) / SR
    noise = rng.normal(size=n)
    # Ignition crack, then a sustained motor roar that fades as it departs.
    crack = band(noise, 700, 9000) * np.exp(-t * 18.0)
    roar = band(noise, 90, 2600) * (1.0 - np.exp(-t * 40.0)) * np.exp(-t * 1.5)
    rumble = band(noise, 35, 260) * (1.0 - np.exp(-t * 25.0)) * np.exp(-t * 1.1)
    hiss = band(noise, 2500, 9000) * (1.0 - np.exp(-t * 30.0)) * np.exp(-t * 2.2) * 0.5
    sig = crack * 0.9 + roar * 1.0 + rumble * 0.9 + hiss
    sig[:48] *= np.linspace(0, 1, 48)
    return norm(sig, 0.9)


# ---------------------------------------------------------------------------
# 6. Seeker tones
# ---------------------------------------------------------------------------

# The seeker's voice. The search beep and the acquired tone are deliberately
# the SAME instrument - same harmonic ratios, same tremolo rate - so the pips
# and the solid tone feel like one system talking to you. Only pitch, length
# and envelope differ.
SEEKER_HARMONICS = ((1, 1.0), (2, 0.28), (3, 0.34), (5, 0.16))
SEEKER_F0 = 1560.0
SEEKER_TREMOLO = 42.0


def _seeker_voice(n, f0):
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for k, a in SEEKER_HARMONICS:
        sig += np.sin(2 * np.pi * f0 * k * t) * a
    sig *= 1.0 + 0.12 * np.sin(2 * np.pi * SEEKER_TREMOLO * t)
    return t, sig


def lock_tone():
    """Search pip: the acquired tone, cut short and pitched down a little."""
    dur = 0.10
    n = int(SR * dur)
    t, sig = _seeker_voice(n, SEEKER_F0 * 0.82)
    # Fast attack, short plateau, quick release - a beep, not a tick.
    env = np.minimum(t * 700.0, 1.0) * np.clip((dur - t) * 26.0, 0.0, 1.0)
    return norm(sig * env, 0.60)


def lock_acquired():
    """Solid tone: the seeker has it. Steady, not decaying - it means committed."""
    dur = 0.6
    n = int(SR * dur)
    t, sig = _seeker_voice(n, SEEKER_F0)
    env = np.minimum(t * 900.0, 1.0) * np.minimum((dur - t) * 30.0, 1.0)
    return norm(sig * env, 0.66)


# ---------------------------------------------------------------------------
# 7. Warp arrival
# ---------------------------------------------------------------------------

WARP_CHARGE = 2.6  # must match Enemy.WARP_CHARGE: the boom lands on the drop


def warp_arrival():
    """A building drone that rises in pitch and pressure for WARP_CHARGE
    seconds, then a tearing crack and a sub boom that rolls on for seconds.
    Uses its own random generator so adding it changes no other sound."""
    r = np.random.default_rng(3141)
    dur = 8.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    c = int(SR * WARP_CHARGE)
    pre = t < WARP_CHARGE
    k = np.clip(t / WARP_CHARGE, 0.0, 1.0)

    # Charge: detuned buzzing partials sliding up, swelling hard at the end.
    f = 38.0 + 150.0 * k ** 2.2
    phase = 2 * np.pi * np.cumsum(f) / SR
    drone = np.zeros(n)
    for mult, amp, det in ((1, 1.0, 0.0), (1, 0.8, 0.9), (2, 0.5, 1.7), (3, 0.3, -2.3), (5, 0.18, 3.1)):
        drone += np.sign(np.sin(phase * mult + det * t * 2 * np.pi)) * amp
    drone = band(drone, 30, 2400)
    hiss = band(r.normal(size=n), 900, 7000) * k ** 3
    swell = k ** 2.6 * pre
    charge = (drone * 0.8 + hiss * 0.5) * swell

    # Drop: crack, a tear sweeping down, a long sub boom and rumble.
    td = np.maximum(t - WARP_CHARGE, 0.0)
    post = ~pre
    noise = r.normal(size=n)
    crack = band(noise, 600, 12000) * np.exp(-td * 14.0) * post
    sweep_f = 60.0 * np.exp(-td * 0.55) + 18.0
    sub = np.sin(2 * np.pi * np.cumsum(sweep_f) / SR) * np.exp(-td * 0.9) * post
    tear = np.zeros(n)
    seg = 2048
    for i in range(c, n - seg, seg // 2):
        tt = (i - c) / SR
        fc = 5000.0 * np.exp(-tt * 2.2) + 120.0
        chunk = band(noise[i:i + seg], fc * 0.5, fc * 1.6) * np.hanning(seg)
        tear[i:i + seg] += chunk * np.exp(-tt * 1.3)
    rumble = band(r.normal(size=n), 25, 220) * np.exp(-td * 0.6) * post

    sig = charge * 0.4 + crack * 1.4 + sub * 1.6 + tear * 1.1 + rumble * 1.3
    sig = np.tanh(sig * 1.4)
    sig[:256] *= np.linspace(0, 1, 256)
    sig[-4096:] *= np.linspace(1, 0, 4096)
    return norm(sig, 0.95)


if __name__ == "__main__":
    print("Generating audio into", OUT)
    write_wav("ciws_fire.wav", gun_loop())
    write_wav("ciws_spin.wav", spin_loop())
    write_wav("explosion.wav", explosion())
    write_wav("impact.wav", impact())
    write_wav("missile_launch.wav", missile_launch())
    write_wav("lock_tone.wav", lock_tone())
    write_wav("lock_acquired.wav", lock_acquired())
    write_wav("warp_arrival.wav", warp_arrival())
    print("done.")
