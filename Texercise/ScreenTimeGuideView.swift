import SwiftUI

struct ScreenTimeGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("How to Check Screen Time")
                        .font(.title.bold())
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            StepView(
                                number: 1,
                                title: "Open Settings",
                                description: "Go to the Settings app on your iPhone"
                            )
                            
                            Divider()
                            
                            StepView(
                                number: 2,
                                title: "Tap Screen Time",
                                description: "Scroll down and tap 'Screen Time'"
                            )
                            
                            Divider()
                            
                            StepView(
                                number: 3,
                                title: "View Today's Usage",
                                description: "See your total screen time for today at the top"
                            )
                            
                            Divider()
                            
                            StepView(
                                number: 4,
                                title: "Come Back Here",
                                description: "Remember the number and log it in Texercise"
                            )
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Text("💡 Pro Tips")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TipBox(
                            icon: "clock.fill",
                            text: "Check once per day, ideally in the evening"
                        )
                        
                        TipBox(
                            icon: "app.badge.fill",
                            text: "You can see breakdown by app category in Screen Time settings"
                        )
                        
                        TipBox(
                            icon: "chart.bar.fill",
                            text: "Log different categories separately for better insights"
                        )
                    }
                    
                    Button {
                        if let url = URL(string: "App-prefs:SCREEN_TIME") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Screen Time Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TipBox: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    ScreenTimeGuideView()
}
