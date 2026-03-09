# macOS Window & Toolbar Styling Reference

> Window configuration, toolbar styles, sizing, positioning, and navigation patterns specific to macOS SwiftUI apps.

---

## Quick Lookup Table

| API | Availability | macOS-Only? | Usage |
|-----|-------------|:-----------:|-------|
| `windowToolbarStyle(_:)` | macOS 11.0+ | Yes | Sets toolbar style: `.unified`, `.unifiedCompact`, `.expanded` |
| `windowStyle(_:)` | macOS 11.0+ | No | Supports `.hiddenTitleBar` for chromeless windows |
| `windowResizability(_:)` | macOS 13.0+ | No | Controls resize handle and green zoom button behavior |
| `defaultSize(width:height:)` | macOS 13.0+ | No | Initial frame size when user creates a new window |
| `defaultPosition(_:)` | macOS 13.0+ | No | Initial window position on screen |
| `windowIdealPlacement(_:)` | macOS 15.0+ | No | Closure with display geometry for precise window positioning |
| `menuBarExtraStyle(_:)` | macOS 13.0+ | Yes | Sets MenuBarExtra to `.menu` or `.window` style |
| `NavigationSplitView` | macOS 13.0+ | No | Columns always visible side-by-side on macOS; translucent sidebar |
| `Inspector` | macOS 14.0+ | No | Trailing-edge sidebar panel; resizable by dragging |

---

## Toolbar Styles

### windowToolbarStyle (macOS-only)

Controls how the toolbar and title bar are displayed. Applied to a scene.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Title bar and toolbar in a single row
        .windowToolbarStyle(.unified)
    }
}
```

**Available styles:**

| Style | Description |
|-------|-------------|
| `.automatic` | System default |
| `.unified` | Title bar and toolbar in a single combined row |
| `.unifiedCompact` | Same as unified but with reduced vertical height |
| `.expanded` | Title bar displayed above the toolbar (more toolbar space) |

```swift
// Unified compact — minimal chrome
.windowToolbarStyle(.unifiedCompact)

// Expanded — title bar above toolbar
.windowToolbarStyle(.expanded)

// Unified with title hidden
.windowToolbarStyle(.unified(showsTitle: false))
```

### Toolbar content

```swift
struct ContentView: View {
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: addItem) {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar)
    }
}
```

---

## Window Style

### windowStyle

Set the visual style of a window. Use `.hiddenTitleBar` for chromeless, immersive windows.

```swift
// Standard title bar (default)
WindowGroup {
    ContentView()
}
.windowStyle(.titleBar)

// Hidden title bar — chromeless window
WindowGroup {
    ContentView()
}
.windowStyle(.hiddenTitleBar)
```

> **Use case:** `.hiddenTitleBar` is useful for media players, custom-chrome apps, or immersive experiences where the standard title bar is unwanted.

---

## Window Sizing

### windowResizability

Controls whether and how a window can be resized. Affects the resize handle and the green zoom button.

```swift
// Fixed size — no resize handle, zoom button disabled
Window("Calculator", id: "calculator") {
    CalculatorView()
}
.windowResizability(.contentSize)

// Flexible with minimum — resize allowed, respects min frame
Window("Editor", id: "editor") {
    EditorView()
        .frame(minWidth: 400, minHeight: 300)
}
.windowResizability(.contentMinSize)

// Automatic (default) — system decides based on content
WindowGroup {
    ContentView()
}
.windowResizability(.automatic)
```

**Options:**

| Value | Behavior |
|-------|----------|
| `.automatic` | System decides resize behavior |
| `.contentSize` | Fixed to content size; no user resize; zoom button disabled |
| `.contentMinSize` | Resizable with minimum based on content's `minWidth`/`minHeight` |

### defaultSize

Sets the initial frame size when a user creates a new window. Subsequent windows may restore their last size.

```swift
WindowGroup {
    ContentView()
}
.defaultSize(width: 800, height: 600)

// Also accepts CGSize
.defaultSize(CGSize(width: 800, height: 600))
```

### defaultPosition

Sets the initial position of new windows on screen.

```swift
WindowGroup {
    ContentView()
}
.defaultPosition(.center)

