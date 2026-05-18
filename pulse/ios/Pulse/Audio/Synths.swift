import AVFoundation
import Foundation

enum Synths {

    static func render(_ voice: VoiceKind, kit: String = "studio", sampleRate: Double) -> [Float] {
        switch voice {
        case .kick:  return renderKick(kit: kit, sampleRate: sampleRate)
        case .snare: return renderSnare(kit: kit, sampleRate: sampleRate)
        case .hat:   return renderHat(kit: kit, sampleRate: sampleRate)
        case .clap:  return renderClap(kit: kit, sampleRate: sampleRate)
        case .bass:  return renderBass(kit: kit, sampleRate: sampleRate)
        case .pluck: return renderPluck(kit: kit, sampleRate: sampleRate)
        case .pad:   return renderPad(kit: kit, sampleRate: sampleRate)
        case .perc:  return renderPerc(kit: kit, sampleRate: sampleRate)
        }
    }

    // MARK: - Envelope helpers

    private static func decay(_ t: Double, peak: Float, decay: Double) -> Float {
        peak * Float(exp(-t / decay * 5))
    }

    private static func ad(_ t: Double, attack: Double, decay: Double, peak: Float) -> Float {
        if t < attack { return peak * Float(t / attack) }
        return peak * Float(exp(-(t - attack) / decay * 5))
    }

    private static func adsr(_ t: Double, attack: Double, decay: Double, sustain: Float,
                             release: Double, totalLen: Double, peak: Float) -> Float {
        let releaseStart = totalLen - release
        if t < attack { return peak * Float(t / attack) }
        if t < releaseStart {
            let dt = t - attack
            let level = Float(exp(-dt / decay * 3))
            return peak * (sustain + (1 - sustain) * max(level, 0))
        }
        let rt = t - releaseStart
        return peak * sustain * Float(exp(-rt / max(release, 0.0001) * 5))
    }
}

// MARK: - Kick

private extension Synths {
    static func renderKick(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.40, startF = 150.0, endF = 40.0, sweepT = 0.18, decayT = 0.18, peak = Float(1.00)
        switch kit {
        case "dusty-tape":  len = 0.45; startF = 110; endF = 35; sweepT = 0.25; decayT = 0.24; peak = 0.85
        case "boom-bap":    len = 0.35; startF = 185; endF = 45; sweepT = 0.14; decayT = 0.14
        case "808":         len = 0.80; startF = 80;  endF = 28; sweepT = 0.35; decayT = 0.55
        case "jazz":        len = 0.35; startF = 100; endF = 50; sweepT = 0.20; decayT = 0.22; peak = 0.75
        case "rainy-night": len = 0.50; startF = 90;  endF = 32; sweepT = 0.30; decayT = 0.30; peak = 0.60
        case "music-box":   len = 0.22; startF = 420; endF = 405; sweepT = 0.012; decayT = 0.10; peak = 0.38
        case "wind-chimes": len = 0.18; startF = 180; endF = 90;  sweepT = 0.05;  decayT = 0.06; peak = 0.18
        case "marimba":     len = 0.35; startF = 150; endF = 100; sweepT = 0.03;  decayT = 0.22; peak = 0.65
        case "arcade":      len = 0.18; startF = 200; endF = 50;  sweepT = 0.08;  decayT = 0.08; peak = 0.85
        case "glass":       len = 0.50; startF = 100; endF = 60;  sweepT = 0.15;  decayT = 0.30; peak = 0.45
        case "toy-piano":   len = 0.20; startF = 250; endF = 120; sweepT = 0.06;  decayT = 0.08; peak = 0.40
        case "jungle":      len = 0.35; startF = 200; endF = 42;  sweepT = 0.12;  decayT = 0.15; peak = 0.95
        case "space":       len = 0.60; startF = 70;  endF = 25;  sweepT = 0.35;  decayT = 0.40; peak = 0.65
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let freq = startF * pow(endF / startF, min(t / sweepT, 1))
            phase += 2 * .pi * freq / sampleRate
            out[i] = Float(sin(phase)) * decay(t, peak: peak, decay: decayT)
        }
        return out
    }
}

// MARK: - Snare

