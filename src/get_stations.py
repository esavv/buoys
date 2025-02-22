import csv, requests, sys, time
import xml.etree.ElementTree as ET

# URL of the NOAA active stations list
URL = "https://www.ndbc.noaa.gov/activestations.xml"

# Fetch the data
print('  Fetching the station list...')
response = requests.get(URL)
response.raise_for_status()

# Parse the XML
print('  Parsing XML...')
tree = ET.ElementTree(ET.fromstring(response.content))
root = tree.getroot()

csv_filename = "../data/stations.csv"
with open(csv_filename, mode="w", newline="") as file:
    writer = csv.writer(file)
    writer.writerow(["id", "name", "lat", "lon"])
    
    # Iterate through each station
    for idx, station in enumerate(root.findall("station")):
        sys.stdout.write(f"\r  Writing station {idx+1}...")
        sys.stdout.flush()
        time.sleep(0.0005)
        station_id = station.get("id")
        name = station.get("name")
        lat = station.get("lat")
        lon = station.get("lon")
        
        writer.writerow([station_id, name, lat, lon])
    print()
