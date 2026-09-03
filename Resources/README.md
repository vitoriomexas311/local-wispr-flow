# LocalFlow artwork

The app icon uses the owner's supplied `localflow.jpg` photograph. It is a
centered square crop with rounded corners, not a generated or retouched face.
`LocalFlow.png` is the 1024-pixel master preview; `LocalFlow.icns` contains the
macOS icon sizes. Exported PNGs retain only pixel and sRGB chunks.

Conversion source is in `scripts/generate-icon.swift`. With a working macOS SDK:

```sh
swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" scripts/generate-icon.swift -o /tmp/localflow-icon
/tmp/localflow-icon /path/to/localflow.jpg .build/icon
iconutil -c icns .build/icon/LocalFlow.iconset -o .build/icon/LocalFlow.icns
```

The original photograph and its camera metadata are not required to build or
install LocalFlow; the committed icon assets are used directly.
