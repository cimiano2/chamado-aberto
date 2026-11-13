"""Efeitos sonoros e música de fundo em estilo chiptune, gerados por síntese (sem samples externos).
Rode: python3 build.py   → ../../assets/sfx/*.wav (mono, 22050 Hz, 16 bits)
"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sfx")
NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name):  # "C5", "G#4"
    return NOTE[name[:-1]] * 2 ** (int(name[-1]) - 4)


def osc(kind, f, t):
    ph = (f * t) % 1.0
    if kind == "square":
        return 1.0 if ph < 0.5 else -1.0
    if kind == "pulse":
        return 1.0 if ph < 0.25 else -1.0
    if kind == "tri":
        return 4 * abs(ph - 0.5) - 1
    return math.sin(2 * math.pi * ph)


def tone(f, dur, kind="square", vol=0.3, attack=0.005, release=0.05, slide=0.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / attack) * min(1.0, (dur - t) / release)
        out.append(vol * env * osc(kind, f + slide * t, t))
    return out


def silence(dur):
    return [0.0] * int(SR * dur)


def noise(dur, vol=0.2, decay=40.0):
    random.seed(7)
    return [vol * math.exp(-decay * i / SR) * random.uniform(-1, 1) for i in range(int(SR * dur))]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def save(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print("wav ->", os.path.normpath(path), "%.2fs" % (len(samples) / SR))


def seq(notes, step, kind="square", vol=0.25):
    out = []
    for n in notes:
        out += silence(step) if n == "-" else tone(freq(n), step, kind, vol)
    return out


save("click", tone(1400, 0.04, "pulse", 0.2, release=0.03))
save("step", noise(0.03, 0.12, 120))
save("ticket", seq(["E6", "C6", "-", "E6", "C6"], 0.07, "pulse", 0.22))          # telefone tocando
save("success", seq(["C5", "E5", "G5", "C6"], 0.07, "square", 0.22) + tone(freq("C6"), 0.18, "square", 0.18))
save("error", tone(160, 0.25, "square", 0.22, slide=-120))
save("expired", seq(["G4", "E4", "C4"], 0.12, "tri", 0.4) + tone(freq("A3"), 0.3, "tri", 0.35))
save("combo", tone(600, 0.15, "pulse", 0.18, slide=2400))
save("dayend", seq(["C5", "E5", "G5", "E5", "G5", "C6", "-", "C6"], 0.11, "square", 0.22))
save("open", seq(["A5", "D6"], 0.05, "pulse", 0.18))

# música de fundo: 8 compassos a 104 bpm, baixo em triângulo + melodia em pulso + chimbal de ruído
bpm = 104
beat = 60 / bpm
eighth = beat / 2
chords = [["C3", "G3"], ["A2", "E3"], ["F2", "C3"], ["G2", "D3"]] * 2
melody = ["E5", "-", "G5", "E5", "D5", "-", "C5", "-", "C5", "-", "E5", "C5", "B4", "-", "A4", "-",
          "A4", "-", "C5", "A4", "G4", "-", "F4", "-", "G4", "-", "B4", "D5", "G5", "-", "-", "-",
          "E5", "-", "G5", "E5", "D5", "-", "C5", "-", "C5", "-", "E5", "G5", "A5", "-", "G5", "-",
          "F5", "-", "E5", "D5", "C5", "-", "D5", "-", "B4", "-", "G4", "B4", "C5", "-", "-", "-"]
bass = []
for ch in chords:
    for k in range(8):
        bass += tone(freq(ch[k % 2]), eighth, "tri", 0.32, release=0.02)
lead = seq(melody, eighth, "pulse", 0.10)
hat = []
for k in range(len(chords) * 8):
    hat += noise(0.02, 0.05 if k % 2 else 0.08, 200) + silence(eighth - 0.02)
save("music", mix(bass, lead, hat))
