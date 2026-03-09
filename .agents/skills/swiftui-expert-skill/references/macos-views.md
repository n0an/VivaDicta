# macOS Views & Components Reference

> macOS-specific SwiftUI views, file operations, drag & drop, and AppKit interop. Covers `HSplitView`, `VSplitView`, `Table`, `PasteButton`, file dialogs, cross-app drag & drop, and `NSViewRepresentable`.

---

## Quick Lookup Table

### Views

| API | Availability | macOS-Only? | Usage |
|-----|-------------|:-----------:|-------|
| `HSplitView` | macOS 10.15+ | Yes | Horizontal resizable split layout with user-draggable dividers |
| `VSplitView` | macOS 10.15+ | Yes | Vertical resizable split layout with user-draggable dividers |
| `Table` | macOS 12.0+ | No | Full multi-column layout with sorting; on iOS compact, columns collapse |
| `PasteButton` | macOS 10.15+ | No | System button that reads clipboard; does NOT auto-validate on macOS |
| `CopyButton` | macOS 15.0+ | Yes | System button that copies `Transferable` content to clipboard |

### File Operations

| API | Availability | macOS-Only? | Usage |
|-----|-------------|:-----------:|-------|
| `fileImporter()` | macOS 11.0+ | No | Native NSOpenPanel with column/list/gallery view, sidebar, tags, QuickLook |
| `fileExporter()` | macOS 11.0+ | No | Native NSSavePanel with format dropdown, tags field |
| `fileMover()` | macOS 11.0+ | No | Native macOS move panel with Finder-like navigation |
| `fileDialogMessage(_:)` | macOS 13.0+ | Yes | Custom message text in file dialogs |
| `fileDialogConfirmationLabel(_:)` | macOS 13.0+ | Yes | Custom confirm button text in file dialogs |
| `fileExporterFilenameLabel(_:)` | macOS 13.0+ | Yes | Custom filename field label in file exporter |

### Drag, Drop & Pasteboard

| API | Availability | macOS-Only? | Usage |
|-----|-------------|:-----------:|-------|
| `onDrag(_:)` / `draggable(_:)` | macOS 11.0+ | No | Drag image follows cursor; items draggable between apps |
| `onDrop(of:delegate:)` / `dropDestination(for:action:)` | macOS 11.0+ | No | Accepts drops from any macOS app including Finder |

### AppKit Interop

| API | Availability | macOS-Only? | Usage |
|-----|-------------|:-----------:|-------|
| `NSViewRepresentable` | macOS 10.15+ | Yes | Wrap an AppKit `NSView` in SwiftUI |
| `NSViewControllerRepresentable` | macOS 10.15+ | Yes | Wrap an AppKit `NSViewController` in SwiftUI |
| `NSHostingController` | macOS 10.15+ | Yes | Host SwiftUI inside an AppKit view controller |
| `NSHostingView` | macOS 10.15+ | Yes | Host SwiftUI inside an AppKit `NSView` hierarchy |

---

## HSplitView & VSplitView (macOS-only)

Resizable split layouts with user-draggable dividers. Use for IDE-style panes where all panels are equal peers.

### Horizontal split

```swift
struct EditorLayout: View {
    var body: some View {
        HSplitView {
            FileTreeView()
                .frame(minWidth: 200)

            CodeEditorView()
                .frame(minWidth: 400)

            PreviewPane()
                .frame(minWidth: 200)
        }
    }
}
```

### Vertical split

```swift
struct TerminalLayout: View {
    var body: some View {
        VSplitView {
            CodeEditorView()
                .frame(minHeight: 300)

            ConsoleOutputView()
                .frame(minHeight: 100)
        }
    }
}
```

> **When to use which:**
> - **`NavigationSplitView`** — sidebar-based navigation (sidebar drives content/detail)
> - **`HSplitView`/`VSplitView`** — IDE-style layouts where all panes are equal peers (editor + terminal, code + preview)

---

## Table

Multi-column data table. On macOS, shows full columns with horizontal scrolling and interactive sortable headers. On iOS compact, all columns after the first are automatically hidden.