private extension Synths {
    static func renderSnare(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.30, hpAlpha = 0.92, noiseDecay = 0.12, noisePeak = Float(0.70)
        var bodyFreq = 220.0, bodyDecay = 0.08, bodyPeak = Float(0.40)
        switch kit {
        case "dusty-tape":
            len = 0.32; hpAlpha = 0.85; noiseDecay = 0.16; noisePeak = 0.50
            bodyFreq = 180; bodyDecay = 0.12; bodyPeak = 0.30
        case "boom-bap":
            len = 0.28; hpAlpha = 0.96; noiseDecay = 0.09; noisePeak = 0.85
            bodyFreq = 260; bodyDecay = 0.06; bodyPeak = 0.45
        case "808":
            len = 0.32; hpAlpha = 0.94; noiseDecay = 0.14; noisePeak = 0.85
            bodyFreq = 200; bodyDecay = 0.06; bodyPeak = 0.25
        case "jazz":
            len = 0.36; hpAlpha = 0.80; noiseDecay = 0.20; noisePeak = 0.45
            bodyFreq = 160; bodyDecay = 0.16; bodyPeak = 0.25
        case "rainy-night":
            len = 0.40; hpAlpha = 0.78; noiseDecay = 0.25; noisePeak = 0.30
            bodyFreq = 140; bodyDecay = 0.20; bodyPeak = 0.15
        case "music-box":
            // Almost no noise — just a high pure tine ping
            len = 0.24; hpAlpha = 0.95; noiseDecay = 0.004; noisePeak = 0.04
            bodyFreq = 1318.5; bodyDecay = 0.14; bodyPeak = 0.58
        case "wind-chimes":
            len = 0.28; hpAlpha = 0.96; noiseDecay = 0.003; noisePeak = 0.02
            bodyFreq = 1760; bodyDecay = 0.16; bodyPeak = 0.55
        case "marimba":
            len = 0.28; hpAlpha = 0.90; noiseDecay = 0.005; noisePeak = 0.05
            bodyFreq = 440; bodyDecay = 0.18; bodyPeak = 0.65
        case "arcade":
            len = 0.12; hpAlpha = 0.95; noiseDecay = 0.04; noisePeak = 0.80
            bodyFreq = 400; bodyDecay = 0.03; bodyPeak = 0.15
        case "glass":
            len = 0.35; hpAlpha = 0.96; noiseDecay = 0.005; noisePeak = 0.06
            bodyFreq = 1047; bodyDecay = 0.20; bodyPeak = 0.62
        case "toy-piano":
            len = 0.18; hpAlpha = 0.90; noiseDecay = 0.06; noisePeak = 0.45
            bodyFreq = 600; bodyDecay = 0.05; bodyPeak = 0.25
        case "jungle":
            len = 0.25; hpAlpha = 0.96; noiseDecay = 0.08; noisePeak = 0.90
            bodyFreq = 280; bodyDecay = 0.05; bodyPeak = 0.50
        case "space":
            len = 0.22; hpAlpha = 0.90; noiseDecay = 0.10; noisePeak = 0.40
            bodyFreq = 800; bodyDecay = 0.08; bodyPeak = 0.38
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)

        var prevIn: Float = 0, prevOut: Float = 0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let n = Float.random(in: -1...1)
            let hp = Float(hpAlpha) * (prevOut + n - prevIn)
            prevIn = n; prevOut = hp
            out[i] += hp * ad(t, attack: 0.001, decay: noiseDecay, peak: noisePeak)
        }

        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let freq = bodyFreq * pow(0.5, min(t / bodyDecay, 1))
            phase += 2 * .pi * freq / sampleRate
            out[i] += Float(sin(phase)) * ad(t, attack: 0.001, decay: bodyDecay, peak: bodyPeak)
        }
        return out
    }
}

// MARK: - Hat

