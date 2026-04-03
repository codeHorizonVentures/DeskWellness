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
    
    @Binding var showJournal: Bool // To control navigation from ContentView if needed
    
    var body: some View {
        NavigationView {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Entries Yet",
                        systemImage: "notebook",
                        description: Text("Complete a check-in or reset to start tracking your routine.")
                    )
                } else {
                    // Contribution Graph Header
                    ContributionGraphView(entries: entries)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                    
                    ForEach(entries) { entry in
                        NavigationLink(destination: EntryDetailView(entry: entry)) {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationTitle("Reset Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddEntryView()) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { showJournal = false }
                }
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let entry = entries[index]
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
        HStack {
            Image(systemName: entry.iconName)
                .foregroundColor(entry.color)
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.type == .scan ? "Check-In" : "Reset Log")
                    .font(.headline)
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if entry.cvaScore != nil {
                Text("\(Int(entry.cvaScore!))")
                    .font(.headline.bold())
                    .foregroundColor(entry.color)
            }
            
            if entry.exercisesCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
            
            if entry.photoPath != nil || entry.frontPhotoPath != nil {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EntryDetailView: View {
    @Bindable var entry: DailyEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: entry.iconName)
                        .font(.title)
                        .foregroundColor(entry.color)
                    Text(entry.type == .scan ? "Check-In" : "Reset Log")
                        .font(.largeTitle.bold())
                    Spacer()
                    Text(entry.formattedDate)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                // Photo
                // Photos
                // Photos & Schema
                if entry.photoPath != nil || entry.frontPhotoPath != nil || entry.frontPointsData != nil || entry.sidePointsData != nil {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Visuals")
                                .font(.headline)
                            Spacer()
                            // Delete Photos Action
                            if entry.photoPath != nil || entry.frontPhotoPath != nil {
                                Button(role: .destructive) {
                                    deletePhotos(for: entry)
                                } label: {
                                    Label("Clear Photos (Keep Data)", systemImage: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                // Front Profile
                                if let frontPath = entry.frontPhotoPath, let img = loadImage(from: frontPath) {
                                    VStack {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 300)
                                            .cornerRadius(12)
                                        Text("Front")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let data = entry.frontPointsData, let points = try? JSONDecoder().decode(FrontPosePoints.self, from: data) {
                                    // Schema Fallback
                                    VStack {
                                        PoseSchemaView(mode: .front, frontPoints: points, sidePoints: nil)
                                            .frame(width: 200, height: 300)
                                            .background(Color.black.opacity(0.8))
                                            .cornerRadius(12)
                                        Text("Front Schema")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Side Profile
                                if let sidePath = entry.photoPath, let img = loadImage(from: sidePath) {
                                    VStack {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 300)
                                            .cornerRadius(12)
                                        Text("Side")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let data = entry.sidePointsData, let points = try? JSONDecoder().decode(SidePosePoints.self, from: data) {
                                    // Schema Fallback
                                    VStack {
                                        PoseSchemaView(mode: .side, frontPoints: nil, sidePoints: points)
                                            .frame(width: 200, height: 300)
                                            .background(Color.black.opacity(0.8))
                                            .cornerRadius(12)
                                        Text("Side Schema")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Exercise Status
                Toggle("Reset Completed", isOn: $entry.exercisesCompleted)
                    .padding(.vertical)
                
                // Stats
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
                
                // Note
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
// MARK: - Contribution Graph

struct ContributionGraphView: View {
    let entries: [DailyEntry]
    
    // Config
    private let daysToDisplay = 91 // ~3 months
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 13) // ~13 weeks
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consistency")
                .font(.headline)
                .padding(.horizontal)
            
            // Heatmap Grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<daysToDisplay, id: \.self) { offset in
                    // Calculate date (reverse chronological order for display? No, typically left-right, top-down)
                    // But GitHub is columns = weeks. 
                    // Simpler: Just a grid of the last N days.
                    
                    let date = Calendar.current.date(byAdding: .day, value: -((daysToDisplay - 1) - offset), to: Date())!
                    let hasEntry = hasEntry(on: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hasEntry ? Color.green : Color.gray.opacity(0.2))
                        .frame(height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.primary.opacity(0.5), lineWidth: isToday ? 1 : 0)
                        )
                }
            }
            .padding(.horizontal)
            
            // Footer Legend
            HStack {
                Text("Last 3 Months")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func hasEntry(on date: Date) -> Bool {
        return entries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
