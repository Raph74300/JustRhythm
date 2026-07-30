import Foundation
import CoreMIDI
import Observation

/// Messages système temps réel émis par la boîte à rythmes ou le séquenceur
/// du clavier. (EX-053 / EX-054)
enum MIDITransport {
    case start          // 0xFA — départ, à partir du début
    case cont           // 0xFB — reprise là où on s'était arrêté
    case stop           // 0xFC — arrêt
    case clock          // 0xF8 — 24 impulsions par noire
}

struct MIDISource: Identifiable, Hashable {
    let id: Int32                   // kMIDIPropertyUniqueID
    let endpoint: MIDIEndpointRef
    let name: String
    let isBluetooth: Bool
}

/// Entrée MIDI. Aucune permission micro n'est demandée nulle part dans
/// l'application. (EX-010)
///
/// Phase 1 : USB filaire. L'appairage Bluetooth intégré est reporté — un
/// clavier déjà appairé dans les réglages iOS apparaît malgré tout ici, avec
/// un avertissement, car sa gigue fausse la moyenne.
@Observable
final class MIDIManager {

    private(set) var sources: [MIDISource] = []
    var selectedID: Int32 = 0
    var lastNote: String?

    /// Source choisie explicitement, retenue d'une séance à l'autre. (EX-013)
    ///
    /// Distincte de `selectedID`, qui est la source réellement connectée à
    /// l'instant : au lancement, le clavier n'est pas toujours énuméré à temps
    /// et il faut bien se rabattre sur autre chose. Sans cette mémoire, ce
    /// repli deviendrait définitif — il existe encore au balayage suivant,
    /// donc rien ne ramènerait jamais au clavier voulu.
    @ObservationIgnored var preferredID: Int32 = 0

    /// (instant en secondes host, note, vélocité, canal 0-15)
    @ObservationIgnored var onNote: ((Double, UInt8, UInt8, UInt8) -> Void)?

    /// (note, canal 0-15). Ne sert **pas** à la mesure, qui ne compte que des
    /// frappes (EX-016) : uniquement à relâcher la note du module sonore, qui
    /// tiendrait sinon indéfiniment. (EX-133)
    @ObservationIgnored var onNoteOff: ((UInt8, UInt8) -> Void)?

    /// (numéro de contrôleur, valeur, canal 0-15). Même remarque : la pédale
    /// reste ignorée de la mesure, elle n'est transmise qu'au module sonore.
    @ObservationIgnored var onController: ((UInt8, UInt8, UInt8) -> Void)?

    /// Prévenu quand la source active disparaît en cours de séance. (EX-014)
    @ObservationIgnored var onSourceLost: ((String) -> Void)?

    /// (instant en secondes host, message). (EX-053 / EX-054)
    @ObservationIgnored var onTransport: ((Double, MIDITransport) -> Void)?

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var outputPort = MIDIPortRef()
    @ObservationIgnored private var connected: MIDIEndpointRef?
    @ObservationIgnored private var destination: MIDIEndpointRef?
    @ObservationIgnored private var runningStatus: UInt8 = 0

    var selected: MIDISource? { sources.first { $0.id == selectedID } }

    // =====================================================================

    func start() {
        MIDIClientCreateWithBlock("JustRhythm" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        MIDIInputPortCreateWithBlock(client, "Input" as CFString, &port) { [weak self] packets, _ in
            self?.read(packets)
        }
        MIDIOutputPortCreate(client, "Output" as CFString, &outputPort)
        refresh()
    }

    func refresh() {
        let previousName = selected?.name
        var found: [MIDISource] = []
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { continue }
            let name = Self.string(endpoint, kMIDIPropertyDisplayName)
                ?? Self.string(endpoint, kMIDIPropertyName)
                ?? "Source \(index + 1)"
            let driver = Self.string(endpoint, kMIDIPropertyDriverOwner) ?? ""
            var uid: Int32 = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uid)
            found.append(MIDISource(
                id: uid,
                endpoint: endpoint,
                name: name,
                isBluetooth: driver.localizedCaseInsensitiveContains("bluetooth")
                          || name.localizedCaseInsensitiveContains("bluetooth")))
        }
        sources = found

