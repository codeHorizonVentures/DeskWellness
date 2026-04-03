//
//  JournalView.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 07.02.2026.
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    let previewEntries: [DailyEntry]?
    @Binding var showJournal: Bool // To control navigation from ContentView if needed

    init(showJournal: Binding<Bool>, previewEntries: [DailyEntry]? = nil) {
        self._showJournal = showJournal
        self.previewEntries = previewEntries
    }

    private var displayEntries: [DailyEntry] {
        previewEntries ?? entries
    }

    private var isPreviewing: Bool {
        previewEntries != nil
    }
    
    var body: some View {
        NavigationView {
            List {
                if displayEntries.isEmpty {
                    ContentUnavailableView(
                        "No Entries Yet",
                        systemImage: "notebook",
                        description: Text("Complete a check-in or reset to start tracking your routine.")
                    )
                } else {
                    JournalSummaryCard(entries: displayEntries)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)

                    if isPreviewing {
                        ForEach(displayEntries) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                EntryRow(entry: entry)
                            }
                        }
                    } else {
                        ForEach(displayEntries) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                EntryRow(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .accessibilityIdentifier("journal_screen")
            .navigationTitle("Reset Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { showJournal = false }
                }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let entry = displayEntries[index]
                let fileManager = FileManager.default
                let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                if let path = entry.photoPath {
                    try? fileManager.removeItem(at: documents.appendingPathComponent(path))
                }
                
                if let path = entry.frontPhotoPath {
                    try? fileManager.removeItem(at: documents.appendingPathComponent(path))
                }
                
                modelContext.delete(entry)
            }
        }
    }
}

struct EntryRow: View {
    let entry: DailyEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.iconName)
                .foregroundColor(entry.color)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(entry.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.journalTitle)
                    .font(.headline)

                Text(entry.journalStatusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if entry.hasAnyVisualData {
                        JournalTag(label: "Saved visuals", color: .blue)
                    }
                }

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            JournalTag(
                label: entry.exercisesCompleted ? "Done" : (entry.type == .scan ? "Check-In" : "Logged"),
                color: entry.exercisesCompleted ? .green : entry.color
            )
        }
        .padding(.vertical, 6)
    }
}

struct EntryDetailView: View {
    @Bindable var entry: DailyEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: entry.iconName)
                            .font(.title2)
                            .foregroundColor(entry.color)
                            .frame(width: 44, height: 44)
                            .background(entry.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.journalTitle)
                                .font(.title2.bold())
                            Text(entry.formattedDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    Text(entry.journalStatusText)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Session")
                        .font(.headline)

                    Toggle("Reset Completed", isOn: $entry.exercisesCompleted)

                    if entry.hasSavedImages {
                        Label("Saved photos stay on device only.", systemImage: "photo.on.rectangle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if entry.hasPoseData {
                        Label("Check-in data was saved locally without photos.", systemImage: "waveform.path.ecg")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)

                if let score = entry.cvaScore {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Side Check")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundColor(.gray)
                            Text("\(Int(score))")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(entry.color)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }

                if entry.hasSavedImages {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Saved Visuals")
                                .font(.headline)

                            Spacer()

                            Button(role: .destructive) {
                                deletePhotos(for: entry)
                            } label: {
                                Label("Clear Photos", systemImage: "trash")
                                    .font(.caption)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                if let frontPath = entry.frontPhotoPath, let img = loadImage(from: frontPath) {
                                    VStack {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 220)
                                            .cornerRadius(12)
                                        Text("Front")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if let sidePath = entry.photoPath, let img = loadImage(from: sidePath) {
                                    VStack {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 220)
                                            .cornerRadius(12)
                                        Text("Side")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let note = entry.note, !note.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.headline)
                        Text(note)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadImage(from path: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
        return UIImage(contentsOfFile: url.path)
    }
    
    private func deletePhotos(for entry: DailyEntry) {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let path = entry.photoPath {
            try? fileManager.removeItem(at: documents.appendingPathComponent(path))
            entry.photoPath = nil
        }
        
        if let path = entry.frontPhotoPath {
            try? fileManager.removeItem(at: documents.appendingPathComponent(path))
            entry.frontPhotoPath = nil
        }
    }
}

struct JournalSummaryCard: View {
    let entries: [DailyEntry]

    private var consistencySummary: ResetConsistencySummary {
        ResetConsistencySummary.build(from: entries.map(\.resetConsistencyEntry))
    }

    private var totalResets: Int {
        entries.filter { $0.type == .workout }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This Week")
                .font(.headline)

            Text(consistencySummary.headline)
                .font(.title3.bold())

            Text(consistencySummary.supportingText)
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: consistencySummary.progressFraction)
                .tint(.green)

            HStack(spacing: 12) {
                SummaryMetricCard(
                    label: "Completed",
                    value: "\(consistencySummary.completedResets)",
                    tint: .green
                )
                SummaryMetricCard(
                    label: "Active Days",
                    value: "\(consistencySummary.activeDays)",
                    tint: .orange
                )
                SummaryMetricCard(
                    label: "Check-Ins",
                    value: "\(consistencySummary.checkIns)",
                    tint: .blue
                )
            }

            Text("All-time reset logs: \(totalResets)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct SummaryMetricCard: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12))
        .cornerRadius(12)
    }
}

struct JournalTag: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var note = ""
    @State private var type: EntryType = .workout
    @State private var exercisesCompleted = false
    
    var body: some View {
        Form {
            Section(header: Text("Type")) {
                Picker("Type", selection: $type) {
                    Text("Reset").tag(EntryType.workout)
                    Text("Check-In (Manual)").tag(EntryType.scan)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Details")) {
                TextField("Notes (e.g., neck reset after a long meeting)", text: $note)
                Toggle("Reset Completed", isOn: $exercisesCompleted)
            }
        }
        .navigationTitle("New Entry")
        .toolbar {
            Button("Save") {
                let entry = DailyEntry(type: type, note: note, exercisesCompleted: exercisesCompleted)
                modelContext.insert(entry)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Schema View

struct PoseSchemaView: View {
    let mode: DetectionMode
    let frontPoints: FrontPosePoints?
    let sidePoints: SidePosePoints?
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack {
                if mode == .front, let p = frontPoints {
                    Path { path in
                        let l = CGPoint(x: p.leftShoulder.x * width, y: (1 - p.leftShoulder.y) * height)
                        let r = CGPoint(x: p.rightShoulder.x * width, y: (1 - p.rightShoulder.y) * height)
                        let n = CGPoint(x: p.nose.x * width, y: (1 - p.nose.y) * height)
                        let mid = CGPoint(x: (l.x + r.x)/2, y: (l.y + r.y)/2)
                        
                        // Shoulders
                        path.move(to: l)
                        path.addLine(to: r)
                        
                        // Neck
                        path.move(to: mid)
                        path.addLine(to: n)
                    }
                    .stroke(Color.green, lineWidth: 3)
                }
                
                if mode == .side, let p = sidePoints {
                     Path { path in
                         let ear = CGPoint(x: p.ear.x * width, y: (1 - p.ear.y) * height)
                         let neck = CGPoint(x: p.neck.x * width, y: (1 - p.neck.y) * height)
                         
                         path.move(to: ear)
                         path.addLine(to: neck)
                         
                         // Horizontal
                         path.move(to: neck)
                         path.addLine(to: CGPoint(x: width, y: neck.y))
                     }
                     .stroke(Color.green, style: StrokeStyle(lineWidth: 3, dash: [5]))
                }
            }
        }
    }
}
