import Cocoa
import SwiftUI

class PoopOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.2, alpha: 0.95)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: PoopOverlayView(window: self))
        self.contentView = hostingView
    }

    func show() {
        self.orderFrontRegardless()
    }

    func hide() {
        self.orderOut(nil)
    }
}

struct PoopOverlayView: View {
    weak var window: PoopOverlayWindow?
    @State private var poops: [PoopEmoji] = []
    @State private var showMessage = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Brown background
                Color(red: 0.45, green: 0.3, blue: 0.15)
                    .opacity(0.97)

                // Poop emojis scattered everywhere
                ForEach(poops) { poop in
                    Text(poop.emoji)
                        .font(.system(size: poop.size))
                        .position(x: poop.x, y: poop.y)
                        .rotationEffect(.degrees(poop.rotation))
                }

                // Center message
                VStack(spacing: 20) {
                    Text("GET BACK TO WORK!")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 4, x: 2, y: 2)

                    Text("You got distracted!")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Button(action: {
                        NotificationCenter.default.post(name: .returnToFocusApp, object: nil)
                    }) {
                        HStack {
                            Text("Back to Focus")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundColor(Color(red: 0.45, green: 0.3, blue: 0.15))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                }
                .opacity(showMessage ? 1 : 0)
                .scaleEffect(showMessage ? 1 : 0.5)
            }
            .onAppear {
                generatePoops(in: geometry.size)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showMessage = true
                }
            }
        }
    }

    func generatePoops(in size: CGSize) {
        let poopEmojis = ["💩"]
        var newPoops: [PoopEmoji] = []

        // Generate a grid of poops with some randomness
        let columns = Int(size.width / 80)
        let rows = Int(size.height / 80)

        for row in 0..<rows {
            for col in 0..<columns {
                let baseX = CGFloat(col) * 80 + 40
                let baseY = CGFloat(row) * 80 + 40

                let poop = PoopEmoji(
                    id: UUID(),
                    emoji: poopEmojis.randomElement()!,
                    x: baseX + CGFloat.random(in: -20...20),
                    y: baseY + CGFloat.random(in: -20...20),
                    size: CGFloat.random(in: 30...60),
                    rotation: Double.random(in: -30...30)
                )
                newPoops.append(poop)
            }
        }

        poops = newPoops
    }
}

struct PoopEmoji: Identifiable {
    let id: UUID
    let emoji: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let rotation: Double
}

extension Notification.Name {
    static let returnToFocusApp = Notification.Name("returnToFocusApp")
}
