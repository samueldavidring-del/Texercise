import SwiftUI

struct ScreenTimeLogView: View {
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int = 30
    @State private var category: String = "Social Media"

    private let categories = [
        "Social Media",
        "Entertainment",
        "Gaming",
        "Productivity",
        "Other"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Screen Time") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat)
                        }
                    }

                    Stepper("Minutes: \(minutes)", value: $minutes, in: 1...300, step: 5)
                }

                Section {
                    Button("Log Screen Time") {
                        screenTimeStore.addManualEntry(minutes: minutes, categoryLabel: category)
                        dismiss()
                    }
                    .disabled(minutes == 0)
                }
            }
            .navigationTitle("Log Screen Time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ScreenTimeLogView()
        .environmentObject(ScreenTimeStore())
}
