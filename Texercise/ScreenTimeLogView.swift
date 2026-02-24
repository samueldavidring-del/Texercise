import SwiftUI

struct ScreenTimeLogView: View {
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @Environment(\.dismiss) var dismiss
    
    @State private var minutes: Int = 0
    @State private var selectedDate = Date()
    @State private var category: String = "Social Media"
    
    let categories = [
        "Social Media",
        "Entertainment",
        "Gaming",
        "Productivity",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScreenTimeLogView()
        .environmentObject(ScreenTimeStore())
}
