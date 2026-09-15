# LocalFlow artwork

An original five-bar waveform mark replaces the former photo icon. The menu-bar
version is a native template image, so it follows macOS light/dark contrast; red
indicates recording or processing. The app icon uses cream bars on a coral gradient.
No third-party image, font, photo, or brand asset is bundled.

Regenerate the 1024px PNG and complete ICNS from vector drawing instructions:

```sh
xcrun swiftc scripts/generate-icon.swift -o /tmp/localflow-icon
/tmp/localflow-icon .build/artwork
iconutil -c icns .build/artwork/LocalFlow.iconset -o Resources/LocalFlow.icns
cp .build/artwork/LocalFlow.png Resources/LocalFlow.png
```
