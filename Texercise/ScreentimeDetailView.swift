import SwiftUI

struct ScreenTimeDetailView: View {
    let entry: ScreenTimeEntry
    let penaltyPoints: Int
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.minutes) minute\(entry.minutes == 1 ? "" : "s")")
                                .font(.title2.bold())
                            Text("-\(penaltyPoints) point\(penaltyPoints == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Details") {
                    if let date = entry.timestamp ?? entry.date {
                        LabeledContent("Logged at", value: timeFormatter.string(from: date))
                    }
                    if let category = entry.category, !category.isEmpty {
                        LabeledContent("Category", value: category)
                    }
                    LabeledContent("Source", value: entry.category == "Auto-tracked" ? "Automatically tracked" : "Manually logged")
                    if let notes = entry.notes, !notes.isEmpty {
                        LabeledContent("Notes", value: notes)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Entry")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Screen Time Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete this screen time entry?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