// Available positions:
// .center, .topLeading, .top, .topTrailing
// .leading, .trailing
// .bottomLeading, .bottom, .bottomTrailing
```

### windowIdealPlacement (macOS 15.0+)

Provides a closure with display geometry for precise programmatic window positioning.

```swift
WindowGroup {
    ContentView()
}
.windowIdealPlacement { context in
    // Position window in the right half of the screen
    let screenFrame = context.defaultDisplay.visibleArea
    return WindowPlacement(
        x: screenFrame.midX,
        y: screenFrame.midY,
        width: screenFrame.width / 2,
        height: screenFrame.height
    )
}
```

### Combined window sizing pattern

The recommended approach for configuring macOS windows:

```swift
WindowGroup {
    ContentView()
        .frame(minWidth: 600, minHeight: 400)
}
.defaultSize(width: 900, height: 600)
.defaultPosition(.center)
.windowResizability(.contentMinSize)
```

**Guidelines:**
- Prefer setting `minWidth`/`minHeight` via `.frame()` on content for predictable layout
- Use `.windowResizability(.contentMinSize)` to enforce those minimums
- Use `.defaultSize()` for initial dimensions (larger than minimums)
- Use `.defaultPosition(.center)` for centered initial placement

---

## MenuBarExtra Style (macOS-only)

Choose between dropdown menu and popover panel for `MenuBarExtra`.

```swift
// Dropdown menu (default)
MenuBarExtra("Status", systemImage: "chart.bar") {
    Button("Action") { /* ... */ }
}
.menuBarExtraStyle(.menu)

// Popover panel with custom SwiftUI content
MenuBarExtra("Status", systemImage: "chart.bar") {
    DashboardView()
}
.menuBarExtraStyle(.window)
```

---

## Navigation Layout (macOS behavior)

### NavigationSplitView

On macOS, `NavigationSplitView` displays columns side-by-side (never overlaid). The sidebar gets a translucent material background. Columns support variable-width resizing by the user.

```swift
struct ContentView: View {
    @State private var departmentId: Department.ID?
    @State private var employeeIds = Set<Employee.ID>()

    var body: some View {
        NavigationSplitView {
            // Sidebar — translucent material on macOS
            List(model.departments, selection: $departmentId) { dept in
                Text(dept.name)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            // Content column
            if let department = model.department(id: departmentId) {
                List(department.employees, selection: $employeeIds) { emp in
                    Text(emp.name)
                }
            } else {
                Text("Select a department")
            }
        } detail: {
            EmployeeDetails(for: employeeIds)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### Column width customization

```swift
NavigationSplitView {
    SidebarView()
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
} detail: {
    DetailView()
        .navigationSplitViewColumnWidth(min: 400, ideal: 600)
}
```

### Inspector (macOS 14.0+)

A trailing-edge panel for supplementary information. On macOS, it appears as a sidebar-style panel that can be resized by dragging its edge.

```swift
struct ContentView: View {
    @State private var showInspector = false

    var body: some View {
        MainContent()
            .inspector(isPresented: $showInspector) {
                InspectorView()
                    .inspectorColumnWidth(min: 200, ideal: 250, max: 400)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("Inspector", systemImage: "info.circle")
                    }
                }
            }
    }
}
```

---

## Commands & Keyboard

### Commands, CommandGroup, CommandMenu

Define menu bar commands. On macOS, these populate the menu bar directly. On iOS, they create key commands.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // Add a new top-level menu (appears between View and Window)
            CommandMenu("Tools") {
                Button("Run Analysis") {
                    // action
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Clear Cache") {
                    // action
                }
            }

            // Replace existing Help menu content
            CommandGroup(replacing: .help) {
                Button("My App Help") {
                    // open help
                }
            }

            // Add items after the "New" group in File menu
            CommandGroup(after: .newItem) {
                Button("New From Template...") {
                    // action
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}
```

### KeyboardShortcut

On macOS, shortcuts are displayed alongside menu items and in button tooltips on hover.

```swift
Button("Save") {
    save()
}
.keyboardShortcut("s", modifiers: .command)

Button("Delete") {
    delete()
}
.keyboardShortcut(.delete, modifiers: .command)
```

### openWindow

Programmatically open a window. If the target window is already open, brings it to the front.

```swift
struct ToolbarActions: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Connection Doctor") {
            openWindow(id: "connection-doctor")
        }

        Button("Show Message") {
            openWindow(value: message.id)  // Type-matched to WindowGroup
        }
    }
}
```

---

## Best Practices

- **Use `.unified` or `.unifiedCompact`** for most apps — `.expanded` only when you need many toolbar items
- **Set min frame sizes on content** and use `.windowResizability(.contentMinSize)` to enforce them
- **Always provide `defaultSize`** so new windows start at a reasonable size
- **Use `NavigationSplitView`** for sidebar navigation — not `HSplitView`
- **Use `Inspector`** for supplementary panels — it integrates with the toolbar automatically
- **Define `Commands`** for all repeatable actions — users expect keyboard shortcuts on macOS
- **Use `#if os(macOS)`** to wrap macOS-only window configuration in multiplatform projects