private extension Synths {
    static func renderHat(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.08, decayT = 0.04, peak = Float(0.35)
        switch kit {
        case "dusty-tape":  len = 0.10; decayT = 0.060; peak = 0.22
        case "boom-bap":    len = 0.06; decayT = 0.025; peak = 0.40
        case "808":         len = 0.05; decayT = 0.018; peak = 0.45
        case "jazz":        len = 0.15; decayT = 0.100; peak = 0.28
        case "rainy-night": len = 0.20; decayT = 0.150; peak = 0.16
        case "music-box":   len = 0.025; decayT = 0.008; peak = 0.18  // tiny spring-mechanism tick
        case "wind-chimes": len = 0.30;  decayT = 0.200; peak = 0.18
        case "marimba":     len = 0.06;  decayT = 0.025; peak = 0.28
        case "arcade":      len = 0.04;  decayT = 0.012; peak = 0.50
        case "glass":       len = 0.06;  decayT = 0.020; peak = 0.35
        case "toy-piano":   len = 0.05;  decayT = 0.015; peak = 0.40
        case "jungle":      len = 0.045; decayT = 0.015; peak = 0.45
        case "space":       len = 0.15;  decayT = 0.080; peak = 0.22
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        var prev: Float = 0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let n = Float.random(in: -1...1)
            let bright = n - prev; prev = n
            out[i] = bright * ad(t, attack: 0.001, decay: decayT, peak: peak)
        }
        return out
    }
}

// MARK: - Clap