        // La source enregistrée est privilégiée à chaque balayage, et non au
        // seul premier lancement : c'est ce qui permet de retrouver son clavier
        // dès qu'il apparaît, même si l'application a dû se rabattre sur une
        // autre source en l'attendant. (EX-013)
        if let preferred = sources.first(where: { $0.id == preferredID }) {
            selectedID = preferred.id
            connect(endpoint: preferred.endpoint)
        } else if let current = sources.first(where: { $0.id == selectedID }) {
            connect(endpoint: current.endpoint)
        } else if let first = sources.first {
            if let previousName { onSourceLost?(previousName) }
            selectedID = first.id
            connect(endpoint: first.endpoint)
        } else {
            if let previousName { onSourceLost?(previousName) }
            connected = nil
            destination = nil
            selectedID = 0
            lastNote = nil
        }
    }

    /// Choix explicite de l'utilisateur : il devient la source privilégiée,
    /// et le restera aux balayages suivants même s'il disparaît un moment.
    func connect(uniqueID: Int32) {
        preferredID = uniqueID
        selectedID = uniqueID
        if let match = sources.first(where: { $0.id == uniqueID }) {
            connect(endpoint: match.endpoint)
        }
    }

    private func connect(endpoint: MIDIEndpointRef) {
        if let previous = connected, previous != endpoint {
            MIDIPortDisconnectSource(port, previous)
        }
        guard connected != endpoint else { return }
        if MIDIPortConnectSource(port, endpoint, nil) == noErr {
            connected = endpoint
            runningStatus = 0
            destination = Self.matchingDestination(for: endpoint)
        }
    }

    /// La source et la destination d'un même clavier partagent en général la
    /// même entité MIDI : c'est ce qui permet de retrouver la sortie sans
    /// demander un second choix à l'utilisateur.
    private static func matchingDestination(for source: MIDIEndpointRef) -> MIDIEndpointRef? {
        var entity = MIDIEntityRef()
        guard MIDIEndpointGetEntity(source, &entity) == noErr, entity != 0,
              MIDIEntityGetNumberOfDestinations(entity) > 0 else { return nil }
        let dest = MIDIEntityGetDestination(entity, 0)
        return dest != 0 ? dest : nil
    }

    // =====================================================================

    /// Notes envoyées à l'instrument et pas encore relâchées, décomptées.
    ///
    /// Un décompte et non un ensemble : en mode octave, deux touches distantes
    /// d'une octave produisent la même note de retour. Sans compter, relâcher
    /// la première éteindrait celle que la seconde fait encore sonner.
    @ObservationIgnored private var sentNotes: [UInt16: Int] = [:]

    /// Attaque une note en retour sur l'instrument, sans fixer sa fin.
    /// (EX-130 / EX-131)
    func startNote(_ note: UInt8, velocity: UInt8, channel: UInt8) {
        guard let destination else { return }
        sentNotes[Self.key(note, channel), default: 0] += 1
        send([0x90 | (channel & 0x0F), note, velocity], to: destination)
    }

    /// Relâche une note envoyée par `startNote`. Sans effet si elle ne sonne
    /// pas : on n'émet jamais un Note Off pour une note qu'on n'a pas jouée,
    /// sous peine de couper celle que l'instrumentiste tient lui-même.
    func stopNote(_ note: UInt8, channel: UInt8) {
        let key = Self.key(note, channel)
        guard let count = sentNotes[key], count > 0 else { return }
        if count > 1 { sentNotes[key] = count - 1 } else { sentNotes[key] = nil }
        guard let destination else { return }
        send([0x80 | (channel & 0x0F), note, 0], to: destination)
    }

    /// Éteint tout ce qui traîne. Appelée à l'arrêt d'une séance, à la coupure
    /// du retour et à la perte de la source : une note de retour ne doit jamais
    /// survivre à ce qui l'a déclenchée.
    func releaseAllSentNotes() {
        guard let destination else { sentNotes.removeAll(); return }
        for (key, _) in sentNotes {
            send([0x80 | UInt8(key >> 8), UInt8(key & 0xFF), 0], to: destination)
        }
        sentNotes.removeAll()
    }

    private static func key(_ note: UInt8, _ channel: UInt8) -> UInt16 {
        UInt16(channel & 0x0F) << 8 | UInt16(note)
    }

    private func send(_ bytes: [UInt8], to destination: MIDIEndpointRef) {
        var packet = MIDIPacket()
        packet.length = UInt16(bytes.count)
        withUnsafeMutableBytes(of: &packet.data) { raw in
            for (index, byte) in bytes.enumerated() { raw[index] = byte }
        }
        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDISend(outputPort, destination, &packetList)
    }

    // =====================================================================

    private func read(_ list: UnsafePointer<MIDIPacketList>) {
        for packet in list.unsafeSequence() {
            // L'horodatage vient du paquet, jamais de l'instant de traitement.
            // 0 signifie « maintenant ». (EX-030)
            let stamp = packet.pointee.timeStamp
            let time = stamp == 0 ? HostClock.now : HostClock.seconds(stamp)
            let length = Int(packet.pointee.length)
            let bytes: [UInt8] = withUnsafeBytes(of: packet.pointee.data) { raw in
                Array(raw.prefix(length))
            }
            parse(bytes, at: time)
        }
    }

    /// Seuls les Note On de vélocité non nulle nourrissent la mesure : c'est
    /// `onNote`, et lui seul, qui compte une frappe. (EX-016)
    ///
    /// Note Off et pédale sont désormais relayés à part, pour le module sonore
    /// qui doit bien relâcher ce qu'il a fait sonner (EX-133). Ils ne passent
    /// jamais par `onNote` : rien de ce qui suit ne compte comme une note
    /// jouée. Aftertouch, pitch bend et messages système restent ignorés.
    private func parse(_ bytes: [UInt8], at time: Double) {
        var i = 0
        while i < bytes.count {
            var status = bytes[i]

            if status & 0x80 != 0 {
                // Les messages temps réel peuvent surgir n'importe où, y
                // compris entre les octets de données d'un autre message.
                // Ils ne réinitialisent donc jamais le running status.
                if status >= 0xF8 {
                    switch status {
                    case 0xF8: onTransport?(time, .clock)
                    case 0xFA: onTransport?(time, .start)
                    case 0xFB: onTransport?(time, .cont)
                    case 0xFC: onTransport?(time, .stop)
                    default: break
                    }
                    i += 1; continue
                }
                if status >= 0xF0 { runningStatus = 0; i += 1; continue }  // système
                runningStatus = status
                i += 1
            } else {
                guard runningStatus != 0 else { i += 1; continue }
                status = runningStatus
            }

            let command = status & 0xF0
            let needed = (command == 0xC0 || command == 0xD0) ? 1 : 2
            guard i + needed <= bytes.count else { return }

            let d1 = bytes[i]
            let d2 = needed == 2 ? bytes[i + 1] : 0
            i += needed

            if command == 0x90 && d2 > 0 {
                onNote?(time, d1, d2, status & 0x0F)
            } else if command == 0x80 || (command == 0x90 && d2 == 0) {
                // Beaucoup de claviers relâchent par un Note On de vélocité
                // nulle plutôt que par un vrai Note Off : les deux comptent.
                onNoteOff?(d1, status & 0x0F)
            } else if command == 0xB0 {
                onController?(d1, d2, status & 0x0F)
            }
        }
    }

    private static func string(_ object: MIDIObjectRef, _ property: CFString) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(object, property, &value) == noErr,
              let result = value?.takeRetainedValue() else { return nil }
        return result as String
    }
}

enum NoteName {
    private static let solfege = ["Do", "Do♯", "Ré", "Ré♯", "Mi", "Fa",
                                  "Fa♯", "Sol", "Sol♯", "La", "La♯", "Si"]
    private static let letters = ["C", "C♯", "D", "D♯", "E", "F",
                                  "F♯", "G", "G♯", "A", "A♯", "B"]

    /// Solfège en français, notation lettrée pour toutes les autres langues. (EX-003)
    static func of(_ midiNote: UInt8) -> String {
        let n = Int(midiNote)
        let isFrench = Locale.current.language.languageCode?.identifier == "fr"
        let names = isFrench ? solfege : letters
        return names[n % 12] + String(n / 12 - 1)
    }
}
