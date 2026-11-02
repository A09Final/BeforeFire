import SwiftUI

struct MonitorSensorIllustration: View {
    let kind: MonitorReading.Kind
    let foreground: Color
    let secondaryForeground: Color

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(illustrationColor.gradient)
            .padding(kind == .presence ? 2 : 0)
    }

    // DESIGN: SF Symbols stay sharp at all card sizes. Change each illustration here.
    private var symbolName: String {
        switch kind {
        case .stoveHeat: "flame.fill"
        case .airQuality: "wind"
        case .presence: "figure.stand"
        case .roomTemperature: "thermometer.medium"
        case .roomHumidity: "drop.fill"
        case .areaPressure: "gauge.with.needle"
        }
    }

    private var illustrationColor: Color {
        switch kind {
        case .stoveHeat: MonitorStyle.flame
        case .roomTemperature, .roomHumidity: MonitorStyle.cyan
        case .airQuality: secondaryForeground
        case .presence, .areaPressure: foreground
        }
    }
}
