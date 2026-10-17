import SwiftUI

/// An overlay scroll bar only appears once you are already scrolling, which is
/// no use as a sign that there is more below.
struct OverflowFade: View {
    var height: CGFloat = 24

    var body: some View {
        LinearGradient(
            colors: [.clear, Color(nsColor: .windowBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom,
        )
        .frame(height: height)
        .allowsHitTesting(false)
    }
}
