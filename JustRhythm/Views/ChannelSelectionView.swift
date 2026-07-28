import SwiftUI

/// Sélection de plusieurs canaux MIDI à écouter à la fois — utile pour un
/// clavier multitimbral qui répartit ses parties sur plusieurs canaux (ex.
/// piano au 1, accompagnement aux 9 et 10). (EX-017)
struct ChannelSelectionView: View {

    let settings: Settings

    var body: some View {
        List {
            Section {
                row(String(localized: "All channels"), isOn: settings.midiChannels.isEmpty) {
                    settings.midiChannels.removeAll()
                }
            }

            Section {
                ForEach(1...16, id: \.self) { channel in
                    row(String(format: NSLocalizedString("Channel %d", comment: ""), channel),
                        isOn: settings.midiChannels.contains(channel)) {
                        toggle(channel)
                    }
                }
            }
        }
        .navigationTitle("Listened channels")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
    }

    private func toggle(_ channel: Int) {
        if settings.midiChannels.contains(channel) {
            settings.midiChannels.remove(channel)
        } else {
            settings.midiChannels.insert(channel)
        }
    }
}