### Basic table

```swift
struct Person: Identifiable {
    let givenName: String
    let familyName: String
    let emailAddress: String
    let id = UUID()
    var fullName: String { givenName + " " + familyName }
}

struct PeopleTable: View {
    @State private var people: [Person] = [ /* ... */ ]

    var body: some View {
        Table(people) {
            TableColumn("Given Name", value: \.givenName)
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
    }
}
```

### Sortable table with selection

```swift
struct SortableTable: View {
    @State private var people: [Person] = [ /* ... */ ]
    @State private var selectedPeople = Set<Person.ID>()
    @State private var sortOrder = [KeyPathComparator(\Person.givenName)]

    var body: some View {
        Table(people, selection: $selectedPeople, sortOrder: $sortOrder) {
            TableColumn("Given Name", value: \.givenName)
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
        .onChange(of: sortOrder) { _, newOrder in
            people.sort(using: newOrder)
        }
        Text("\(selectedPeople.count) people selected")
    }
}
```

### Adaptive table for macOS + iOS compact

Handle the compact size class gracefully by showing combined info in the first column:

```swift
struct AdaptiveTable: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    @State private var people: [Person] = [ /* ... */ ]
    @State private var sortOrder = [KeyPathComparator(\Person.givenName)]

    var body: some View {
        Table(people, sortOrder: $sortOrder) {
            TableColumn("Given Name", value: \.givenName) { person in
                VStack(alignment: .leading) {
                    Text(isCompact ? person.fullName : person.givenName)
                    if isCompact {
                        Text(person.emailAddress)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            TableColumn("Family Name", value: \.familyName)
            TableColumn("E-Mail Address", value: \.emailAddress)
        }
        .onChange(of: sortOrder) { _, newOrder in
            people.sort(using: newOrder)
        }
    }
}
```

### Table styles

```swift
// Bordered with visible grid lines (macOS-only)
Table(people) { /* columns */ }
    .tableStyle(.bordered)

// Bordered with alternating row backgrounds
Table(people) { /* columns */ }
    .tableStyle(.bordered(alternatesRowBackgrounds: true))

// Inset (no borders)
Table(people) { /* columns */ }
    .tableStyle(.inset)

// Hide column headers
Table(people) { /* columns */ }
    .tableColumnHeaders(.hidden)
```

---

## PasteButton & CopyButton

### PasteButton

System button that reads clipboard content via `Transferable`. On macOS, it does NOT auto-validate pasteboard changes (unlike iOS).

```swift
struct ClipboardView: View {
    @State private var pastedText = ""

    var body: some View {
        HStack {
            PasteButton(payloadType: String.self) { strings in
                pastedText = strings[0]
            }
            Divider()
            Text(pastedText)
            Spacer()
        }
    }
}
```

### CopyButton (macOS 15.0+, macOS-only)

System button that copies `Transferable` content to the clipboard.

```swift
struct CopyableContent: View {
    let shareableText = "Hello, world!"

    var body: some View {
        HStack {
            Text(shareableText)
            CopyButton(item: shareableText)
        }
    }
}
```

---

## File Operations

### fileImporter

On macOS, presents a native `NSOpenPanel` with column/list/gallery view, sidebar favorites, tags, and QuickLook.

```swift
struct FilePickerView: View {
    @State private var showImporter = false
    @State private var selectedURL: URL?

    var body: some View {
        Button("Choose PDF") {
            showImporter = true
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let gotAccess = url.startAccessingSecurityScopedResource()
                if gotAccess {
                    selectedURL = url
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}
```

> **Important:** Always call `startAccessingSecurityScopedResource()` on returned URLs, and `stopAccessingSecurityScopedResource()` when done.

### fileExporter

On macOS, presents a native `NSSavePanel` with format dropdown and tags.

```swift
struct ExportView: View {
    @State private var showExporter = false
    @State private var document = TextFile(text: "Hello, world!")

    var body: some View {
        Button("Export") {
            showExporter = true
        }
        .fileExporter(
            isPresented: $showExporter,
            document: document,
            contentType: .plainText,
            defaultFilename: "MyFile.txt"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}
```

