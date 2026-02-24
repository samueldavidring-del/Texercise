import SwiftUI

struct BlockingBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apps Restricted")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("Earn points to unlock your selected apps")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Spacer()
            
            Image(systemName: "figure.run")
                .foregroundColor(.white)
                .font(.title2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.gradient)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#Preview {
    BlockingBannerView()
}
