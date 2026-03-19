# DocC Documentation Guide

## Overview

VivaDicta uses [DocC](https://developer.apple.com/documentation/docc) for API documentation, hosted on GitHub Pages at:

**https://n0an.github.io/VivaDicta/**

The documentation is built locally and deployed to the `gh-pages` branch. The `main` branch does not contain the generated output.

## Building & Deploying

### Prerequisites

- Xcode with iOS Simulator installed
- Git with push access to the repository

### Build & Deploy (One Command)

```bash
./build-docc.sh
```

This script:
1. Builds the DocC archive using `xcodebuild docbuild`
2. Transforms it for static hosting with `docc process-archive`
3. Adds the root redirect (`index.html`) and favicons
4. Switches to the `gh-pages` branch
5. Replaces the `docs/` folder with the new build
6. Commits and pushes to `gh-pages`
7. Switches back to `main`

GitHub Pages automatically deploys from the `gh-pages` branch's `/docs` folder.

### Important Notes

- Must be run from the **`main` branch**
- Working tree should be clean (no uncommitted changes) to avoid issues when switching branches
- The script will fail if the Xcode build fails
- First deployment after adding new DocC articles may take a few minutes to appear on GitHub Pages

## DocC Catalog Structure

The DocC catalog lives at `VivaDicta/VivaDicta.docc/`:

```
VivaDicta.docc/
├── VivaDicta.md              # Landing page
├── AppGroupCoordinatorArchitecture.md  # Architecture article
└── Resources/
    ├── overview@2x.png       # Light mode hero image
    └── overview~dark@2x.png  # Dark mode hero image
```

## Adding Documentation

### Adding a New Article

1. Create a `.md` file in `VivaDicta/VivaDicta.docc/`
2. Use DocC markdown syntax with the `@Metadata` directive
3. Reference it from `VivaDicta.md` landing page if needed
4. Run `./build-docc.sh` to rebuild and deploy

### Adding Documentation to Code

Add `///` doc comments to public types and methods. DocC automatically generates pages for all documented symbols.

```swift
/// Coordinates communication between the main app and extensions.
///
/// ## Overview
///
/// `AppGroupCoordinator` uses App Groups for shared storage...
public final class AppGroupCoordinator {
    /// Requests the main app to start recording.
    public func requestStartRecording() { ... }
}
```

### Adding Images

Place images in `VivaDicta/VivaDicta.docc/Resources/`. Use the `@2x` suffix for Retina and `~dark` for dark mode variants:

```
myimage@2x.png        # Light mode
myimage~dark@2x.png   # Dark mode
```

Reference in markdown: `![Description](myimage)`

## Hosting Configuration

- **Branch**: `gh-pages` (orphan branch, contains only docs output)
- **Folder**: `/docs`
- **Base path**: `/VivaDicta` (matches the GitHub repo name)
- **Redirect**: `docs/index.html` redirects root URL to `/documentation/vivadicta`

## Troubleshooting

### 404 after deploy
GitHub Pages can take 1-2 minutes to update. If it persists, check the `gh-pages` branch has the `docs/` folder with content.

### Build fails with "no such module"
Resolve Swift packages first: `xcodebuild -resolvePackageDependencies -workspace ./VivaDicta.xcodeproj/project.xcworkspace -scheme VivaDicta`

### Docs are stale
Make sure you're running `./build-docc.sh` from `main` with the latest code. The script builds from whatever state your working directory is in.
