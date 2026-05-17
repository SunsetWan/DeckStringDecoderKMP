import DeckStringDecoder
import SwiftUI

struct ContentView: View {
    @State private var decodeResult = DemoResult.idle
    @State private var roundTripResult = DemoResult.idle
    @State private var invalidInputResult = DemoResult.idle

    var body: some View {
        NavigationView {
            List {
                Section {
                    DebugActionRow(
                        title: "Decode",
                        systemImage: "doc.text.magnifyingglass",
                        result: decodeResult,
                        action: runDecode
                    )

                    DebugActionRow(
                        title: "Round Trip",
                        systemImage: "arrow.triangle.2.circlepath",
                        result: roundTripResult,
                        action: runRoundTrip
                    )

                    DebugActionRow(
                        title: "Invalid Input",
                        systemImage: "exclamationmark.triangle",
                        result: invalidInputResult,
                        action: runInvalidInput
                    )
                }

                Section("Current Deck") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fixture")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Standard Warrior")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deck String")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Self.standardDeckString)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("DeckString Debug")
        }
        .navigationViewStyle(.stack)
    }

    private func runDecode() {
        do {
            let deck = try Self.decoder.decode(Self.standardDeckString)
            decodeResult = .success(deck.summary)
        } catch {
            decodeResult = .failure(Self.describe(error))
        }
    }

    private func runRoundTrip() {
        do {
            let deck = try Self.decoder.decode(Self.standardDeckString)
            let encodedDeckString = try Self.decoder.encode(deck)
            let decodedDeck = try Self.decoder.decode(encodedDeckString)

            if decodedDeck == deck {
                roundTripResult = .success("Encoded and decoded deck matches fixture.")
            } else {
                roundTripResult = .failure("Encoded deck decoded to a different model.")
            }
        } catch {
            roundTripResult = .failure(Self.describe(error))
        }
    }

    private func runInvalidInput() {
        do {
            _ = try Self.decoder.decode(Self.invalidDeckString)
            invalidInputResult = .failure("Expected DeckStringError, but decode succeeded.")
        } catch let error as DeckStringError {
            invalidInputResult = .success(Self.describe(error))
        } catch {
            invalidInputResult = .failure(Self.describe(error))
        }
    }

    private static let decoder = DeckStringDecoder()
    private static let standardDeckString = "AAECAQcCrwSRvAIOHLACkQP/A44FqAXUBaQG7gbnB+8HgrACiLACub8CAAA="
    private static let invalidDeckString = "AAEFAQcAAAA="

    private static func describe(_ error: Error) -> String {
        if let deckStringError = error as? DeckStringError {
            return deckStringError.errorDescription ?? "\(deckStringError)"
        }

        return error.localizedDescription
    }
}

private struct DebugActionRow: View {
    let title: String
    let systemImage: String
    let result: DemoResult
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            Text(result.message)
                .font(.callout)
                .foregroundColor(result.color)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

private struct DemoResult {
    let message: String
    let color: Color

    static let idle = DemoResult(message: "Not run", color: .secondary)

    static func success(_ message: String) -> DemoResult {
        DemoResult(message: message, color: .green)
    }

    static func failure(_ message: String) -> DemoResult {
        DemoResult(message: message, color: .red)
    }
}

private extension Deck {
    var summary: String {
        let heroText = heroes.map(String.init).joined(separator: ", ")
        return "Format: \(format.debugName), heroes: \(heroText), cards: \(totalCardCount), sideboard: \(totalSideboardCardCount)"
    }
}

private extension DeckFormat {
    var debugName: String {
        switch self {
        case .unknown:
            return "unknown"
        case .wild:
            return "wild"
        case .standard:
            return "standard"
        case .classic:
            return "classic"
        case .twist:
            return "twist"
        @unknown default:
            return "future"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
