The goal of this project is to build an iPhone widget for the lock screen that displays real-time buoy data most relevant to surf forecasting, namely swell height, period, and direction.

Resources:
* The station page for my favorite NOAA buoy, 44065: https://www.ndbc.noaa.gov/station_page.php?station=44065
* The NOAA NDBC's Web Date Guide: https://www.ndbc.noaa.gov/docs/ndbc_web_data_guide.pdf
* NDBC's directory of realtime data: https://www.ndbc.noaa.gov/data/realtime2/
* 44065 Standard Meteorological Data: https://www.ndbc.noaa.gov/data/realtime2/44065.txt
* 44065 Spectral Wave Summary Data: https://www.ndbc.noaa.gov/data/realtime2/44065.spec

When building & running an iOS lock screen widget onto your phone from XCode, if you run into build errors, ensure the following in Product > Scheme > Edit Scheme (for BuoyDataWidgetExtension, not BuoyData):
* Add this Environment Variable: key: `_XCWidgetKind`, value: `BuoyDataWidget`
* In WidgetKit Environment ensure attribute Family is set to `accessoryRectangular` (or whichever lock screen accessory family you're using)