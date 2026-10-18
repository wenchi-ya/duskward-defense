"""Original offline score and effects. Python standard library only; reproducible seed."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parent
TAU = math.tau


def write(name, left, right=None):
    right = left if right is None else right
    peak = max(max(abs(x) for x in left), max(abs(x) for x in right), 0.001)
    gain = min(1.0, 0.86 / peak)
    pcm = bytearray()
    for l, r in zip(left, right):
        pcm.extend(struct.pack('<hh', int(l * gain * 32767), int(r * gain * 32767)))
    path = ROOT / (name + '.wav')
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm)
    print(name, 'seconds=', round(len(left) / RATE, 2), 'peak=', round(peak * gain, 3))


def note(left, right, start, duration, midi, voice, gain, pan=0.0):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    start = int(start * RATE)
    count = int(duration * RATE)
    for i in range(count):
        t = i / RATE
        u = i / count
        phase = TAU * frequency * t
        if voice == 'lute':
            envelope = min(1, t / 0.008) * math.exp(-4.8 * u) * min(1, (1-u) / 0.12)
            sample = (math.sin(phase) + 0.32 * math.sin(2*phase) + 0.12 * math.sin(3*phase)) * envelope
        elif voice == 'flute':
            envelope = min(1, t / 0.09) * min(1, (1-u) / 0.24)
            sample = (math.sin(phase + 0.025 * math.sin(TAU*4.6*t)) + 0.12 * math.sin(2*phase)) * envelope
        else:
            envelope = min(1, t / 0.035) * math.exp(-2.4*u) * min(1, (1-u) / 0.2)
            sample = (math.sin(phase) + 0.18 * math.sin(2*phase)) * envelope
        sample *= gain
        # Wrap natural tails and quiet room reflections across the loop boundary.
        for delay, level in [(0, 1.0), (0.137, 0.12), (0.283, 0.06)]:
            k = (start + i + int(delay * RATE)) % len(left)
            left[k] += sample * level * (0.7 - pan * 0.25)
            right[k] += sample * level * (0.7 + pan * 0.25)


def music(name, bpm, shift, intensity):
    beat = 60 / bpm
    left = [0.0] * round(64 * beat * RATE)
    right = left.copy()
    # Dorian/minor fantasy theme, two phrases with answering and closing cadences.
    chords = [(50,57,62,65), (46,53,58,62), (53,60,65,69), (48,55,60,64),
              (50,57,62,65), (55,62,67,70), (46,53,58,62), (45,52,57,61)]
    phrases = [[(74,1),(77,.5),(76,.5),(74,1),(69,1)],
               [(70,1.5),(74,.5),(77,1),(74,1)],
               [(77,1),(79,.5),(81,.5),(79,1),(77,1)],
               [(76,1.5),(72,.5),(69,2)],
               [(74,.5),(76,.5),(77,1),(81,1),(79,1)],
               [(79,1),(77,.5),(76,.5),(74,1),(70,1)],
               [(77,1),(74,1),(70,1),(72,1)],
               [(73,1),(69,1),(74,2)]]
    rng = random.Random(413 + shift)
    for bar in range(16):
        chord = chords[bar % 8]
        for eighth in range(8):
            pitch = chord[[0,2,1,3,1,2,3,2][eighth]] + shift
            note(left, right, (bar*4 + eighth*.5)*beat, beat*1.4, pitch, 'lute', .10, -.5)
        for b in [0, 2]:
            note(left, right, (bar*4+b)*beat, beat*1.8, chord[0]-12+shift, 'bass', .13, .1)
        position = bar*4
        for pitch, length in phrases[bar % 8]:
            # Second phrase uses a gentle harmony instead of merely repeating louder.
            note(left, right, position*beat, length*beat*.92, pitch+shift, 'flute', .082, .35)
            if bar >= 8 and bar % 4 == 2:
                note(left, right, position*beat, length*beat*.85, pitch-12+shift, 'lute', .045, -.2)
            position += length
        for b in range(4):
            start = int((bar*4+b)*beat*RATE)
            for i in range(int(.13*RATE)):
                t = i/RATE
                # Soft frame drum on 1/3, brushed shaker on 2/4.
                drum = math.sin(TAU*(74*t-95*t*t))*math.exp(-32*t) if b % 2 == 0 else rng.uniform(-1,1)*math.exp(-65*t)*.33
                k = (start+i) % len(left)
                left[k] += drum*.065*intensity
                right[k] += drum*.065*intensity
    write('music/'+name, left, right)


def effect(name, duration, flavor):
    rng = random.Random(912 + sum(map(ord, name)))
    result = []
    smooth = 0.0
    for i in range(int(duration*RATE)):
        t = i/RATE
        u = t/duration
        noise = rng.uniform(-1, 1)
        smooth = smooth*.83 + noise*.17
        tail = (1-u)**2
        attack = min(1, t/.004)
        if flavor == 'arrow':
            value = (noise*.25 + math.sin(TAU*(1300*t-700*t*t))*.1) * math.exp(-22*t)
        elif flavor in ('cannon', 'meteor'):
            value = (smooth*1.5 + math.sin(TAU*(64*t-26*t*t))*.45)*tail
        elif flavor == 'magic':
            value = (math.sin(TAU*(430*t+530*t*t)) + .3*math.sin(TAU*1190*t))*tail*.32
        elif flavor == 'melee':
            value = (noise*.25+math.sin(TAU*1830*t)*math.exp(-50*t)*.2)*math.exp(-30*t)
        elif flavor in ('build', 'upgrade'):
            value = (smooth*.8*math.exp(-18*t) + math.sin(TAU*(420*t+220*t*t))*.28*tail)
        elif flavor in ('victory', 'defeat', 'wave', 'reinforce'):
            pitches = {'victory':[62,66,69,74], 'defeat':[62,60,57,50], 'wave':[50,57,62], 'reinforce':[62,67,69]}[flavor]
            index = min(len(pitches)-1, int(u*len(pitches)))
            local = (u*len(pitches)) % 1
            f = 440*2**((pitches[index]-69)/12)
            envelope = min(1, local*20)*min(1,(1-local)*12)
            value = (math.sin(TAU*f*t)+.18*math.sin(TAU*f*2*t))*envelope*tail*.36
        elif flavor == 'leak':
            value = math.sin(TAU*(430*t-160*t*t))*tail*.3
        elif flavor == 'death':
            value = smooth*tail*.6
        else:
            value = (math.sin(TAU*740*t)+.3*math.sin(TAU*1110*t))*math.exp(-35*t)*.3
        result.append(value * attack)
    # Explicit release protects against clicks on all effects.
    for i in range(min(200, len(result))):
        result[-1-i] *= i/200
    write('sfx/'+name, result)


if __name__ == '__main__':
    music('hearth', 80, 0, .45)
    music('border_watch', 100, 0, 1)
    music('last_bastion', 108, -2, 1.3)
    for name, duration in [('ui',.12),('build',.45),('upgrade',.55),('arrow',.18),
                           ('magic',.4),('cannon',.6),('melee',.16),('death',.2),
                           ('meteor',.9),('reinforce',.65),('wave',.8),('victory',1.6),
                           ('defeat',1.6),('leak',.45)]:
        effect(name, duration, name)
