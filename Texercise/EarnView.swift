import SwiftUI

struct EarnView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    
    @State private var showingExerciseOptions = false
    @State private var showingWorkoutLog = false
    @State private var showingScreenTimeLog = false
    @State private var showingScreenTimeGuide = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("Earn Points")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // MARK: Exercise and Workout Logging
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Activities")
                            .font(.headline)
                        
                        Button {
                            showingExerciseOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .frame(width: 30)
                                Text("Log Exercise")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                        
                        Button {
                            showingWorkoutLog = true
                        } label: {
                            HStack {
                                Image(systemName: "figure.run")
                                    .frame(width: 30)
                                Text("Log Workout")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)
                    
                    // MARK: Screen Time
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Screen Time")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingScreenTimeGuide = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "questionmark.circle.fill")
                                    Text("How to Check")
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                        }
                        
                        Button {
                            showingScreenTimeLog = true
                        } label: {
                            HStack {
                                Image(systemName: "iphone")
                                    .frame(width: 30)
                                Text("Log Screen Time")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)
                    
                    // MARK: Health Authorization
                    if !healthStore.isAuthorized {
                        VStack(spacing: 12) {
                            Text(healthStore.hasRequestedAuthorization ? "Health Access Needed" : "Health Access Required")
                                .font(.headline)
                            
                            if healthStore.hasRequestedAuthorization {
                                Text("Please enable Health access in Settings → Health → Data Access & Devices → Texercise")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    if let url = URL(string: "x-apple-health://") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text("Open Health Settings")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            } else {
                                Text("Grant access to Health to track steps and workouts")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    healthStore.requestAuthorization()
                                } label: {
                                    Text("Grant Access")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Earn")
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
            .sheet(isPresented: $showingScreenTimeLog) {
                ScreenTimeLogView()
            }
            .sheet(isPresented: $showingScreenTimeGuide) {
                ScreenTimeGuideView()
            }
            .sheet(isPresented: $showingExerciseOptions) {
                ExerciseOptionsView()
            }
            .sheet(isPresented: $showingWorkoutLog) {
                AddWorkoutView()
                    .environmentObject(healthStore)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(pointSettings)
            }
        }
    }
}

#Preview {
    EarnView()
        .environmentObject(ExerciseStore())
        .environmentObject(ScreenTimeStore())
        .environmentObject(HealthStore())
        .environmentObject(PointSettingsStore())
}
