//
//  SearchView.swift
//  BuoyData
//
//  Created by Erik Savage on 1/6/25.
//

import SwiftUI
import WidgetKit

struct SearchView: View {
    @State private var waveHeight: String = "Loading..."
    @State private var swellHeight: String = "Loading..."
    @State private var swellPeriod: String = "Loading..."
    @State private var swellDirection: String = "Loading..."
    @State private var lastUpdated: String = "Loading..."
    @State private var buoyID: String = "Loading..."
    @State private var newBuoyID: String = ""

    var body: some View {
        VStack {
            Text("Station \(buoyID)")
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
            
            Text("Update Buoy")
                .padding(.top, 20)
                .font(.headline)
            
            TextField("Enter buoy ID", text: $newBuoyID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
                .padding(.top, 0)

            Button(action: updateFavoriteBuoy) {
                Text("Submit")
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
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
        
        WidgetCenter.shared.reloadAllTimelines()
        
        buoyID = newBuoyID
        fetchBuoyData(for: buoyID)
        
        newBuoyID = ""
    }
}

#Preview {
    SearchView()
}