private extension Synths {
    static func renderClap(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.25, peak = Float(0.50), finalDecay = 0.12
        switch kit {
        case "dusty-tape":  len = 0.28; peak = 0.35; finalDecay = 0.16
        case "boom-bap":    len = 0.22; peak = 0.65; finalDecay = 0.09
        case "808":         len = 0.20; peak = 0.75; finalDecay = 0.08
        case "jazz":        len = 0.25; peak = 0.40; finalDecay = 0.10
        case "rainy-night": len = 0.35; peak = 0.25; finalDecay = 0.22
        case "music-box":   len = 0.16; peak = 0.28; finalDecay = 0.07  // chime shimmer
        case "wind-chimes": len = 0.28; peak = 0.16; finalDecay = 0.20
        case "marimba":     len = 0.18; peak = 0.25; finalDecay = 0.08
        case "arcade":      len = 0.15; peak = 0.80; finalDecay = 0.05
        case "glass":       len = 0.20; peak = 0.45; finalDecay = 0.09
        case "toy-piano":   len = 0.16; peak = 0.45; finalDecay = 0.06
        case "jungle":      len = 0.18; peak = 0.80; finalDecay = 0.06
        case "space":       len = 0.40; peak = 0.28; finalDecay = 0.30
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        let bursts: [(Double, Double)] = [(0, 0.02), (0.012, 0.02), (0.025, 0.02), (0.045, finalDecay)]
        for (offset, dec) in bursts {
            let start = Int(offset * sampleRate)
            for i in start..<count {
                let t = Double(i - start) / sampleRate
                out[i] += Float.random(in: -1...1) * ad(t, attack: 0.001, decay: dec, peak: peak)
            }
        }
        return out
    }
}

// MARK: - Bass

private extension Synths {
    static func renderBass(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.35, freq = 55.0, lpStart = 1200.0, lpEnd = 180.0
        var sweepT = 0.25, decayT = 0.18, peak = Float(0.60), useSine = false
        switch kit {
        case "dusty-tape":
            len = 0.38; freq = 49; lpStart = 800;  lpEnd = 120; sweepT = 0.28; decayT = 0.22; peak = 0.55
        case "boom-bap":
            len = 0.35; freq = 41; lpStart = 1600; lpEnd = 220; sweepT = 0.22; decayT = 0.16; peak = 0.65
        case "808":
            len = 0.45; freq = 41; lpStart = 2000; lpEnd = 280; sweepT = 0.20; decayT = 0.25; peak = 0.70; useSine = true
        case "jazz":
            len = 0.40; freq = 49; lpStart = 900;  lpEnd = 200; sweepT = 0.15; decayT = 0.25; peak = 0.55; useSine = true
        case "rainy-night":
            len = 0.45; freq = 55; lpStart = 600;  lpEnd = 100; sweepT = 0.35; decayT = 0.28; peak = 0.45; useSine = true
        case "music-box":
            // Clean mid-register tine — G4, pure sine, no LP sweep
            len = 0.48; freq = 392; lpStart = 12000; lpEnd = 11000; sweepT = 0.01; decayT = 0.28; peak = 0.38; useSine = true
        case "wind-chimes":
            len = 0.55; freq = 440; lpStart = 12000; lpEnd = 11500; sweepT = 0.01; decayT = 0.35; peak = 0.32; useSine = true
        case "marimba":
            len = 0.45; freq = 82.4; lpStart = 12000; lpEnd = 11000; sweepT = 0.01; decayT = 0.30; peak = 0.55; useSine = true
        case "arcade":
            len = 0.25; freq = 98; lpStart = 2800; lpEnd = 800; sweepT = 0.10; decayT = 0.12; peak = 0.70
        case "glass":
            len = 0.55; freq = 65; lpStart = 12000; lpEnd = 11000; sweepT = 0.01; decayT = 0.40; peak = 0.40; useSine = true
        case "toy-piano":
            len = 0.35; freq = 110; lpStart = 3000; lpEnd = 1200; sweepT = 0.05; decayT = 0.20; peak = 0.45
        case "jungle":
            len = 0.40; freq = 41; lpStart = 1800; lpEnd = 200; sweepT = 0.15; decayT = 0.22; peak = 0.75; useSine = true
        case "space":
            len = 0.55; freq = 41; lpStart = 800; lpEnd = 60; sweepT = 0.40; decayT = 0.38; peak = 0.50; useSine = true
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0, lpPrev = Float(0)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            phase += 2 * .pi * freq / sampleRate
            let raw: Float
            if useSine {
                raw = Float(sin(phase))
            } else {
                raw = Float(2 * (phase / (2 * .pi) - floor(phase / (2 * .pi) + 0.5)))
            }
            let cutoff = lpStart * pow(lpEnd / lpStart, min(t / sweepT, 1))
            let rc = 1 / (2 * .pi * cutoff)
            let dt = 1 / sampleRate
            let alpha = Float(dt / (rc + dt))
            lpPrev = lpPrev + alpha * (raw - lpPrev)
            out[i] = lpPrev * ad(t, attack: 0.003, decay: decayT, peak: peak)
        }
        return out
    }
}

// MARK: - Pluck

private extension Synths {
    static func renderPluck(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.40, startF = 523.25, endF = 440.0, sweepT = 0.20, decayT = 0.18, peak = Float(0.50)
        switch kit {
        case "dusty-tape":  len = 0.45; startF = 392; endF = 330; sweepT = 0.22; decayT = 0.22; peak = 0.42
        case "boom-bap":    len = 0.38; startF = 440; endF = 370; sweepT = 0.18; decayT = 0.15
        case "808":         len = 0.42; startF = 480; endF = 380; sweepT = 0.15; decayT = 0.20; peak = 0.52
        case "jazz":        len = 0.35; startF = 659; endF = 587; sweepT = 0.15; decayT = 0.14; peak = 0.45
        case "rainy-night": len = 0.50; startF = 740; endF = 659; sweepT = 0.25; decayT = 0.28; peak = 0.35
        // C6 tine: sine fundamental + inharmonic partial at 2.756× (real music box overtone ratio)
        case "music-box":   len = 0.75; startF = 1046.5; endF = 1030.0; sweepT = 0.018; decayT = 0.50; peak = 0.50
        case "wind-chimes": len = 0.75; startF = 1568;   endF = 1530;   sweepT = 0.015; decayT = 0.50; peak = 0.45
        case "marimba":     len = 0.50; startF = 523;    endF = 515;    sweepT = 0.008; decayT = 0.28; peak = 0.55
        case "arcade":      len = 0.22; startF = 880;    endF = 440;    sweepT = 0.08;  decayT = 0.10; peak = 0.60
        case "glass":       len = 0.70; startF = 1319;   endF = 1290;   sweepT = 0.012; decayT = 0.45; peak = 0.48
        case "toy-piano":   len = 0.50; startF = 523;    endF = 510;    sweepT = 0.010; decayT = 0.30; peak = 0.52
        case "jungle":      len = 0.30; startF = 1047;   endF = 523;    sweepT = 0.08;  decayT = 0.12; peak = 0.58
        case "space":       len = 0.45; startF = 1047;   endF = 1175;   sweepT = 0.08;  decayT = 0.28; peak = 0.42
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        var phase2 = 0.0  // inharmonic partial, only used for music-box
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let freq = startF * pow(endF / startF, min(t / sweepT, 1))
            phase += 2 * .pi * freq / sampleRate
            if kit == "music-box" {
                // Inharmonic partial decays 2.5× faster, 22% amplitude
                phase2 += 2 * .pi * freq * 2.756 / sampleRate
                let env1 = ad(t, attack: 0.001, decay: decayT,       peak: peak)
                let env2 = ad(t, attack: 0.001, decay: decayT * 0.4, peak: peak * 0.22)
                out[i] = Float(sin(phase)) * env1 + Float(sin(phase2)) * env2
            } else if kit == "marimba" || kit == "glass" || kit == "wind-chimes" {
                out[i] = Float(sin(phase)) * ad(t, attack: 0.001, decay: decayT, peak: peak)
            } else {
                let normalized = phase / (2 * .pi)
                let frac = normalized - floor(normalized)
                let tri = Float(4 * abs(frac - 0.5) - 1)
                out[i] = tri * ad(t, attack: 0.002, decay: decayT, peak: peak)
            }
        }
        return out
    }
}

// MARK: - Pad

private extension Synths {
    static func renderPad(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.90, baseFreq = 261.63, detuneCents = 12.0, lpCutoff = 1600.0
        var attack = 0.06, decayT = 0.40, sustain = Float(0.40), releaseT = 0.40, peak = Float(0.35)
        switch kit {
        case "dusty-tape":
            len = 1.00; baseFreq = 246.94; detuneCents = 18; lpCutoff = 1100
            attack = 0.09; decayT = 0.50; sustain = 0.35; releaseT = 0.45; peak = 0.28
        case "boom-bap":
            len = 0.85; baseFreq = 220.00; detuneCents = 8;  lpCutoff = 1400
            attack = 0.05; decayT = 0.35; sustain = 0.45; releaseT = 0.38; peak = 0.38
        case "808":
            len = 1.00; baseFreq = 220.00; detuneCents = 22; lpCutoff = 1800
            attack = 0.07; decayT = 0.45; sustain = 0.45; releaseT = 0.45; peak = 0.38
        case "jazz":
            len = 1.00; baseFreq = 261.63; detuneCents = 6;  lpCutoff = 1400
            attack = 0.12; decayT = 0.50; sustain = 0.50; releaseT = 0.50; peak = 0.32
        case "rainy-night":
            len = 1.20; baseFreq = 220.00; detuneCents = 15; lpCutoff = 900
            attack = 0.15; decayT = 0.60; sustain = 0.50; releaseT = 0.60; peak = 0.25
        case "music-box":
            // Two detuned pure sines — delicate bell shimmer
            len = 0.90; baseFreq = 659.26; detuneCents = 2; lpCutoff = 20000
            attack = 0.012; decayT = 0.38; sustain = 0.50; releaseT = 0.38; peak = 0.30
        case "wind-chimes":
            len = 1.10; baseFreq = 659.26; detuneCents = 2;  lpCutoff = 20000
            attack = 0.10; decayT = 0.50; sustain = 0.38; releaseT = 0.55; peak = 0.22
        case "marimba":
            len = 0.90; baseFreq = 261.63; detuneCents = 3;  lpCutoff = 20000
            attack = 0.03; decayT = 0.40; sustain = 0.45; releaseT = 0.45; peak = 0.30
        case "arcade":
            len = 0.70; baseFreq = 220;    detuneCents = 0;  lpCutoff = 2200
            attack = 0.02; decayT = 0.25; sustain = 0.60; releaseT = 0.30; peak = 0.40
        case "glass":
            len = 1.00; baseFreq = 440;    detuneCents = 1;  lpCutoff = 20000
            attack = 0.06; decayT = 0.45; sustain = 0.45; releaseT = 0.50; peak = 0.28
        case "toy-piano":
            len = 0.80; baseFreq = 261.63; detuneCents = 14; lpCutoff = 2800
            attack = 0.03; decayT = 0.35; sustain = 0.45; releaseT = 0.40; peak = 0.35
        case "jungle":
            len = 1.00; baseFreq = 87.31;  detuneCents = 20; lpCutoff = 700
            attack = 0.12; decayT = 0.50; sustain = 0.50; releaseT = 0.55; peak = 0.30
        case "space":
            len = 1.20; baseFreq = 110;    detuneCents = 25; lpCutoff = 1200
            attack = 0.25; decayT = 0.60; sustain = 0.55; releaseT = 0.65; peak = 0.28
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        let freqs = [
            baseFreq * pow(2.0, -detuneCents / 1200.0),
            baseFreq * pow(2.0,  detuneCents / 1200.0),
        ]
        var phases = [0.0, 0.0]
        var lpPrev: Float = 0
        let rc = 1 / (2 * Double.pi * lpCutoff)
        let dt = 1 / sampleRate
        let alpha = Float(dt / (rc + dt))
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var sample: Float = 0
            for (j, f) in freqs.enumerated() {
                phases[j] += 2 * .pi * f / sampleRate
                if kit == "music-box" || kit == "wind-chimes" || kit == "glass" || kit == "space" || kit == "marimba" {
                    sample += Float(sin(phases[j]))
                } else {
                    let frac = phases[j] / (2 * .pi) - floor(phases[j] / (2 * .pi))
                    sample += Float(2 * frac - 1)
                }
            }
            sample *= 0.5
            lpPrev += alpha * (sample - lpPrev)
            out[i] = lpPrev * adsr(t, attack: attack, decay: decayT, sustain: sustain,
                                   release: releaseT, totalLen: len, peak: peak)
        }
        return out
    }
}

// MARK: - Perc

private extension Synths {
    static func renderPerc(kit: String, sampleRate: Double) -> [Float] {
        var len = 0.12, startF = 880.0, endF = 440.0, sweepT = 0.08, decayT = 0.06, peak = Float(0.40)
        switch kit {
        case "dusty-tape":  len = 0.14; startF = 440;  endF = 220; sweepT = 0.10; decayT = 0.08; peak = 0.32
        case "boom-bap":    len = 0.10; startF = 1200; endF = 600; sweepT = 0.06; decayT = 0.05; peak = 0.45
        case "808":         len = 0.18; startF = 1760; endF = 880; sweepT = 0.12; decayT = 0.12; peak = 0.38
        case "jazz":        len = 0.10; startF = 600;  endF = 350; sweepT = 0.06; decayT = 0.06; peak = 0.38
        case "rainy-night": len = 0.16; startF = 320;  endF = 160; sweepT = 0.12; decayT = 0.12; peak = 0.22
        case "music-box":   len = 0.09; startF = 2637; endF = 2500; sweepT = 0.010; decayT = 0.032; peak = 0.33
        case "wind-chimes": len = 0.10; startF = 3500; endF = 3400; sweepT = 0.006; decayT = 0.040; peak = 0.35
        case "marimba":     len = 0.12; startF = 1568; endF = 1540; sweepT = 0.008; decayT = 0.070; peak = 0.45
        case "arcade":      len = 0.08; startF = 1320; endF = 660;  sweepT = 0.040; decayT = 0.035; peak = 0.55
        case "glass":       len = 0.12; startF = 4000; endF = 3900; sweepT = 0.006; decayT = 0.055; peak = 0.32
        case "toy-piano":   len = 0.10; startF = 2100; endF = 2000; sweepT = 0.008; decayT = 0.050; peak = 0.40
        case "jungle":      len = 0.09; startF = 1500; endF = 750;  sweepT = 0.050; decayT = 0.040; peak = 0.48
        case "space":       len = 0.14; startF = 800;  endF = 2400; sweepT = 0.060; decayT = 0.060; peak = 0.35
        default: break
        }
        let count = Int(sampleRate * len)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let freq = startF * pow(endF / startF, min(t / sweepT, 1))
            phase += 2 * .pi * freq / sampleRate
            out[i] = Float(sin(phase)) * ad(t, attack: 0.001, decay: decayT, peak: peak)
        }
        return out
    }
}
