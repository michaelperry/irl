import SwiftUI

enum IRLColors {
    static let oceanBlue = Color(red: 0 / 255, green: 102 / 255, blue: 255 / 255)
    static let earthGreen = Color(red: 0 / 255, green: 204 / 255, blue: 102 / 255)
    static let pureWhite = Color.white
    static let deepSpace = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)

    static var earthGradient: LinearGradient {
        LinearGradient(
            colors: [oceanBlue, earthGreen],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
