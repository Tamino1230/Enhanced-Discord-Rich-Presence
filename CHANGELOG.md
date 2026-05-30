# Changelog

### Added
- added **Linux** support.
- added Support for:
  - `Google Chrome`
  - `Microsoft Edge` (coming soon)
  - `Opera` (coming soon)
  - `Opera GX` (coming soon)
  - `Brave`
  - `Vivaldi`
  - `Chromium*`

>`*`Chromium itself is supported, but some Browsers may have different Registry locations which makes them not work. If your browser doesn't work, feel free to open an Issue and I'll check if I can add it!

### Changed
- fixed an issue that if the video/song was only 1 character long, it woulds stop the RPC due to the title and state needing to be at least 2 characters long. Thanks to [ImHoppy](https://github.com/ImHoppy) for this PR!

## Known Issues

- When the Extension is active across multiple browser windows simultaneously, executing the same Activity causes a race condition that leads to unpredictable behavior.