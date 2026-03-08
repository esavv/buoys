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
            .sheet(isPresented: $showingAddSheet) {
                AddBuoySheet(selectedTab: $selectedTab)
                    .presentationDetents([.fraction(0.4)])
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

struct FavoriteBuoyRow: View {
    let buoy: FavoriteBuoy
    let isWidgetBuoy: Bool

    @State private var buoyData: BuoyResponse? = nil
    @State private var isLoading = true

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
                FavoriteBuoyReadings(data: data)
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    readingLine("Wave Height", value: data.sigWaveHeightFt, unit: "ft")
                    readingLine("Swell Height", value: data.swellHeightFt, unit: "ft")
                }
                VStack(alignment: .leading, spacing: 2) {
                    readingLine("Period", value: data.swellPeriodS, unit: "s")
                    readingLine("Direction", value: data.swellDirection)
                }
            }
            if let updated = data.lastUpdated {
                Text("Updated \(updated)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func readingLine(_ label: String, value: String?, unit: String? = nil) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let value = value, value != "N/A" {
                Text(unit != nil ? "\(value) \(unit!)" : value)
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Text("N/A")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AddBuoySheet: View {
    @Environment(FavoritesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: AppTab

    @State private var buoyId = ""
    @State private var isValidating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter a Buoy ID")
                    .font(.subheadline)

                TextField("44091", text: $buoyId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(maxWidth: 240)

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Button {
                    validateAndAdd()
                } label: {
                    if isValidating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Add")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(buoyId.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                .frame(maxWidth: 240)

                Text("or")
                    .font(.subheadline)

                Button {
                    dismiss()
                    selectedTab = .map
                } label: {
                    Text("Select From Map")
                        .font(.subheadline)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Add Buoy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func validateAndAdd() {
        let trimmedId = buoyId.trimmingCharacters(in: .whitespaces)
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
                        dismiss()
                    } else {
                        errorMessage = "Station not found. Check the ID and try again."
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
