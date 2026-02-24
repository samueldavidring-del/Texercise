import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    
    @Binding var showingSettings: Bool
    
    @State private var errorMessage: String?
    
    private var last30Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }
    
    private func pointsForDate(_ date: Date) -> DailyPoints {
        return PointsStore.pointsForDay(
            date: date,
            healthStore: healthStore,
            exerciseStore: exerciseStore,
            screenTimeStore: screenTimeStore,
            settings: pointSettings.settings
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("History")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Error Loading Data")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                    
                    // MARK: Weekly Charts
                    WeeklyChartsView()
                        .environmentObject(screenTimeStore)
                        .environmentObject(exerciseStore)
                        .environmentObject(healthStore)
                        .onAppear {
                            print("📊 WeeklyChartsView appeared")
                        }
                    
                    // MARK: Daily History
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Days")
                            .font(.headline)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(last30Days, id: \.self) { date in
                                NavigationLink {
                                    DayDetailView(date: date)
                                        .environmentObject(healthStore)
                                        .environmentObject(exerciseStore)
                                        .environmentObject(screenTimeStore)
                                        .environmentObject(pointSettings)
                                } label: {
                                    DayRowView(date: date, points: pointsForDate(date))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }
}

struct DayRowView: View {
    let date: Date
    let points: DailyPoints
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: date))
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Text("+\(points.earned)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("-\(points.screen)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Text("\(points.net)")
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(points.net >= 0 ? .green : .red)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    MainTabView()
}
