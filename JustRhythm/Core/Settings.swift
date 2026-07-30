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

/// Ce que l'application renvoie au clavier quand une frappe tombe dans la
/// zone « juste ». (EX-130 / EX-131)
///
/// Les libellés décrivent ce que l'application **émet**, jamais ce qu'on
/// entendra : cela dépend du Local Control, réglé sur l'instrument et hors de
/// notre portée. L'ancien « Note muette si imprécise » était faux dans la
/// configuration d'usine — Local Control activé, rien n'est muet, et ce sont
/// au contraire les frappes justes qui s'entendent renforcées. La consigne du
/// pied de page dit, elle, ce qu'il faut configurer pour obtenir l'effet voulu.
enum FeedbackMode: Int, CaseIterable, Identifiable {
    case octave = 0, mute = 1
    var id: Int { rawValue }

    /// Ce que la fonction cherche à obtenir, commun aux deux modes.
    ///
    /// Le seul endroit où l'intention a sa place : l'en-tête dit où va le son,
    /// l'interrupteur à quelle condition, le mode lequel — aucun des trois n'a
    /// à porter le pourquoi. Il s'arrête à ce qui se constate : le retour tombe
    /// dans le temps du jeu. Qu'il fasse progresser plus vite est plausible,
    /// n'est pas mesuré, et ne sera donc pas affirmé. (EX-097)
    static let purpose = String(localized: "The point is immediate confirmation: an accurate hit is heard as it happens, in the time of playing rather than the time of analysis — which no number read afterwards can replace.")

    /// Court : l'en-tête et l'interrupteur ont déjà posé « au clavier » et
    /// « quand la frappe est juste ». Les répéter ici ne dirait rien de plus.
    var label: String {
        switch self {
        case .octave: return String(localized: "Octave note")
        case .mute:   return String(localized: "Same note")
        }
    }

    var hint: String {
        switch self {
        case .octave:
            return String(localized: "A note an octave above the one you played is sent back when the hit lands in the “right” zone. Leave Local Control on, so you keep hearing your own notes alongside it.")
        case .mute:
            return String(localized: "The note you played is sent back at the same pitch, but only when the hit is accurate. Turn Local Control off to make the instrument stay silent on inaccurate hits — otherwise it already sounds on its own, and accurate hits are merely reinforced.")
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
    /// Le métronome démarre sur le message Start de la boîte à rythmes, et son
    /// tempo se cale ensuite sur l'horloge MIDI du clavier : les deux ne se
    /// séparent pas en pratique, un seul réglage suffit. (EX-053 / EX-054)
    var syncStart: Bool { didSet { store.set(syncStart, forKey: K.syncStart) } }
    /// Un retour sonore signale la justesse de la frappe sur l'instrument.
    var feedbackEnabled: Bool { didSet { store.set(feedbackEnabled, forKey: K.feedbackOn) } }
    var feedbackMode: FeedbackMode { didSet { store.set(feedbackMode.rawValue, forKey: K.feedbackMode) } }
    /// Le téléphone sonorise lui-même les notes reçues. (EX-133)
    var instrumentEnabled: Bool { didSet { store.set(instrumentEnabled, forKey: K.instrOn) } }
    var instrumentVoice: InstrumentVoice { didSet { store.set(instrumentVoice.rawValue, forKey: K.instrVoice) } }

    // — Configuration : ce qu'on règle une fois, donc derrière l'engrenage —
    var manualAlignmentMs: Double { didSet { store.set(manualAlignmentMs, forKey: K.align) } }
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
    /// Resserrement du graphe, de 0,25 à 1. À 1, il couvre exactement la
    /// demi-subdivision — soit toute la plage qu'un écart peut atteindre,
    /// ni plus (espace mort) ni moins (notes écrasées au bord). (EX-067)
    var scaleZoom: Double { didSet { store.set(scaleZoom, forKey: K.scaleZoom) } }
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
        beatsPerBar  = Self.int(K.bar, 4)
        clickVoice   = ClickVoice(rawValue: Self.int(K.voice, 0)) ?? .claves
        syncStart    = Self.bool(K.syncStart, false)
        feedbackEnabled = Self.bool(K.feedbackOn, false)
        feedbackMode    = FeedbackMode(rawValue: Self.int(K.feedbackMode, 0)) ?? .octave
        instrumentEnabled = Self.bool(K.instrOn, false)
        instrumentVoice   = InstrumentVoice(rawValue: Self.int(K.instrVoice, 0)) ?? .piano

        manualAlignmentMs = Self.double(K.align, 0)
        tolerancePercent  = Self.double(K.tolPct, 5)
        lastSourceID      = Int32(Self.int(K.source, 0))
        midiChannels      = Self.intSet(K.channels, [])
        minVelocity       = Self.int(K.minVel, 1)
        chordWindowMs     = Self.double(K.chord, 30)
        scaleZoom         = Self.double(K.scaleZoom, 1)
        statsWindow       = Self.int(K.statsWin, 200)
    }

    /// Durée d'un pas de grille, en secondes. (EX-032)
    var stepPeriod: Double { 60.0 / bpm / Double(subdivision.rawValue) }

    /// Nombre de pas de grille dans une mesure. 0 si aucun accent. (EX-042)
    var stepsPerBar: Int { beatsPerBar > 0 ? beatsPerBar * subdivision.rawValue : 0 }

    private enum K {
        static let bpm = "bpm", click = "click", volume = "volume"
        static let subdiv = "subdiv", bar = "bar", voice = "voice"
        static let syncStart = "syncStart"
        static let feedbackOn = "feedbackOn", feedbackMode = "feedbackMode"
        static let instrOn = "instrOn", instrVoice = "instrVoice"
        static let align = "align", tolPct = "tolPct", source = "source"
        static let channels = "channels", minVel = "minVel", chord = "chord"
        static let scaleZoom = "scaleZoom", statsWin = "statsWin"
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
