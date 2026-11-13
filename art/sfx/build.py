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

# ---------------------------------------------------------------- som ambiente de escritório (loop de 30 s)
def lowpass(x, a):
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, a):
    lp = lowpass(x, a)
    return [v - l for v, l in zip(x, lp)]


def ambient(seconds=30.0, fade=2.0):
    rnd = random.Random(42)
    n = int(SR * (seconds + fade))
    out = [0.0] * n
    # 1) ar-condicionado: ruído marrom grave e constante
    white = [rnd.uniform(-1, 1) for _ in range(n)]
    hum = lowpass(white, 0.004)
    peak = max(abs(v) for v in hum) or 1
    for i in range(n):
        out[i] += 0.11 * hum[i] / peak
    # 2) burburinho: ruído na faixa da voz, modulado em "sílabas"
    voice = highpass(lowpass([rnd.uniform(-1, 1) for _ in range(n)], 0.12), 0.02)
    vpeak = max(abs(v) for v in voice) or 1
    env, target = 0.0, 0.0
    for i in range(n):
        if i % int(SR / 5) == 0:                      # nova "sílaba" ~5x por segundo
            target = rnd.choice([0.0, 0.2, 0.5, 0.8, 1.0]) if rnd.random() < 0.7 else 0.0
        env += 0.0008 * (target - env)
        out[i] += 0.035 * env * voice[i] / vpeak
    # 3) teclados: rajadas de cliques curtos em 4 mesas a distâncias diferentes
    def click(at, vol, tone):
        length = int(SR * 0.012)
        for k in range(length):
            if at + k < n:
                out[at + k] += vol * math.exp(-k / (SR * 0.0025)) * rnd.uniform(-1, 1) * (1 if k % tone else -0.6)
    for typist, vol in enumerate((0.16, 0.10, 0.07, 0.05)):
        t = rnd.uniform(0, 3)
        while t < seconds + fade:
            burst = rnd.randint(4, 18)
            for _ in range(burst):
                click(int(t * SR), vol * rnd.uniform(0.6, 1.0), 2 + typist)
                t += rnd.uniform(0.07, 0.16)
            t += rnd.uniform(1.0, 4.5)                 # pausa para pensar
    # 4) cliques de mouse esparsos
    for _ in range(18):
        at = int(rnd.uniform(0, seconds) * SR)
        click(at, 0.09, 2)
        click(at + int(SR * 0.09), 0.07, 2)
    # 5) telefone tocando longe (abafado), duas vezes
    for start in (8.0, 22.5):
        for ring in range(2):
            t0 = start + ring * 1.4
            for i in range(int(SR * 0.8)):
                tt = i / SR
                f = 950 if int(tt * 20) % 2 == 0 else 1180
                idx = int((t0 + tt) * SR)
                if idx < n:
                    out[idx] += 0.018 * math.sin(2 * math.pi * f * tt) * min(1, tt * 30) * min(1, (0.8 - tt) * 30)
    # 6) impressora: motor + arraste de papel por 3 s
    p0 = int(15.0 * SR)
    paper = lowpass([rnd.uniform(-1, 1) for _ in range(int(SR * 3))], 0.25)
    for i in range(int(SR * 3)):
        tt = i / SR
        env = min(1, tt * 4) * min(1, (3 - tt) * 4)
        motor = 0.5 * math.sin(2 * math.pi * 110 * tt) + 0.3 * math.sin(2 * math.pi * 220 * tt)
        sweep = 1.0 if (tt * 2.5) % 1.0 < 0.6 else 0.3
        out[p0 + i] += env * (0.03 * motor + 0.05 * sweep * paper[i])
    # loop sem emenda: o fim faz crossfade com o começo
    m = int(SR * seconds)
    f = int(SR * fade)
    for i in range(f):
        a = i / f
        out[i] = out[i] * a + out[m + i] * (1 - a)
    loop = out[:m]
    peak = max(abs(v) for v in loop)
    return [0.7 * v / peak for v in loop]


# O jogo usa a gravação assets/audio/office_ambience.ogg; a versão sintetizada fica
# disponível como alternativa: descomente para gerar assets/sfx/ambient.wav.
# save("ambient", ambient())


