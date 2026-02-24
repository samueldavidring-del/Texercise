import SwiftUI
import FamilyControls

struct AddScreenTimeView: View {
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @Environment(\.dismiss) var dismiss
    
    @State private var minutes: Int = 0
    @State private var selectedDate = Date()
    @State private var category: String = "Social Media"
    @State private var showingAppPicker = false
    
    @ObservedObject private var categoryStore = ScreenTimeCategoryStore.shared
    
    // Build category list from selection + standard categories
    private var availableCategories: [String] {
        var cats: [String] = []
        
        // Add selected Apple categories first
        for cat in categoryStore.activitySelection.categories {
            if let name = cat.localizedDisplayName {
                cats.append(name)
            }
        }
        
        // Add selected individual apps
        for app in categoryStore.activitySelection.applications {
            if let name = app.localizedDisplayName {
                cats.append(name)
            }
        }
        
        // Fall back to standard categories if nothing selected
        if cats.isEmpty {
            cats = ["Social Media", "Entertainment", "Gaming", "Productivity", "Other"]
        }
        
        return cats.sorted()
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section("App / Category") {
                    Picker("Category", selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        // Default to first available category
                        if !availableCategories.contains(category) {
                            category = availableCategories.first ?? "Other"
                        }
                    }
                    
                    if categoryStore.isTrackingEnabled {
                        Button {
                            showingAppPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                Text("Manage Tracked Apps")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(categoryStore.selectionSummary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Duration") {
                    HStack {
                        Text("Minutes")
                        Spacer()
                        TextField("Minutes", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    Stepper("Adjust: \(minutes) min", value: $minutes, in: 0...720, step: 5)
                }
                
                Section {
                    Button("Save") {
                        screenTimeStore.addEntry(
                            date: selectedDate,
                            minutes: minutes,
                            category: category
                        )
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(minutes <= 0)
                }
            }
            .navigationTitle("Log Screen Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAppPicker) {
                ScreenTimePickerView()
            }
        }
    }
}

#Preview {
    AddScreenTimeView()
        .environmentObject(ScreenTimeStore())
}
