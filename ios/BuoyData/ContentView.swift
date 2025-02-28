//
//  ContentView.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var waveHeight: String = "Loading..."
    @State private var swellPeriod: String = "Loading..."
    @State private var swellDirection: String = "Loading..."
    @State private var buoyID: String = "Loading..."
    @State private var newBuoyID: String = "" // For the text field input
    @State private var showDropdown = false // Controls visibility of the dropdown
    @FocusState private var isTextFieldFocused: Bool

    let availableBuoyIDs = ["44065", "44091", "SDHN4"]

    var filteredBuoyIDs: [String] {
        if newBuoyID.isEmpty {
            return availableBuoyIDs
        } else {
            return availableBuoyIDs.filter { $0.lowercased().contains(newBuoyID.lowercased()) }
        }
    }

    var body: some View {
        VStack {
            Text("Station \(buoyID) Data")
                .font(.title)
                .padding()
            HStack {
                Text("Sig. Wave Height:")
                    .frame(width: 250, alignment: .trailing) // Fixed width for right-alignment
                Spacer()
                Text("\(waveHeight) ft")
                    .frame(width: 200, alignment: .leading) // Left-aligned data
            }
            
            HStack {
                Text("Swell Period:")
                    .frame(width: 250, alignment: .trailing)
                Spacer()
                Text("\(swellPeriod) s")
                    .frame(width: 200, alignment: .leading)
            }
            
            HStack {
                Text("Swell Direction:")
                    .frame(width: 250, alignment: .trailing)
                Spacer()
                Text("\(swellDirection)")
                    .frame(width: 200, alignment: .leading)
            }
            
            Divider()
                .padding(.vertical, 20)
            
            Text("Update Buoy")
                .font(.headline)
            
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    TextField("Enter buoy ID", text: $newBuoyID, onEditingChanged: { isEditing in
                        showDropdown = isEditing
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                    .focused($isTextFieldFocused)
                    
                    if showDropdown {
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) { // Ensures no extra padding between items
                                ForEach(filteredBuoyIDs, id: \.self) { buoy in
                                    Text(buoy)
                                        .padding(.vertical, 4) // Adjusts item padding
                                        .padding(.horizontal, 4) // Adds horizontal padding, including on the left
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white)
                                        .onTapGesture {
                                            newBuoyID = buoy
                                            isTextFieldFocused = false // Resign focus
                                        }
                                }
                            }
                            .frame(width: 250) // Matches text field width
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray)) // Optional border
                        }
                        .frame(width: 250) // Ensure the dropdown matches text field width
                    }
                }
            }

            Button(action: updateFavoriteBuoy) {
                Text("Submit")
                    .frame(width: 150)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .onAppear {
            let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
            buoyID = sharedDefaults?.string(forKey: "favoriteBuoy") ?? "44065"
            fetchBuoyData(for: buoyID)
        }
    }
    
    func fetchBuoyData(for buoyID: String) {
        guard let url = URL(string: "https://www.ndbc.noaa.gov/data/realtime2/\(buoyID).spec") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Network error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let content = String(data: data, encoding: .utf8) {
                parseBuoyData(content)
            }
        }.resume()
    }
    
    func parseBuoyData(_ content: String) {
        let lines = content.split(separator: "\n")
        guard lines.count > 2 else {
            print("Unexpected file format")
            return
        }
        
        // Column headers
        let headers = lines[0].split(separator: " ", omittingEmptySubsequences: true)
        // Most recent data (third row)
        let latestData = lines[2].split(separator: " ", omittingEmptySubsequences: true)
        
        if let waveHeightIndex = headers.firstIndex(of: "WVHT"),
           let swellPeriodIndex = headers.firstIndex(of: "SwP"),
           let swellDirectionIndex = headers.firstIndex(of: "SwD") {
            DispatchQueue.main.async {
                if let waveHeightMeters = Double(latestData[waveHeightIndex]) {
                    let waveHeightFeet = waveHeightMeters * 3.28084
                    waveHeight = String(format: "%.1f", waveHeightFeet) // Format to 1 decimal place
                } else {
                    waveHeight = "N/A"
                }
                swellPeriod = String(latestData[swellPeriodIndex])
                swellDirection = String(latestData[swellDirectionIndex])
            }
        } else {
            waveHeight = "N/A"
            swellPeriod = "N/A"
            swellDirection = "N/A"
            print("Could not find required headers")
        }
    }
    
    func updateFavoriteBuoy() {
        guard !newBuoyID.isEmpty else {
            print("New buoy ID is empty")
            return
        }
        
        let sharedDefaults = UserDefaults(suiteName: "group.BuoyData")
        sharedDefaults?.set(newBuoyID, forKey: "favoriteBuoy")
        print("Favorite buoy updated to \(newBuoyID)")
        
        // Trigger widget update
        WidgetCenter.shared.reloadAllTimelines()
        
        // Update the current buoy ID and fetch new data
        buoyID = newBuoyID
        fetchBuoyData(for: buoyID)
        
        // Clear the text field
        newBuoyID = ""
    }
}

#Preview {
    ContentView()
}