# ---------------------------------------------------------------- música do menu (original, 8 bits, loop de 30 s)
def menu_theme():
    """Tema original do menu: 128 BPM, 16 compassos (A + B), Dó maior.
    Melodia e harmonia compostas para este jogo; instrumentos no estilo de console de 8 bits."""
    bpm = 128
    e = 60 / bpm / 2                     # duração de uma colcheia
    bar = e * 8
    chords_a = [("C", ["C4", "E4", "G4"]), ("A", ["A3", "C4", "E4"]), ("F", ["F3", "A3", "C4"]), ("G", ["G3", "B3", "D4"])] * 2
    chords_b = [("D", ["D4", "F4", "A4"]), ("G", ["G3", "B3", "D4"]), ("E", ["E4", "G4", "B4"]), ("A", ["A3", "C4", "E4"]),
                ("F", ["F3", "A3", "C4"]), ("G", ["G3", "B3", "D4"]), ("C", ["C4", "E4", "G4"]), ("G", ["G3", "B3", "D4"])]
    chords = chords_a + chords_b
    roots = {"C": "C2", "A": "A1", "F": "F2", "G": "G2", "D": "D2", "E": "E2"}
    fifths = {"C": "G2", "A": "E2", "F": "C3", "G": "D3", "D": "A2", "E": "B2"}
    melody = [
        # A
        "E5 - G5 E5 C5 - D5 E5", "C5 - A4 C5 E5 - D5 C5", "A4 - C5 F5 E5 - D5 C5", "D5 - B4 G4 D5 - - -",
        "E5 - G5 C6 B5 - G5 E5", "A5 - E5 C5 E5 - A5 G5", "F5 - A5 F5 D5 - C5 A4", "B4 - D5 G5 F5 E5 D5 -",
        # B
        "F5 F5 - A5 - F5 D5 -", "G5 G5 - B5 - G5 D5 -", "E5 - G5 B5 A5 G5 E5 -", "C5 - E5 A5 G5 - E5 -",
        "A5 - G5 F5 E5 - F5 A5", "G5 - F5 E5 D5 - B4 D5", "C5 - E5 G5 C6 - G5 E5", "D5 - G4 B4 D5 - - -",
    ]
    total = int(SR * bar * 16)
    out = [0.0] * total

    def put(samples, at):
        for i, v in enumerate(samples):
            if at + i < total:
                out[at + i] += v

    def note(f, dur, kind, vol, staccato=0.85):
        n = int(SR * dur)
        on = int(n * staccato)
        res = []
        for i in range(n):
            t = i / SR
            env = min(1.0, t / 0.005) * (min(1.0, (on - i) / (SR * 0.02)) if i < on else 0.0)
            res.append(vol * env * osc(kind, f, t))
        return res

    for b in range(16):
        t0 = int(SR * bar * b)
        name, triad = chords[b]
        # melodia (pulso 25%), nota segura enquanto houver "-"
        steps = melody[b].split()
        k = 0
        while k < 8:
            if steps[k] == "-":
                k += 1
                continue
            length = 1
            while k + length < 8 and steps[k + length] == "-":
                length += 1
            put(note(freq(steps[k]), e * length, "pulse", 0.13), t0 + int(SR * e * k))
            k += length
        # arpejo discreto em semicolcheias (quadrada), uma oitava acima do acorde
        for s16 in range(16):
            tone_name = triad[s16 % 3]
            f = freq(tone_name) * 2
            put(note(f, e / 2, "square", 0.025, 0.6), t0 + int(SR * e / 2 * s16))
        # baixo saltitante (triângulo): fundamental, fundamental, quinta, fundamental...
        pattern = [roots[name], roots[name], fifths[name], roots[name], roots[name], fifths[name], roots[name], fifths[name]]
        for k, nm in enumerate(pattern):
            put(note(freq(nm), e, "tri", 0.30, 0.7), t0 + int(SR * e * k))
        # bateria: bumbo nos tempos 1 e 3, caixa no 2 e 4, chimbal nas colcheias
        rnd = random.Random(b)
        for beat in range(4):
            at = t0 + int(SR * e * 2 * beat)
            if beat % 2 == 0:
                kick = [0.45 * math.sin(2 * math.pi * (150 - 1200 * i / SR) * i / SR) * math.exp(-i / (SR * 0.05))
                        for i in range(int(SR * 0.09))]
                put(kick, at)
            else:
                put([0.16 * math.exp(-i / (SR * 0.04)) * rnd.uniform(-1, 1) for i in range(int(SR * 0.12))], at)
        for k in range(8):
            put([0.05 * math.exp(-i / (SR * 0.008)) * rnd.uniform(-1, 1) for i in range(int(SR * 0.03))],
                t0 + int(SR * e * k))
    peak = max(abs(v) for v in out)
    return [0.8 * v / peak for v in out]


save("menu_theme", menu_theme())
# converte para OGG (menor) em assets/audio/ e apaga o WAV intermediário
import shutil, subprocess
wav = os.path.join(OUT, "menu_theme.wav")
ogg = os.path.join(OUT, "..", "audio", "menu_theme.ogg")
if shutil.which("ffmpeg"):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    print("ogg ->", os.path.normpath(ogg))
