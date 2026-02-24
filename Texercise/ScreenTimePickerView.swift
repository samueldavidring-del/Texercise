import SwiftUI
import FamilyControls

struct ScreenTimePickerView: View {
    
    @ObservedObject var categoryStore = ScreenTimeCategoryStore.shared
    @StateObject var familyControlsManager = FamilyControlsManager.shared
    
    @State private var showingPicker = false
    @State private var showingAuthAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Track Screen Time", isOn: $categoryStore.isTrackingEnabled)
                        .tint(.blue)
                } footer: {
                    Text("When enabled, time spent in selected apps and categories will count against your daily points.")
                }
                
                if categoryStore.isTrackingEnabled {
                    Section {
                        if familyControlsManager.isAuthorized {
                            // Show current selection summary
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tracked Apps & Categories")
                                        .font(.headline)
                                    Text(categoryStore.selectionSummary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Change") {
                                    showingPicker = true
                                }
                                .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        } else {
                            // Not authorized yet
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Screen Time Access Required")
                                    .font(.headline)
                                Text("Texercise needs permission to see your installed apps and categories.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    Task {
                                        await familyControlsManager.requestAuthorization()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "lock.shield.fill")
                                        Text("Grant Access")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical, 4)
                            
                            if let error = familyControlsManager.authorizationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } header: {
                        Text("Apps & Categories")
                    } footer: {
                        Text("Select which apps and categories count against your screen time points.")
                    }
                    
                    // Show selected apps/categories list if any
                    if familyControlsManager.isAuthorized && categoryStore.hasSelection {
                        Section("Currently Tracking") {
                            if !categoryStore.activitySelection.categories.isEmpty {
                                ForEach(Array(categoryStore.activitySelection.categories), id: \.self) { category in
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue)
                                        Text(category.localizedDisplayName ?? "Unknown Category")
                                    }
                                }
                            }
                            
                            if !categoryStore.activitySelection.applications.isEmpty {
                                ForEach(Array(categoryStore.activitySelection.applications), id: \.self) { app in
                                    HStack {
                                        Image(systemName: "app.fill")
                                            .foregroundColor(.purple)
                                        Text(app.localizedDisplayName ?? "Unknown App")
                                    }
                                }
                            }
                        }
                        
                        Section {
                            Button("Clear All Selections") {
                                categoryStore.activitySelection = FamilyActivitySelection()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Screen Time Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .familyActivityPicker(
                isPresented: $showingPicker,
                selection: $categoryStore.activitySelection
            )
            .onAppear {
                familyControlsManager.checkAuthorization()
            }
        }
    }
}

#Preview {
    ScreenTimePickerView()
}
