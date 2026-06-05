//
//  FavoritesView.swift
//  BuoyData
//
//  Created by Erik Savage on 3/7/26.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var store
    @Binding var selectedTab: AppTab
    @State private var showingAddSheet = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if store.favorites.isEmpty {
                        VStack {
                            Spacer()
                            addButton
                                .padding(.horizontal)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(Array(store.favorites.enumerated()), id: \.element.id) { index, buoy in
                                FavoriteBuoyRow(buoy: buoy, isWidgetBuoy: index == 0)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onDelete { store.remove(at: $0) }
                            .onMove { store.move(from: $0, to: $1) }

                            if editMode == .inactive {
                                addButton
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                    }
                }

                if showingAddSheet {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingAddSheet = false
                        }

                    AddBuoySheet(
                        selectedTab: $selectedTab,
                        onDismiss: { showingAddSheet = false }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.favorites.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        } label: {
                            if editMode == .active {
                                Text("Done").fontWeight(.semibold)
                            } else {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .onDisappear {
                editMode = .inactive
            }
            .onChange(of: store.favorites.isEmpty) {
                if store.favorites.isEmpty {
                    Task { @MainActor in
                        editMode = .inactive
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.headline)
                Text("Add Buoy")
                    .font(.headline)
            }
            .foregroundStyle(Color(.systemGray))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

struct FavoriteBuoyRow: View {
    let buoy: FavoriteBuoy
    let isWidgetBuoy: Bool
    @Environment(\.editMode) private var editMode

    @State private var buoyData: BuoyResponse? = nil
    @State private var isLoading = true
    
    private var isEditing: Bool {
        editMode?.wrappedValue == .active
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let name = buoyData?.name {
                        Text(name)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text("Station \(buoy.id)")
                        .font(buoyData?.name != nil ? .subheadline : .headline)
                        .foregroundStyle(buoyData?.name != nil ? .secondary : .primary)
                }
                Spacer()
                if isWidgetBuoy {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                }
            }

            if isLoading {
                ProgressView()
                    .padding(.vertical, 4)
            } else if let data = buoyData, data.status == "success" {
                FavoriteBuoyReadings(data: data, isEditing: isEditing)
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .onAppear {
            fetchData()
        }
    }

    private func fetchData() {
        guard let url = APIConfig.buoyURL(for: buoy.id) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(BuoyResponse.self, from: data)
                DispatchQueue.main.async {
                    buoyData = decoded
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async { isLoading = false }
            }
        }.resume()
    }
}

struct FavoriteBuoyReadings: View {
    let data: BuoyResponse
    var isEditing: Bool = false

    private var showValues: Bool { data.isRecent }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: isEditing ? 5 : 20) {
                Grid(alignment: .leading, horizontalSpacing: isEditing ? 3 : 6, verticalSpacing: 2) {
                    GridRow {
                        readingLabel("Wave Height:")
                        readingValue(showValues ? data.sigWaveHeightFt : nil, unit: "ft")
                    }
                    GridRow {
                        readingLabel("Swell Height:")
                        readingValue(showValues ? data.swellHeightFt : nil, unit: "ft")
                    }
                    GridRow {
                        readingLabel("Water Temp:")
                        readingValue(showValues ? data.waterTempFDisplay : nil, unit: "°F")
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: isEditing ? 3 : 6, verticalSpacing: 2) {
                    GridRow {
                        readingLabel("Swell Period:")
                        readingValue(showValues ? data.swellPeriodS : nil, unit: "s")
                    }
                    GridRow {
                        readingLabel("Swell Direction:")
                        readingValue(showValues ? data.swellDirection : nil)
                    }
                    GridRow {
                        readingLabel("Wave Direction:")
                        readingValue(showValues ? data.meanWaveDirectionDeg.flatMap { $0 != "N/A" ? "\($0)°" : nil } : nil)
                    }
                }
            }
            if let staleText = data.staleDisplayString {
                Text(staleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let updated = data.lastUpdated {
                Text("Updated \(updated)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func readingLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    @ViewBuilder
    private func readingValue(_ value: String?, unit: String? = nil) -> some View {
        if let value = value, value != "N/A" {
            Text(unit != nil ? "\(value) \(unit!)" : value)
                .font(.caption)
                .fontWeight(.medium)
        } else {
            Text("N/A")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct AddBuoySheet: View {
    @Environment(FavoritesStore.self) private var store
    @Binding var selectedTab: AppTab
    let onDismiss: () -> Void

    @State private var buoyId = ""
    @State private var isValidating = false
    @State private var errorMessage: String? = nil
    @FocusState private var isBuoyIdFocused: Bool

    private var trimmedBuoyId: String {
        buoyId.trimmingCharacters(in: .whitespaces)
    }

    private var canSubmit: Bool {
        !trimmedBuoyId.isEmpty && !isValidating
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Enter a buoy ID (e.g. 44091)", text: $buoyId)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .focused($isBuoyIdFocused)
                    .onSubmit {
                        if canSubmit {
                            validateAndAdd()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                }

                HStack(spacing: 10) {
                    Button {
                        onDismiss()
                        selectedTab = .map
                    } label: {
                        Text("Find on Map")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 16)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        validateAndAdd()
                    } label: {
                        if isValidating {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 34, height: 18)
                        } else {
                            Text("Add")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34)
                        }
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 14)
                    .background(canSubmit ? Color(red: 0.13, green: 0.31, blue: 0.58) : Color(.systemGray4))
                    .clipShape(Capsule())
                    .disabled(!canSubmit)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18))
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            isBuoyIdFocused = true
        }
    }

    private func validateAndAdd() {
        let trimmedId = trimmedBuoyId
        errorMessage = nil

        if store.contains(trimmedId) {
            errorMessage = "This station is already in your favorites."
            return
        }

        isValidating = true

        guard let url = APIConfig.buoyURL(for: trimmedId) else {
            errorMessage = "Invalid buoy ID."
            isValidating = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    errorMessage = "Could not reach the server. Try again."
                    isValidating = false
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(BuoyResponse.self, from: data)
                DispatchQueue.main.async {
                    if decoded.status == "success" {
                        store.add(trimmedId)
                        onDismiss()
                    } else {
                        errorMessage = "Buoy not found. Check the ID and try again."
                        isValidating = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Something went wrong. Try again."
                    isValidating = false
                }
            }
        }.resume()
    }
}

#Preview {
    FavoritesView(selectedTab: .constant(.favorites))
        .environment(FavoritesStore())
}
