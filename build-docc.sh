#!/bin/sh
set -e

# Build DocC documentation and deploy to gh-pages branch
# Usage: ./build-docc.sh

export DOCC_JSON_PRETTYPRINT="YES"

CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: Must be on main branch. Currently on: $CURRENT_BRANCH"
    exit 1
fi

# Build DocC archive
echo "Building DocC documentation..."
xcrun xcodebuild docbuild \
    -scheme VivaDicta \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.4' \
    -derivedDataPath "$PWD/.derivedData"

# Transform for static hosting into a temp directory
TEMP_DOCS=$(mktemp -d)
xcrun docc process-archive transform-for-static-hosting \
    "$PWD/.derivedData/Build/Products/Debug-iphonesimulator/VivaDicta.doccarchive" \
    --output-path "$TEMP_DOCS/docs" \
    --hosting-base-path "VivaDicta"

# Add redirect and favicons
echo '<script>window.location.href += "/documentation/vivadicta"</script>' > "$TEMP_DOCS/docs/index.html"
cp -f "$PWD/favicon.ico" "$TEMP_DOCS/docs/favicon.ico"
cp -f "$PWD/favicon.png" "$TEMP_DOCS/docs/favicon.png"

# Clean up build artifacts
rm -rf "$PWD/.derivedData"

# Deploy to gh-pages branch
echo "Deploying to gh-pages..."
git checkout gh-pages

rm -rf docs
cp -R "$TEMP_DOCS/docs" docs
rm -rf "$TEMP_DOCS"

git add docs/
git commit -m "Update DocC documentation" || echo "No changes to commit"
git push origin gh-pages

# Switch back to main
git checkout main

echo "Done! Documentation deployed to gh-pages."
echo "Site: https://n0an.github.io/VivaDicta/"
