import SwiftUI

struct LoadingView: View {
    @State private var progress: Double = 0.0
    @State private var isLoading = true
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.accentColor.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // App icon/logo
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    Text("Texercise")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Loading your fitness data...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ProgressView(value: min(progress, 1.0), total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 200)
                }
            }
        }
        .onAppear {
            startLoading()
        }
    }
    
    private func startLoading() {
        // Simulate loading with progress
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            progress += 0.02
            
            if progress >= 1.0 {
                timer.invalidate()
                
                // Small delay before transitioning
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        onComplete()
                    }
                }
            }
        }
    }
}

#Preview {
    LoadingView {
        print("Loading complete")
    }
}
