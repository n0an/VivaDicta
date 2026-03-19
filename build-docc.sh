#!/bin/sh

export DOCC_JSON_PRETTYPRINT="YES"

xcrun xcodebuild docbuild \
    -scheme VivaDicta \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$PWD/.derivedData"

xcrun docc process-archive transform-for-static-hosting \
    "$PWD/.derivedData/Build/Products/Debug-iphonesimulator/VivaDicta.doccarchive" \
    --output-path "docs" \
    --hosting-base-path "VivaDicta"

echo '<script>window.location.href += "/documentation/vivadicta"</script>' > docs/index.html

# Copy favicon to docs folder
cp -f "$PWD/favicon.ico" "$PWD/docs/favicon.ico"
cp -f "$PWD/favicon.png" "$PWD/docs/favicon.png"

rm -rf "$PWD/.derivedData"
