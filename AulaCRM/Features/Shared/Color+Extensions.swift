import SwiftUI

#if !os(macOS)
import UIKit

typealias NSColor = UIColor

extension UIColor {
    static var textBackgroundColor: UIColor {
        return .systemBackground
    }
}

extension Color {
    init(nsColor: UIColor) {
        self.init(uiColor: nsColor)
    }
}
#endif
