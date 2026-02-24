import SwiftUI
import SafariServices

struct StravaConnectionView: View {
    @StateObject private var stravaAPI = StravaAPI()
    @EnvironmentObject var healthStore: HealthStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var isImporting = false
    @State private var importedCount = 0
    @State private var healthKitImportedCount = 0
    @State private var showingActivities = false
    @State private var activities: [StravaActivity] = []
    @State private var showingManualEntry = false
    
    var body: some View {
        NavigationView {
            List {
                if stravaAPI.isAuthenticated {
                    // MARK: Connected
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Connected to Strava")
                                    .font(.headline)
                                if !stravaAPI.athleteName.isEmpty {
                                    Text(stravaAPI.athleteName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Section("Import Workouts") {
                        Button {
                            Task {
                                await importActivities()
                            }
                        } label: {
                            HStack {
                                if isImporting {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isImporting ? "Importing..." : "Import to Health")
                            }
                        }
                        .disabled(isImporting)
                        
                        if importedCount > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Found \(importedCount) Strava activities")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                if healthKitImportedCount > 0 {
                                    Text("Imported \(healthKitImportedCount) workouts to Health")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button("View Activities") {
                            showingActivities = true
                        }
                        
                        Button("Disconnect", role: .destructive) {
                            stravaAPI.disconnect()
                        }
                    }
                    
                } else {
                    // MARK: Not Connected
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "figure.run")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading) {
                                    Text("Strava")
                                        .font(.title2.bold())
                                    Text("Import your workouts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text("Connect your Strava account to automatically import all your past and future workouts.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section("What Gets Imported") {
                        Label("Running workouts", systemImage: "figure.run")
                        Label("Cycling activities", systemImage: "bicycle")
                        Label("Swimming sessions", systemImage: "figure.pool.swim")
                        Label("Other sports", systemImage: "sportscourt")
                    }
                    
                    Section {
                        Button {
                            showingManualEntry = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Connect to Strava")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Strava Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingActivities) {
                StravaActivitiesListView(activities: activities)
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualAuthView(stravaAPI: stravaAPI)
            }
        }
    }
    
    private func importActivities() async {
        isImporting = true
        healthKitImportedCount = 0
        
        print("🔄 Starting import process...")
        
        // Fetch last 6 months of activities
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())
        activities = await stravaAPI.fetchActivities(after: sixMonthsAgo)
        importedCount = activities.count
        
        print("📥 Fetched \(importedCount) activities from Strava")
        
        // Import to HealthKit
        if !activities.isEmpty {
            do {
                healthKitImportedCount = try await stravaAPI.importActivitiesToHealthKit(activities)
                
                print("✅ Imported \(healthKitImportedCount) workouts to HealthKit")
                print("⏳ Waiting 2 seconds for HealthKit to process...")
                
                // Wait for HealthKit to process the workouts
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                print("🔄 Refreshing workout list...")
                
                // Refresh HealthKit data on main thread
                await MainActor.run {
                    healthStore.loadRecentWorkouts()
                }
                
                // Wait a bit more for the query to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    print("📊 Current workout count in app: \(healthStore.recentWorkouts.count)")
                    print("📊 Workouts today: \(healthStore.workouts(on: Date()).count)")
                }
                
            } catch {
                print("❌ Import failed: \(error)")
            }
        }
        
        isImporting = false
    }
}

struct ManualAuthView: View {
    @ObservedObject var stravaAPI: StravaAPI
    @Environment(\.dismiss) private var dismiss
    
    @State private var authorizationCode = ""
    @State private var isAuthenticating = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Step 1: Open Strava Authorization")
                            .font(.headline)
                        
                        Text("Tap the button below to open Strava in Safari. After you authorize, you'll see a page that can't load - that's normal!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            if let url = stravaAPI.getManualAuthorizationURL() {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "safari")
                                Text("Open Strava")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Step 2: Copy the Code")
                            .font(.headline)
                        
                        Text("After authorizing, look at the URL in Safari. It will look like:\nhttp://localhost/?code=ABC123...\n\nCopy everything after 'code='")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Step 3: Paste Code Below")
                            .font(.headline)
                        
                        TextField("Paste authorization code here", text: $authorizationCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button {
                            connectWithCode()
                        } label: {
                            HStack {
                                if isAuthenticating {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isAuthenticating ? "Connecting..." : "Connect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(authorizationCode.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(authorizationCode.isEmpty || isAuthenticating)
                    }
                }
            }
            .navigationTitle("Connect Strava")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func connectWithCode() {
        isAuthenticating = true
        errorMessage = ""
        
        let code = authorizationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await stravaAPI.handleAuthCallback(code: code)
                await MainActor.run {
                    isAuthenticating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    errorMessage = "Failed to connect. Make sure you copied the entire code."
                }
            }
        }
    }
}

struct StravaActivitiesListView: View {
    let activities: [StravaActivity]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(activities) { activity in
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.name)
                        .font(.headline)
                    
                    HStack {
                        Text(activity.type)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(String(format: "%.2f mi", activity.distanceMiles))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(activity.durationMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(activity.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Strava Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
