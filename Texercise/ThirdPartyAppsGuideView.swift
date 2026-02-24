import SwiftUI

struct ThirdPartyAppsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("Sync Third-Party Workouts")
                        .font(.title.bold())
                    
                    Text("Texercise automatically pulls workouts from apps like Strava, Nike Run Club, Peloton, and others through Apple Health.")
                        .foregroundColor(.secondary)
                    
                    // MARK: Setup Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Setup Instructions")
                            .font(.headline)
                        
                        GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                AppSyncStep(
                                    appName: "Strava",
                                    icon: "🚴",
                                    steps: [
                                        "Open Strava app",
                                        "Go to Profile → Settings",
                                        "Tap 'Applications, Services and Devices'",
                                        "Tap 'Health' and enable 'Write Workouts'"
                                    ]
                                )
                                
                                Divider()
                                
                                AppSyncStep(
                                    appName: "Nike Run Club",
                                    icon: "👟",
                                    steps: [
                                        "Open Nike Run Club app",
                                        "Go to Profile → Settings",
                                        "Tap 'Health & Privacy'",
                                        "Enable 'Health App' toggle"
                                    ]
                                )
                                
                                Divider()
                                
                                AppSyncStep(
                                    appName: "Peloton",
                                    icon: "🏃",
                                    steps: [
                                        "Open Peloton app",
                                        "Go to More → Settings",
                                        "Tap 'Health App'",
                                        "Enable 'Connect to Health'"
                                    ]
                                )
                            }
                        }
                    }
                    
                    // MARK: Common Apps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Compatible Apps")
                            .font(.headline)
                        
                        Text("These popular fitness apps sync with Apple Health:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            AppBadge(name: "Strava", icon: "🚴")
                            AppBadge(name: "Nike Run Club", icon: "👟")
                            AppBadge(name: "Peloton", icon: "🏃")
                            AppBadge(name: "MapMyRun", icon: "🗺️")
                            AppBadge(name: "Zwift", icon: "🚴")
                            AppBadge(name: "Fitbit", icon: "⌚")
                            AppBadge(name: "Garmin", icon: "⌚")
                            AppBadge(name: "Apple Watch", icon: "⌚")
                        }
                    }
                    
                    // MARK: Troubleshooting
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Troubleshooting")
                            .font(.headline)
                        
                        TroubleshootBox(
                            title: "Workouts not showing?",
                            solutions: [
                                "Make sure Texercise has Health access enabled",
                                "Check that your fitness app has permission to write to Health",
                                "Try completing a new workout to test the sync",
                                "Restart both apps if needed"
                            ]
                        )
                    }
                    
                    // MARK: Check Health Settings
                    Button {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                            Text("Open Health App")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Third-Party Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AppSyncStep: View {
    let appName: String
    let icon: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(icon)
                    .font(.title2)
                Text(appName)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }
}

struct AppBadge: View {
    let name: String
    let icon: String
    
    var body: some View {
        HStack {
            Text(icon)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct TroubleshootBox: View {
    let title: String
    let solutions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(solutions, id: \.self) { solution in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.accentColor)
                        Text(solution)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ThirdPartyAppsGuideView()
}
