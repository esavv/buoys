//
//  FavoritesView.swift
//  BuoyData
//
//  Created by Erik Savage on 3/7/26.
//

import SwiftUI
import UIKit

private extension Color {
    static let favoriteScreenBackground = Color("FavoriteScreenBackground")
    static let favoriteCardSurface = Color("FavoriteCardSurface")
}

struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var store
    @Binding var selectedTab: AppTab
    @State private var showingAddSheet = false
    @State private var editMode: EditMode = .inactive

    private let addBuoyComposerAnimation = Animation.spring(response: 0.36, dampingFraction: 0.86)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.favoriteScreenBackground
                    .ignoresSafeArea()

                Group {
                    if store.favorites.isEmpty {
                        VStack {
                            Spacer()
                            if !showingAddSheet {
                                addButton
                                    .padding(.horizontal)
                            }
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

                            if editMode == .inactive && !showingAddSheet {
                                addButton
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }

                if showingAddSheet {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissAddComposer()
                        }

                    AddBuoySheet(
                        selectedTab: $selectedTab,
                        onDismiss: dismissAddComposer
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
            withAnimation(addBuoyComposerAnimation) {
                showingAddSheet = true
            }
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

    private func dismissAddComposer() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        withAnimation(addBuoyComposerAnimation) {
            showingAddSheet = false
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
        .background(Color.favoriteCardSurface)
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
    @State private var isBuoyIdFocused = false
    @State private var errorShakeTrigger: CGFloat = 0

    private var trimmedBuoyId: String {
        buoyId.trimmingCharacters(in: .whitespaces)
    }

    private var canSubmit: Bool {
        !trimmedBuoyId.isEmpty && !isValidating
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                }

                BuoyIdTextField(
                    placeholder: "Enter a buoy ID (e.g. 44091)",
                    text: $buoyId,
                    isFocused: $isBuoyIdFocused,
                    onSubmit: submitIfPossible
                )
                    .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                    .modifier(ShakeEffect(trigger: errorShakeTrigger))
                    .padding(.horizontal, 14)
                    .padding(.top, errorMessage == nil ? 14 : 0)

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
                        submitIfPossible()
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
                    .background {
                        ZStack {
                            Capsule()
                                .fill(Color(.systemGray4))
                                .opacity(canSubmit ? 0 : 1)
                            Capsule()
                                .fill(Color(red: 0.13, green: 0.31, blue: 0.58))
                                .opacity(canSubmit ? 1 : 0)
                        }
                    }
                    .clipShape(Capsule())
                    .disabled(!canSubmit)
                    .animation(.easeInOut(duration: 0.12), value: canSubmit)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            isBuoyIdFocused = true
        }
        .onChange(of: isBuoyIdFocused) {
            if !isBuoyIdFocused && isValidating {
                isBuoyIdFocused = true
            }
        }
        .onChange(of: buoyId) {
            if buoyId.isEmpty {
                errorMessage = nil
            }
        }
    }

    private func submitIfPossible() {
        isBuoyIdFocused = true

        if canSubmit {
            validateAndAdd()
        }
    }

    private func validateAndAdd() {
        let trimmedId = trimmedBuoyId
        errorMessage = nil
        isBuoyIdFocused = true

        if store.contains(trimmedId) {
            showError("Buoy already in favorites!")
            return
        }

        isValidating = true

        guard let url = APIConfig.buoyURL(for: trimmedId) else {
            showError("Invalid buoy ID.")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    showError("Could not reach the server. Try again.")
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
                        showError("Buoy not found!")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    showError("Something went wrong. Try again.")
                }
            }
        }.resume()
    }

    private func showError(_ message: String) {
        errorMessage = message
        isValidating = false
        isBuoyIdFocused = true

        withAnimation(.linear(duration: 0.35)) {
            errorShakeTrigger += 1
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var trigger: CGFloat
    var travelDistance: CGFloat = 5
    var shakesPerTrigger: CGFloat = 3

    var animatableData: CGFloat {
        get { trigger }
        set { trigger = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travelDistance * sin(trigger * .pi * shakesPerTrigger * 2),
                y: 0
            )
        )
    }
}

private struct BuoyIdTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.placeholder = placeholder
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .go
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self

        if textField.text != text {
            textField.text = text
        }

        if isFocused && !textField.isFirstResponder {
            DispatchQueue.main.async {
                if context.coordinator.parent.isFocused {
                    textField.becomeFirstResponder()
                }
            }
        } else if !isFocused && textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BuoyIdTextField

        init(parent: BuoyIdTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
        }
    }
}

#Preview {
    FavoritesView(selectedTab: .constant(.favorites))
        .environment(FavoritesStore())
}
