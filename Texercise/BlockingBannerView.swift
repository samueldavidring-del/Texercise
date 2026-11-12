import SwiftUI

struct BlockingBannerView: View {
    /// True when today's hard daily limit is the reason for the block,
    /// rather than simply being out of points.
    var isHardBlocked: Bool = false

    /// Called when the user taps the close button. Hides the banner for the
    /// current block only — the apps themselves stay blocked.
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(isHardBlocked ? "Daily Limit Reached" : "Apps Restricted")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(isHardBlocked
                     ? "Your selected apps are locked until tomorrow"
                     : "Earn points to unlock your selected apps")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss banner")
            } else {
                Image(systemName: "figure.run")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 16) {
        BlockingBannerView(onDismiss: {})
        BlockingBannerView(isHardBlocked: true, onDismiss: {})
    }
}
