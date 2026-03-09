# macOS Scenes Reference

> SwiftUI scene types for macOS apps — `Settings`, `MenuBarExtra`, `WindowGroup`, `Window`, `UtilityWindow`, and `DocumentGroup`. Covers macOS-only scenes and cross-platform scenes with macOS-specific behavior.

---

## Quick Lookup Table

| API | Availability | macOS-Only? | macOS-Specific Behavior |
|-----|-------------|:-----------:|------------------------|
| `WindowGroup` | macOS 11.0+ | No | Multiple window instances, tabbed interface, automatic Window menu commands |
| `Window` | macOS 13.0+ | No | App quits when sole window closes; adds itself to Windows menu |
| `UtilityWindow` | macOS 15.0+ | Yes | Floating tool palette; receives `FocusedValues` from active main window |
| `Settings` | macOS 11.0+ | Yes | Presents preferences window (Cmd+,) |
| `MenuBarExtra` | macOS 13.0+ | Yes | Persistent icon/menu in the system menu bar |
| `DocumentGroup` | macOS 11.0+ | No | Document-based menu bar commands (File > New/Open/Save); multiple document windows |

---

## Settings (macOS-only)

Presents the app's preferences window, accessible via **Cmd+,** or the app menu. SwiftUI automatically enables the Settings menu item and manages the window lifecycle.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("Advanced", systemImage: "star") {
                AdvancedSettingsView()
            }
        }
        .scenePadding()
        .frame(maxWidth: 350, minHeight: 100)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("showPreview") private var showPreview = true
    @AppStorage("fontSize") private var fontSize = 12.0

    var body: some View {
        Form {
            Toggle("Show Previews", isOn: $showPreview)
            Slider(value: $fontSize, in: 9...96) {
                Text("Font Size (\(fontSize, specifier: "%.0f") pts)")
            }
        }
    }
}
```

### SettingsLink (macOS 14.0+)

A button that opens the Settings scene. Use for in-app navigation to preferences.

```swift
struct SidebarFooter: View {
    var body: some View {
        SettingsLink {
            Label("Preferences", systemImage: "gear")
        }
    }
}
```

### openSettings environment action (macOS 14.0+)

Programmatically open (or bring to front) the Settings window.

```swift
struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open Settings") {
            openSettings()
        }
    }
}
```

---

## MenuBarExtra (macOS-only)

Renders a persistent control in the system menu bar. Two styles available:
- **`.menu`** (default) — standard dropdown menu
- **`.window`** — popover panel with custom SwiftUI views

### Menu-style (dropdown)

```swift
@main
struct UtilityApp: App {
    var body: some Scene {
        MenuBarExtra("My Utility", systemImage: "hammer") {
            Button("Action One") { /* ... */ }
            Button("Action Two") { /* ... */ }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

### Window-style (popover panel)

```swift
@main
struct StatusApp: App {
    var body: some Scene {
        MenuBarExtra("Status", systemImage: "chart.bar") {
            VStack(spacing: 12) {
                Text("System Status")
                    .font(.headline)
                ProgressView(value: 0.7)
                    .progressViewStyle(.linear)
                Button("Refresh") { /* ... */ }
            }
            .padding()
            .frame(width: 240)
        }
        .menuBarExtraStyle(.window)
    }
}
```

### Toggleable menu bar extra

```swift
@main
struct AppWithMenuBarExtra: App {
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        MenuBarExtra(
            "App Menu Bar Extra", systemImage: "star",
            isInserted: $showMenuBarExtra
        ) {
            StatusMenu()
        }
    }
}
```

### Menu-bar-only app pattern

For utility apps that only live in the menu bar with no Dock icon:

```swift
@main
struct MenuBarOnlyApp: App {
    var body: some Scene {
        MenuBarExtra("My Utility", systemImage: "gear") {
            VStack {
                DashboardView()
            }
            .frame(width: 300, height: 400)
        }
        .menuBarExtraStyle(.window)
    }
}
```

> **Tip:** Set `LSUIElement = true` in Info.plist to hide the Dock icon and app switcher entry. The app auto-terminates if the user removes the extra from the menu bar.

---

## WindowGroup (macOS behavior)

On macOS, `WindowGroup` supports:
- **Multiple window instances** — users can open many windows from File > New Window
- **Tabbed interface** — users can merge windows into tabs
- **Automatic Window menu** — commands for window management appear automatically

```swift
@main
struct Mail: App {
    var body: some Scene {
        // Basic multi-window support
        WindowGroup {
            MailViewer()
        }

        // Data-presenting window opened programmatically
        WindowGroup("Message", for: Message.ID.self) { $messageID in
            MessageDetail(messageID: messageID)
        }
    }
}

// Open a specific window programmatically
struct NewMessageButton: View {
    var message: Message
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Message") {
            openWindow(value: message.id)
        }
    }
}
```

> **Key difference from `Window`:** `WindowGroup` keeps the app running even after all windows are closed. `Window` (as sole scene) quits the app when closed.

---

## Window

A single, unique window scene. The system ensures only one instance exists.

```swift
@main
struct Mail: App {
    var body: some Scene {
        WindowGroup {
            MailViewer()
        }

        // Supplementary singleton window
        Window("Connection Doctor", id: "connection-doctor") {
            ConnectionDoctor()
        }
    }
}

// Open programmatically — brings to front if already open
struct OpenDoctorButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Connection Doctor") {
            openWindow(id: "connection-doctor")
        }
    }
}
```

### Window as sole scene

If `Window` is the only scene, the app quits when the window closes:

```swift
@main
struct VideoCall: App {
    var body: some Scene {
        Window("VideoCall", id: "main") {
            CameraView()
        }
    }
}
```

> **Recommendation:** In most cases, prefer `WindowGroup` for the primary scene. Use `Window` for supplementary singleton windows.

---

## UtilityWindow (macOS-only)

A specialized floating window for tool palettes and inspector panels. Available since macOS 15.0.

**Key behaviors:**
- Receives `FocusedValues` from the focused main scene (like menu bar commands)
- Floats above main windows (default level: `.floating`)
- Hides when the app is no longer active
- Only becomes focused when explicitly needed (e.g., clicking the title bar)
- Dismissible with the Escape key
- Not minimizable by default
- Automatically adds a show/hide item to the View menu

```swift
@main
struct PhotoBrowser: App {
    var body: some Scene {
        WindowGroup {
            PhotoGallery()
        }

        UtilityWindow("Photo Info", id: "photo-info") {
            PhotoInfoViewer()
        }
    }
}

struct PhotoInfoViewer: View {
    // Automatically updates based on whichever main window is focused
    @FocusedValue(PhotoSelection.self) private var selectedPhotos

    var body: some View {
        if let photos = selectedPhotos {
            Text("\(photos.count) photos selected")
        } else {
            Text("No selection")
                .foregroundStyle(.secondary)
        }
    }
}
```

> **Tip:** Remove the automatic View menu item with `.commandsRemoved()` and place a `WindowVisibilityToggle` elsewhere in your commands.

---

## DocumentGroup

Document-based apps with automatic file management. On macOS, provides:
- **Document-based menu bar commands** (File > New, Open, Save, Revert)
- **Multiple document windows** simultaneously
- On iOS, shows a document browser instead

```swift
@main
struct TextEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TextFile()) { configuration in
            ContentView(document: configuration.$document)
        }
    }
}

struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String = ""

    init() {}

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

### Multiple document types

```swift
@main
struct MyApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TextFile()) { group in
            ContentView(document: group.$document)
        }
        DocumentGroup(viewing: MyImageFormatDocument.self) { group in
            MyImageFormatViewer(image: group.document)
        }
    }
}
```

---

## Platform Conditionals

Always wrap macOS-only scenes in `#if os(macOS)`:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }

        MenuBarExtra("Status", systemImage: "bolt") {
            StatusMenu()
        }
        #endif
    }
}
```

---

## Best Practices

- **Use `Settings`** for preferences — prefer this over a custom preferences window
- **Use `MenuBarExtra`** for menu bar items — prefer this over managing AppKit's `NSStatusItem` directly
- **Use `WindowGroup`** as the primary scene — reserve `Window` for supplementary singletons
- **Use `UtilityWindow`** for inspectors/palettes — it handles floating, focus, and visibility automatically
- **Use `DocumentGroup`** for document-based apps — it provides the full File menu and document lifecycle
- **Gate macOS-only scenes** with `#if os(macOS)` for multiplatform projects
- **Use `openWindow(id:)`** to open windows programmatically — it brings existing windows to front
