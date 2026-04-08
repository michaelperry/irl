import SwiftUI

enum IRLColors {
    static let oceanBlue = Color(red: 0 / 255, green: 102 / 255, blue: 255 / 255)
    static let earthGreen = Color(red: 0 / 255, green: 204 / 255, blue: 102 / 255)
    static let pureWhite = Color.white

    // Adaptive background — deep space in dark, clean white in light
    static let deepSpace = Color("DeepSpace")
    static let surface = Color("Surface")
    static let cardBackground = Color("CardBackground")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")

    static var earthGradient: LinearGradient {
        LinearGradient(
            colors: [oceanBlue, earthGreen],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
