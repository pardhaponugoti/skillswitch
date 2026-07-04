import SwiftUI

enum Theme {
    // Enclosure — gray powder-coated steel
    static let steelTop = Color(red: 0.80, green: 0.81, blue: 0.83)
    static let steelMid = Color(red: 0.70, green: 0.71, blue: 0.74)
    static let steelBottom = Color(red: 0.58, green: 0.60, blue: 0.63)
    static let steelEdge = Color(red: 0.36, green: 0.38, blue: 0.41)

    // Wall behind the panel
    static let wallTop = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let wallBottom = Color(red: 0.08, green: 0.08, blue: 0.10)

    // Interior — dark dead front behind the breakers
    static let interiorTop = Color(red: 0.13, green: 0.14, blue: 0.16)
    static let interiorBottom = Color(red: 0.09, green: 0.10, blue: 0.12)

    // Breaker bodies
    static let breakerTop = Color(red: 0.22, green: 0.23, blue: 0.26)
    static let breakerBottom = Color(red: 0.16, green: 0.17, blue: 0.19)

    // Switch states
    static let liveGreen = Color(red: 0.22, green: 0.82, blue: 0.38)
    static let offRed = Color(red: 0.88, green: 0.30, blue: 0.24)
    static let deadGray = Color(red: 0.42, green: 0.44, blue: 0.47)

    // Safety yellow accents
    static let safety = Color(red: 0.97, green: 0.78, blue: 0.12)

    // Label tape (Dymo-style)
    static let tapeBlack = Color(red: 0.07, green: 0.07, blue: 0.09)

    static let inkDark = Color(red: 0.14, green: 0.15, blue: 0.17)

    static var steel: LinearGradient {
        LinearGradient(colors: [steelTop, steelMid, steelBottom], startPoint: .top, endPoint: .bottom)
    }

    static var wall: LinearGradient {
        LinearGradient(colors: [wallTop, wallBottom], startPoint: .top, endPoint: .bottom)
    }

    static var interior: LinearGradient {
        LinearGradient(colors: [interiorTop, interiorBottom], startPoint: .top, endPoint: .bottom)
    }

    static var breaker: LinearGradient {
        LinearGradient(colors: [breakerTop, breakerBottom], startPoint: .top, endPoint: .bottom)
    }
}

/// Phillips-head screw, for corners of the faceplate.
struct ScrewView: View {
    var angle: Double = 25

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.steel)
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.8))
            Group {
                Rectangle().frame(width: 7, height: 1.4)
                Rectangle().frame(width: 1.4, height: 7)
            }
            .foregroundStyle(.black.opacity(0.55))
            .rotationEffect(.degrees(angle))
        }
        .frame(width: 11, height: 11)
        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
    }
}

/// Black-and-yellow hazard stripe strip.
struct HazardStripe: View {
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<Int(geo.size.width / 14) + 2, id: \.self) { _ in
                    Parallelogram()
                        .fill(Theme.tapeBlack)
                        .frame(width: 7)
                    Parallelogram()
                        .fill(Theme.safety)
                        .frame(width: 7)
                }
            }
        }
        .background(Theme.safety)
        .clipped()
    }
}

struct Parallelogram: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let skew = rect.height * 0.8
        p.move(to: CGPoint(x: rect.minX + skew, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX + skew, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
