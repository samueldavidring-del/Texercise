import SwiftUI

struct SplashScreenView: View {
    let onFinished: () -> Void
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.blue)
                    
                    Text("Texercise")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Earn your screen time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 48)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startProgress()
        }
    }
    
    private func startProgress() {
        // Animate progress bar in stages, finishing after ~2 seconds minimum
        withAnimation(.easeIn(duration: 0.5)) { progress = 0.3 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.6)) { progress = 0.65 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.5)) { progress = 0.85 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.4)) { progress = 1.0 }
        }
        
        // Dismiss after bar completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            onFinished()
        }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
