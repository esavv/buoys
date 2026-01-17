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
    @State private var swellHeight: String = "Loading..."
    @State private var swellPeriod: String = "Loading..."
    @State private var swellDirection: String = "Loading..."
    @State private var lastUpdated: String = "Loading..."
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
                    .frame(width: 250, alignment: .trailing)
                Spacer()
                Text("\(waveHeight) ft")
                    .frame(width: 200, alignment: .leading)
            }
            
            HStack {
                Text("Swell Height:")
                    .frame(width: 250, alignment: .trailing)
                Spacer()
                Text("\(swellHeight) ft")
                    .frame(width: 200, alignment: .leading)
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
            
            HStack {
                Text("Last Updated:")
                    .frame(width: 250, alignment: .trailing)
                Spacer()
                Text("\(lastUpdated)")
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
        guard let url = APIConfig.buoyURL(for: buoyID) else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Network error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let buoyResponse = try decoder.decode(BuoyResponse.self, from: data)
                
                DispatchQueue.main.async {
                    if buoyResponse.status == "success" {
                        waveHeight = buoyResponse.sigWaveHeightFt ?? "N/A"
                        swellHeight = buoyResponse.swellHeightFt ?? "N/A"
                        swellPeriod = buoyResponse.swellPeriodS ?? "N/A"
                        swellDirection = buoyResponse.swellDirection ?? "N/A"
                        lastUpdated = buoyResponse.lastUpdated ?? "N/A"
                    } else {
                        waveHeight = "N/A"
                        swellHeight = "N/A"
                        swellPeriod = "N/A"
                        swellDirection = "N/A"
                        lastUpdated = "N/A"
                        print("API error: \(buoyResponse.errorMsg ?? "Unknown error")")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    waveHeight = "N/A"
                    swellHeight = "N/A"
                    swellPeriod = "N/A"
                    swellDirection = "N/A"
                    lastUpdated = "N/A"
                }
                print("JSON decoding error: \(error.localizedDescription)")
            }
        }.resume()
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
