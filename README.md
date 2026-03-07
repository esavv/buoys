# BuoyData

BuoyData is an iOS lock screen widget that displays real-time NOAA buoy data for surf forecasting, including swell height, period, direction, and more. Check the swell at a glance without unlocking your phone.

## Getting Started

1. Open BuoyData and enter your preferred [NOAA buoy station ID](https://www.ndbc.noaa.gov/activestations.xml)
2. To customize your lock screen, either long press the lock screen and tap "Customize", or go to Settings > Wallpaper > Customize
3. Tap "Add Widgets" and search for BuoyData
4. Select the circular widget

## Support

For bug reports or feature requests, please [open an issue](https://github.com/esavv/buoys/issues).

## Data Source

All buoy data is sourced from [NOAA's National Data Buoy Center (NDBC)](https://www.ndbc.noaa.gov/).

## Developer Resources

* [NOAA NDBC Web Data Guide](https://www.ndbc.noaa.gov/docs/ndbc_web_data_guide.pdf)
* [Active stations list](https://www.ndbc.noaa.gov/activestations.xml)
* [NDBC realtime data directory](https://www.ndbc.noaa.gov/data/realtime2/)

### Building from source

When building & running the lock screen widget from Xcode, if you run into build errors, ensure the following in Product > Scheme > Edit Scheme (for BuoyDataWidgetExtension, not BuoyData):
* Add this Environment Variable: key: `_XCWidgetKind`, value: `BuoyDataWidget`
* In WidgetKit Environment ensure attribute Family is set to `accessoryRectangular` (or whichever lock screen accessory family you're using)