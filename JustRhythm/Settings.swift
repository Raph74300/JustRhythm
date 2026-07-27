import Foundation
import Observation

/// Finesse de la grille sur laquelle les notes sont jugées. (EX-041)
enum Subdivision: Int, CaseIterable, Identifiable {
    case quarter = 1, eighth = 2, triplet = 3, sixteenth = 4
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .quarter:   return "Noires"
        case .eighth:    return "Croches"
        case .triplet:   return "Triolets"
        case .sixteenth: return "Doubles-croches"
        }
    }
    var shortLabel: String {
        switch self {
        case .quarter:   return "♩"
        case .eighth:    return "♪"
        case .triplet:   return "3"
        case .sixteenth: return "♬"
        }
    }
}

/// Réglages persistants, restaurés au lancement. (EX-093)
@Observable
final class Settings {

    private let store = UserDefaults.standard

    // — Métronome : ce qu'on touche en jouant, donc sur l'écran principal —
    var bpm: Double { didSet { store.set(bpm, forKey: K.bpm) } }
    var clickEnabled: Bool { didSet { store.set(clickEnabled, forKey: K.click) } }
    var volume: Double { didSet { store.set(volume, forKey: K.volume) } }
    /// (EX-041)
    var subdivision: Subdivision { didSet { store.set(subdivision.rawValue, forKey: K.subdiv) } }
    /// 0 = aucun accent, sinon 2 à 12. (EX-042)
    var beatsPerBar: Int { didSet { store.set(beatsPerBar, forKey: K.bar) } }
    /// (EX-051)
    var clickVoice: ClickVoice { didSet { store.set(clickVoice.rawValue, forKey: K.voice) } }
    /// Le métronome démarre sur le message Start de la boîte à rythmes. (EX-053)
    var syncStart: Bool { didSet { store.set(syncStart, forKey: K.syncStart) } }
    /// Le tempo se cale sur l'horloge MIDI du clavier. (EX-054)
    var followClock: Bool { didSet { store.set(followClock, forKey: K.followClock) } }

    // — Configuration : ce qu'on règle une fois, donc derrière l'engrenage —
    var manualAlignmentMs: Double { didSet { store.set(manualAlignmentMs, forKey: K.align) } }
    var toleranceMs: Double { didSet { store.set(toleranceMs, forKey: K.tol) } }
    var lastSourceID: Int32 { didSet { store.set(Int(lastSourceID), forKey: K.source) } }
    /// 0 = tous les canaux, sinon 1 à 16. (EX-017)
    var midiChannel: Int { didSet { store.set(midiChannel, forKey: K.channel) } }
    /// (EX-018)
    var minVelocity: Int { didSet { store.set(minVelocity, forKey: K.minVel) } }
    /// Fenêtre de regroupement d'accord, en ms. 0 = chaque note comptée seule. (EX-036)
    var chordWindowMs: Double { didSet { store.set(chordWindowMs, forKey: K.chord) } }
    /// Échelle horizontale du graphe, en ms. (EX-067)
    var windowMs: Double { didSet { store.set(windowMs, forKey: K.window) } }
    /// Nombre de notes retenues pour les statistiques. (EX-084)
    var statsWindow: Int { didSet { store.set(statsWindow, forKey: K.statsWin) } }

    // =====================================================================
    // Helpers statiques : une fonction locale à init() qui lirait `store`
    // capturerait implicitement `self`, ce que Swift interdit avant la fin
    // de l'initialisation.
    // =====================================================================

    private static func double(_ key: String, _ fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? fallback
    }
    private static func int(_ key: String, _ fallback: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? fallback
    }
    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    init() {
        bpm          = Self.double(K.bpm, 80)
        clickEnabled = Self.bool(K.click, true)
        volume       = Self.double(K.volume, 0.5)
        subdivision  = Subdivision(rawValue: Self.int(K.subdiv, 1)) ?? .quarter
        beatsPerBar  = Self.int(K.bar, 4)
        clickVoice   = ClickVoice(rawValue: Self.int(K.voice, 0)) ?? .claves
        syncStart    = Self.bool(K.syncStart, false)
        followClock  = Self.bool(K.followClock, false)

        manualAlignmentMs = Self.double(K.align, 0)
        toleranceMs       = Self.double(K.tol, 20)
        lastSourceID      = Int32(Self.int(K.source, 0))
        midiChannel       = Self.int(K.channel, 0)
        minVelocity       = Self.int(K.minVel, 1)
        chordWindowMs     = Self.double(K.chord, 30)
        windowMs          = Self.double(K.window, 120)
        statsWindow       = Self.int(K.statsWin, 200)
    }

    /// Durée d'un pas de grille, en secondes. (EX-032)
    var stepPeriod: Double { 60.0 / bpm / Double(subdivision.rawValue) }

    /// Nombre de pas de grille dans une mesure. 0 si aucun accent. (EX-042)
    var stepsPerBar: Int { beatsPerBar > 0 ? beatsPerBar * subdivision.rawValue : 0 }

    private enum K {
        static let bpm = "bpm", click = "click", volume = "volume"
        static let subdiv = "subdiv", bar = "bar", voice = "voice"
        static let syncStart = "syncStart", followClock = "followClock"
        static let align = "align", tol = "tol", source = "source"
        static let channel = "channel", minVel = "minVel", chord = "chord"
        static let window = "window", statsWin = "statsWin"
    }
}

/// Jusqu'où la dispersion reste compatible avec un rendu propre. (EX-082)
///
/// Un pourcentage seul ne tient pas : la variabilité motrice humaine a un
/// plancher qui ne se contracte pas indéfiniment avec le tempo. On retient
/// donc le plus permissif des deux critères.
enum Regularity {
    static let ratio = 0.05
    static let floor = 0.015

    static func limit(step: Double) -> Double { max(ratio * step, floor) }

    static func isAcceptable(sd: Double, step: Double) -> Bool {
        sd > 0 && sd <= limit(step: step)
    }
}