### File dialog customization (macOS-only)

Customize text in file dialogs with these macOS-specific modifiers:

```swift
// Custom message and confirm button on file importer
.fileImporter(
    isPresented: $showImporter,
    allowedContentTypes: [.image]
) { result in
    // handle result
}
.fileDialogMessage("Select an image to use as your profile photo")
.fileDialogConfirmationLabel("Use This Photo")

// Custom filename label on file exporter
.fileExporter(
    isPresented: $showExporter,
    document: myDocument,
    contentType: .png
) { result in
    // handle result
}
.fileExporterFilenameLabel("Export As:")
```

---

## Drag, Drop & Pasteboard

On macOS, drag and drop works **across applications** (e.g., drag from your app to Finder, Mail, or other apps).

### Modern approach (Transferable)

```swift
// Drag source
struct DraggableCard: View {
    let item: MyItem

    var body: some View {
        Text(item.title)
            .draggable(item)  // Requires Transferable conformance
    }
}

// Drop target
struct DropZone: View {
    @State private var droppedItems: [MyItem] = []

    var body: some View {
        VStack {
            ForEach(droppedItems) { item in
                Text(item.title)
            }
        }
        .dropDestination(for: MyItem.self) { items, location in
            droppedItems.append(contentsOf: items)
            return true
        }
        .frame(width: 300, height: 200)
        .border(.secondary)
    }
}
```

### Legacy approach (NSItemProvider)

```swift
// Drag source
Image(systemName: "doc")
    .onDrag {
        NSItemProvider(object: fileURL as NSURL)
    }

// Drop target
Text("Drop files here")
    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
        // handle providers
        return true
    }
```

---

## AppKit Interop

### NSViewRepresentable (macOS-only)

Wraps an AppKit `NSView` for use in SwiftUI. Implement `makeNSView(context:)` and `updateNSView(_:context:)`.

```swift
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }
}

// Usage
struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://apple.com")!)
            .frame(minWidth: 600, minHeight: 400)
    }
}
```

### NSViewRepresentable with Coordinator

Use a Coordinator to forward delegate/target-action callbacks to SwiftUI.

```swift
struct SearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                text.wrappedValue = field.stringValue
            }
        }
    }
}
```

> **Warning:** SwiftUI controls the layout via `frame` and `bounds`. Never set these properties directly on the managed `NSView` — it conflicts with SwiftUI and causes undefined behavior.

### NSViewControllerRepresentable (macOS-only)

Wraps an AppKit `NSViewController` for use in SwiftUI.

```swift
struct MapViewWrapper: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> MapViewController {
        MapViewController()
    }

    func updateNSViewController(_ nsViewController: MapViewController, context: Context) {
        // Update the controller when SwiftUI state changes
    }
}
```

### NSHostingController & NSHostingView (macOS-only)

Host SwiftUI content inside AppKit (reverse direction — AppKit app embedding SwiftUI views).

```swift
// Host SwiftUI as a view controller
let hostingController = NSHostingController(rootView: MySwiftUIView())
window.contentViewController = hostingController

// Host SwiftUI directly as an NSView
let hostingView = NSHostingView(rootView: MySwiftUIView())
someNSView.addSubview(hostingView)
```

---

## Best Practices

- **Use `NavigationSplitView`** for sidebar-driven navigation — reserve `HSplitView`/`VSplitView` for IDE-style equal peer panes
- **Make `Table` adaptive** — handle compact size classes by showing combined info in the first column
- **Always call `startAccessingSecurityScopedResource()`** on URLs from `fileImporter` — they are security-scoped
- **Use `Transferable`** for drag & drop (modern) — fall back to `NSItemProvider` only for legacy compatibility
- **Use `NSViewRepresentable` with Coordinator** when you need delegate callbacks from AppKit views
- **Never set `frame`/`bounds`** directly on views managed by `NSViewRepresentable` — SwiftUI owns the layout
- **Prefer native SwiftUI** over AppKit interop when possible — only use `NSViewRepresentable` for features SwiftUI doesn't provide
