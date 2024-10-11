import SwiftUI

extension Font {
    static func appTitle() -> Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }
    
    static func appHeadline() -> Font {
        .system(.title, design: .rounded, weight: .semibold)
    }
    
    static func appSubheadline() -> Font {
        .system(.title3, design: .rounded, weight: .medium)
    }
    
    static func appBody() -> Font {
        .system(.body, design: .default)
    }
    
    static func appCaption() -> Font {
        .system(.caption, design: .default)
    }
}