import SwiftUI

struct ProgressRingView: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct MultiRingView: View {
    let stepsProgress: Double
    let pointsProgress: Double
    let workoutProgress: Double
    let exerciseProgress: Double
    
    let stepsEnabled: Bool
    let pointsEnabled: Bool
    let workoutEnabled: Bool
    let exerciseEnabled: Bool
    
    private var enabledCount: Int {
        [stepsEnabled, pointsEnabled, workoutEnabled, exerciseEnabled].filter { $0 }.count
    }
    
    var body: some View {
        ZStack {
            if enabledCount == 0 {
                // No goals enabled - show placeholder
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Goals Set")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Enable goals in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Show rings based on what's enabled
                // Calculate ring sizes dynamically
                let sizes = calculateRingSizes(count: enabledCount)
                
                ForEach(Array(enabledRings().enumerated()), id: \.offset) { index, ring in
                    ProgressRingView(
                        progress: ring.progress,
                        color: ring.color,
                        lineWidth: 12
                    )
                    .frame(width: sizes[index], height: sizes[index])
                }
            }
        }
    }
    
    private struct RingData {
        let progress: Double
        let color: Color
    }
    
    private func enabledRings() -> [RingData] {
        var rings: [RingData] = []
        
        if stepsEnabled {
            rings.append(RingData(progress: stepsProgress, color: .green))
        }
        if pointsEnabled {
            rings.append(RingData(progress: pointsProgress, color: .blue))
        }
        if workoutEnabled {
            rings.append(RingData(progress: workoutProgress, color: .orange))
        }
        if exerciseEnabled {
            rings.append(RingData(progress: exerciseProgress, color: .purple))
        }
        
        return rings
    }
    
    private func calculateRingSizes(count: Int) -> [CGFloat] {
        switch count {
        case 1: return [200]
        case 2: return [200, 140]
        case 3: return [200, 160, 120]
        case 4: return [200, 160, 120, 80]
        default: return []
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        // All enabled
        MultiRingView(
            stepsProgress: 0.7,
            pointsProgress: 0.5,
            workoutProgress: 0.8,
            exerciseProgress: 0.3,
            stepsEnabled: true,
            pointsEnabled: true,
            workoutEnabled: true,
            exerciseEnabled: true
        )
        
        // Only 2 enabled
        MultiRingView(
            stepsProgress: 0.7,
            pointsProgress: 0.5,
            workoutProgress: 0.8,
            exerciseProgress: 0.3,
            stepsEnabled: true,
            pointsEnabled: false,
            workoutEnabled: true,
            exerciseEnabled: false
        )
        
        // None enabled
        MultiRingView(
            stepsProgress: 0.7,
            pointsProgress: 0.5,
            workoutProgress: 0.8,
            exerciseProgress: 0.3,
            stepsEnabled: false,
            pointsEnabled: false,
            workoutEnabled: false,
            exerciseEnabled: false
        )
    }
}
