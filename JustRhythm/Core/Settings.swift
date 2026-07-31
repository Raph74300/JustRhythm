import Foundation
import Observation

/// Finesse de la grille sur laquelle les notes sont jugées. (EX-041)
enum Subdivision: Int, CaseIterable, Identifiable {
    case quarter = 1, eighth = 2, triplet = 3, sixteenth = 4
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .quarter:   return String(localized: "Quarter notes")
        case .eighth:    return String(localized: "Eighth notes")
        case .triplet:   return String(localized: "Triplets")
        case .sixteenth: return String(localized: "Sixteenth notes")
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

/// Ce que le module sonore fait différemment quand la frappe est juste. (EX-134)
///
/// L'application est la voix : elle peut donc réellement étouffer une note, ce
/// qu'un retour renvoyé à l'instrument ne permettait pas — il dépendait du Local
/// Control, réglé hors de notre portée, et cette dépendance a fini par emporter
/// toute la fonction (voir Risques et décisions).
///
/// `none` est l'état inactif : il n'y a donc pas d'interrupteur en plus, la
/// section Instrument garde sa taille.
enum AccuracyVoicing: Int, CaseIterable, Identifiable {
    case none = 0, octave = 1, accurateOnly = 2
    var id: Int { rawValue }

    /// Des verbes : l'application agit sur sa propre voix.
    var label: String {
        switch self {
        case .none:         return String(localized: "Nothing in particular")
        case .octave:       return String(localized: "Add an octave")
        case .accurateOnly: return String(localized: "Mute the others")
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
    /// (EX-051)
    var clickVoice: ClickVoice { didSet { store.set(clickVoice.rawValue, forKey: K.voice) } }
    /// Le métronome démarre sur le message Start de la boîte à rythmes, et son
    /// tempo se cale ensuite sur l'horloge MIDI du clavier : les deux ne se
    /// séparent pas en pratique, un seul réglage suffit. (EX-053 / EX-054)
    var syncStart: Bool { didSet { store.set(syncStart, forKey: K.syncStart) } }
    /// Le téléphone sonorise lui-même les notes reçues. (EX-133)
    var instrumentEnabled: Bool { didSet { store.set(instrumentEnabled, forKey: K.instrOn) } }
    var instrumentVoice: InstrumentVoice { didSet { store.set(instrumentVoice.rawValue, forKey: K.instrVoice) } }
    /// Ce que le module sonore change quand la frappe est juste. (EX-134)
    var accuracyVoicing: AccuracyVoicing { didSet { store.set(accuracyVoicing.rawValue, forKey: K.accVoicing) } }

    // — Configuration : ce qu'on règle une fois, donc derrière l'engrenage —
    var manualAlignmentMs: Double { didSet { store.set(manualAlignmentMs, forKey: K.align) } }
    /// Correction appliquée quand l'horloge du clavier est suivie. (EX-035)
    ///
    /// Une valeur à part, et non un caprice : quand l'instrument transmet son
    /// horloge, les messages temps réel passent devant les notes dans sa file de
    /// sortie, et les frappes sortent donc plus tard. La chaîne d'entrée est
    /// réellement plus longue dans ce mode — mesuré à une quinzaine de
    /// millisecondes de plus sur un CVP-303. L'application sait dans quel mode
    /// elle est : c'est à elle de choisir, pas à l'utilisateur de s'en souvenir.
    var syncAlignmentMs: Double { didSet { store.set(syncAlignmentMs, forKey: K.syncAlign) } }
    /// Largeur de la zone « juste », en pourcentage de la subdivision. Un
    /// écart n'a pas la même portée musicale selon la finesse de la grille :
    /// 50 ms sur une noire lente passent inaperçus, sur une double-croche
    /// rapide ils s'entendent. (EX-063)
    var tolerancePercent: Double { didSet { store.set(tolerancePercent, forKey: K.tolPct) } }
    var lastSourceID: Int32 { didSet { store.set(Int(lastSourceID), forKey: K.source) } }
    /// Vide = tous les canaux, sinon les canaux 1 à 16 retenus. (EX-017)
    var midiChannels: Set<Int> { didSet { store.set(Array(midiChannels), forKey: K.channels) } }
    /// (EX-018)
    var minVelocity: Int { didSet { store.set(minVelocity, forKey: K.minVel) } }
    /// Fenêtre de regroupement d'accord, en ms. 0 = chaque note comptée seule. (EX-036)
    var chordWindowMs: Double { didSet { store.set(chordWindowMs, forKey: K.chord) } }
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
    private static func intSet(_ key: String, _ fallback: Set<Int>) -> Set<Int> {
        (UserDefaults.standard.object(forKey: key) as? [Int]).map(Set.init) ?? fallback
    }

    init() {
        bpm          = Self.double(K.bpm, 80)
        clickEnabled = Self.bool(K.click, true)
        volume       = Self.double(K.volume, 0.5)
        subdivision  = Subdivision(rawValue: Self.int(K.subdiv, 1)) ?? .quarter
        clickVoice   = ClickVoice(rawValue: Self.int(K.voice, 0)) ?? .claves
        syncStart    = Self.bool(K.syncStart, false)
        instrumentEnabled = Self.bool(K.instrOn, false)
        instrumentVoice   = InstrumentVoice(rawValue: Self.int(K.instrVoice, 0)) ?? .piano
        accuracyVoicing   = AccuracyVoicing(rawValue: Self.int(K.accVoicing, 0)) ?? .none

        manualAlignmentMs = Self.double(K.align, 0)
        syncAlignmentMs   = Self.double(K.syncAlign, 0)
        tolerancePercent  = Self.double(K.tolPct, 5)
        lastSourceID      = Int32(Self.int(K.source, 0))
        midiChannels      = Self.intSet(K.channels, [])
        minVelocity       = Self.int(K.minVel, 1)
        chordWindowMs     = Self.double(K.chord, 30)
        statsWindow       = Self.int(K.statsWin, 200)
    }

    /// Durée d'un pas de grille, en secondes. (EX-032)
    var stepPeriod: Double { 60.0 / bpm / Double(subdivision.rawValue) }


    private enum K {
        static let bpm = "bpm", click = "click", volume = "volume"
        static let subdiv = "subdiv", voice = "voice"
        static let syncStart = "syncStart"
        static let instrOn = "instrOn", instrVoice = "instrVoice"
        static let accVoicing = "accVoicing"
        static let align = "align", syncAlign = "syncAlign"
        static let tolPct = "tolPct", source = "source"
        static let channels = "channels", minVel = "minVel", chord = "chord"
        static let statsWin = "statsWin"
    }
}

/// Largeur de la zone « juste », rapportée à la subdivision. (EX-063)
///
/// Même raisonnement que `Regularity` ci-dessous, et pour la même raison : un
/// pourcentage seul finirait par exiger mieux que ce qu'une main humaine peut
/// faire, et mieux qu'une oreille ne sait entendre. On garde donc le plus
/// permissif des deux critères.
enum Tolerance {
    /// Seuil courant de perception d'un décalage. En deçà, l'écart ne
    /// s'entend plus : le mesurer garde un sens, l'exiger n'en a pas.
    static let floor = 0.020

    static func limit(percent: Double, step: Double) -> Double {
        max(percent / 100 * step, floor)
    }
}

/// Jusqu'où la dispersion reste compatible avec un rendu propre. (EX-082)
///
/// Le type porte le nom du critère — la régularité —, la valeur qu'il juge
/// s'affiche sous le nom de « Dispersion » : c'est un écart-type, donc plus
/// il est grand, moins le jeu est régulier. Les deux mots ne désignent pas la
/// même chose et l'interface doit afficher celui qui se lit dans le bon sens.
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
