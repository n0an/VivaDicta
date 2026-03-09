# SwiftUI Charts Reference (iOS 16+)

## Overview

Swift Charts is Apple's native charting framework for SwiftUI. Use `Chart` with one or more marks to build bar, line, area, point, rule, rectangle, and sector charts. This reference covers the standard 2D chart APIs, axis customization, built-in selection APIs, annotations, and custom touch handling.

## Availability

Base `Chart`, custom axes, scales, and most marks require iOS 16 or later.

- `BarMark`, `LineMark`, `AreaMark`, `PointMark`, `RectangleMark`, and `RuleMark` are available on iOS 16+
- `SectorMark`, built-in selection, and scrollable chart axes require iOS 17+
- Data-driven plot types such as `BarPlot` and `LinePlot` require iOS 18+
- Chart3D and Z-axis APIs exist on iOS 26+; this reference is primarily about 2D `Chart`, with a dedicated Chart3D section below

```swift
if #available(iOS 17, *) {
    // Selection, SectorMark, scrollable axes
} else {
    // Base Chart, axes, scales, and core marks
}
```

## Core APIs

### Import the Framework

Always check that the file imports `Charts` before using `Chart`, `Chart3D`, `BarMark`, `SectorMark`, or `ChartProxy`.

```swift
import SwiftUI
import Charts
```

If chart types are unresolved, the first thing to verify is that `Charts` is imported in that file.

### Chart Container

`Chart` is the root view. Add one or more marks inside it.

```swift
Chart(sales) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Revenue", item.revenue)
    )
}
```

### Data Models Should Be Identifiable

Prefer `Identifiable` models for chart data so identity stays stable as data changes.

```swift
struct SalesPoint: Identifiable {
    let id: UUID
    let month: String
    let revenue: Double
}
```

If your model cannot conform to `Identifiable`, provide an explicit id key path:

```swift
Chart(sales, id: \.month) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Revenue", item.revenue)
    )
}
```

### Plottable Values

Use `.value(_, _)` to describe what each axis value means. Those labels are reused by axes, legends, and accessibility.

```swift
LineMark(
    x: .value("Day", entry.date),
    y: .value("Steps", entry.count)
)
```

## Chart Types

### BarMark

Use `BarMark` for categorical comparisons, histograms, and interval bars.

```swift
Chart(products) { product in
    BarMark(
        x: .value("Product", product.name),
        y: .value("Units", product.units)
    )
}
```

`BarMark` supports stacking with `MarkStackingMethod`:

```swift
.standard
.normalized
.center
.unstacked
```

### LineMark

Use `LineMark` for continuous trends.

```swift
Chart(steps) { day in
    LineMark(
        x: .value("Day", day.date),
        y: .value("Steps", day.count)
    )
    .interpolationMethod(.monotone)
}
```

Available interpolation methods:

```swift
.linear
.cardinal
.cardinal(tension: 0.3)
.catmullRom
.catmullRom(alpha: 0.5)
.monotone
.stepStart
.stepCenter
.stepEnd
```

### AreaMark

Use `AreaMark` to fill under a line or between two values.

```swift
Chart(temperatures) { sample in
    AreaMark(
        x: .value("Hour", sample.hour),
        y: .value("Temperature", sample.value),
        stacking: .unstacked
    )
}
```

You can also define ranged areas with `yStart` and `yEnd`, which is useful for bands such as min/max ranges or confidence intervals.

```swift
AreaMark(
    x: .value("Day", sample.day),
    yStart: .value("Low", sample.low),
    yEnd: .value("High", sample.high)
)
```

### PointMark

Use `PointMark` for scatter plots or to emphasize individual points.

```swift
Chart(measurements) { measurement in
    PointMark(
        x: .value("Time", measurement.time),
        y: .value("Value", measurement.value)
    )
}
```

### RectangleMark

Use `RectangleMark` for heat maps, bins, and ranged cells.

```swift
Chart(cells) { cell in
    RectangleMark(
        xStart: .value("Start Day", cell.startDay),
        xEnd: .value("End Day", cell.endDay),
        yStart: .value("Low", cell.low),
        yEnd: .value("High", cell.high)
    )
}
```

### RuleMark

Use `RuleMark` for thresholds, targets, and crosshair lines.

```swift
Chart(sales) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Revenue", item.revenue)
    )

    RuleMark(y: .value("Goal", 10_000))
        .foregroundStyle(.red)
}
```

### SectorMark

Use `SectorMark` for pie and donut-style charts. `SectorMark` requires iOS 17 or later.

```swift
Chart(expenses) { expense in
    SectorMark(
        angle: .value("Amount", expense.amount),
        innerRadius: .ratio(0.6),
        angularInset: 2
    )
    .foregroundStyle(by: .value("Category", expense.category))
}
```

Use `innerRadius` to turn a pie chart into a donut chart, and `angularInset` to separate slices visually.

### Plot Types (iOS 18+)

iOS 18 adds data-driven plot wrappers for the same chart families:

- `AreaPlot`
- `BarPlot`
- `LinePlot`
- `PointPlot`
- `RectanglePlot`
- `RulePlot`
- `SectorPlot`

Use these when you want a more data-first API surface, but the underlying chart families stay the same.

### Chart3D (iOS 26+)

`Chart3D` is a separate API for 3D chart content. It supports 3D `PointMark`, `RectangleMark`, `RuleMark`, and `SurfacePlot`.

```swift
if #available(iOS 26, *) {
    Chart3D(points) { point in
        PointMark(
            x: .value("X", point.x),
            y: .value("Y", point.y),
            z: .value("Z", point.z)
        )
    }
    .chart3DPose(.front)
    .chart3DCameraProjection(.perspective)
}
```

Use `Chart3D` when you need a real Z axis. Keep it version-gated because it requires iOS 26 or later.

## Axis Tweaks

### Axis Visibility and Labels

Use `chartXAxis`, `chartYAxis`, `chartXAxisLabel`, and `chartYAxisLabel` on the `Chart` container.
Axis visibility supports `.automatic`, `.visible`, and `.hidden`.

```swift
Chart(data) { item in
    BarMark(
        x: .value("Month", item.month),
        y: .value("Revenue", item.revenue)
    )
}
.chartXAxis(.visible)
.chartYAxis(.hidden)
.chartXAxisLabel("Month")
.chartYAxisLabel("Revenue")
```

### Custom Axis Marks

Use `AxisMarks` to control tick placement, labels, and grid lines.

```swift
Chart(steps) { day in
    LineMark(
        x: .value("Day", day.date),
        y: .value("Steps", day.count)
    )
}
.chartXAxis {
    AxisMarks(
        preset: .aligned,
        position: .bottom,
        values: .stride(by: .day)
    ) {
        AxisGridLine()
        AxisTick(length: .label)
        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
    }
}
```

Useful `AxisMarks` inputs:

- `preset`: `.automatic`, `.extended`, `.aligned`, `.inset`
- `position`: `.automatic`, `.leading`, `.trailing`, `.top`, `.bottom`
- `values`: `.automatic`, `.automatic(desiredCount:)`, `.stride(by:)`, `.stride(by:count:)`, or an explicit array

### Axis Components

Within `AxisMarks`, combine the built-in axis components as needed:

```swift
AxisGridLine()
AxisTick()
AxisValueLabel()
```

`AxisValueLabel` can be tuned for dense axes:

```swift
AxisValueLabel(
    collisionResolution: .greedy(minimumSpacing: 8),
    orientation: .vertical
)
```

Available label orientations:

```swift
.automatic
.horizontal
.vertical
.verticalReversed
```

Available collision strategies:

```swift
.automatic
.greedy
.greedy(priority: 1, minimumSpacing: 8)
.truncate
.disabled
```

### Axis Domains and Plot Area Tweaks

Use scales when you need explicit axis domains or plot area control.

```swift
Chart(data) { item in
    LineMark(
        x: .value("Index", item.index),
        y: .value("Score", item.score)
    )
}
.chartXScale(domain: 0...30)
.chartYScale(domain: 0...100)
.chartPlotStyle { plotArea in
    plotArea
        .background(.gray.opacity(0.08))
}
```

You can set one axis domain without forcing the other:

```swift
.chartXScale(domain: startDate...endDate)
```

### Scrollable Axes (iOS 17+)

For larger datasets, make the plot area scroll and control the visible domain.

```swift
@State private var scrollX = 7

Chart(data) { item in
    BarMark(
        x: .value("Day", item.day),
        y: .value("Value", item.value)
    )
}
.chartScrollableAxes(.horizontal)
.chartXVisibleDomain(length: 7)
.chartScrollPosition(x: $scrollX)
```

## Selection APIs

### Single-Value Selection

Use `chartXSelection(value:)` or `chartYSelection(value:)` when you want one selected value.

```swift
struct SelectableLineChart: View {
    let steps: [DailySteps]
    @State private var selectedDate: Date?

    var body: some View {
        Chart(steps) { day in
            LineMark(
                x: .value("Day", day.date),
                y: .value("Steps", day.count)
            )
            .interpolationMethod(.monotone)

            if let selectedDate {
                RuleMark(x: .value("Selected Day", selectedDate))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXSelection(value: $selectedDate)
    }
}
```

`chartYSelection(value:)` works the same way for vertical selection.

### Range Selection

Use `chartXSelection(range:)` or `chartYSelection(range:)` when you want a dragged range instead of a single point.

```swift
struct RangeSelectableBars: View {
    let weeks: [WeeklyRevenue]
    @State private var selectedWeeks: ClosedRange<Int>?

    var body: some View {
        Chart(weeks) { week in
            BarMark(
                x: .value("Week", week.index),
                y: .value("Revenue", week.revenue)
            )
        }
        .chartXSelection(range: $selectedWeeks)
    }
}
```

Range selection requires a `ClosedRange` whose bound type matches the plotted axis value.

### Choosing Single vs Range

- Use `value:` bindings when only one point or axis value should be selected.
- Use `range:` bindings when users should brush a span (for zoom windows, comparisons, or grouped summaries).

### Angle Selection

Use `chartAngleSelection(value:)` with `SectorMark` charts. There is no built-in range overload for angle selection.

```swift
struct SelectablePieChart: View {
    let expenses: [ExpenseSlice]
    @State private var selectedAmount: Double?

    var body: some View {
        Chart(expenses) { expense in
            SectorMark(
                angle: .value("Amount", expense.amount)
            )
            .foregroundStyle(by: .value("Category", expense.category))
        }
        .chartAngleSelection(value: $selectedAmount)
    }
}
```

**Important**: Selection bindings return the plottable axis value, not the full data element. Map back to your model if you need the selected record.

## Annotations

Use `annotation(position:)` on a mark when you need labels, callouts, or highlighted values attached to the plotted content.

```swift
BarMark(
    x: .value("Month", item.month),
    y: .value("Revenue", item.revenue)
)
.annotation(position: .top) {
    Text(item.revenue.formatted())
}
```

This is useful for selected values, thresholds, summaries, and direct labeling. Common positions include `.overlay`, `.top`, `.bottom`, `.leading`, and `.trailing`.

## ChartProxy and Custom Touch Handling

Use `chartOverlay`/`chartBackground` (iOS 16+) or `chartGesture` (iOS 17+) with `ChartProxy` when built-in selection modifiers are not enough.

```swift
struct ProxyDrivenChart: View {
    let steps: [DailySteps]
    @State private var selectedDate: Date?

    var body: some View {
        Chart(steps) { day in
            LineMark(
                x: .value("Day", day.date),
                y: .value("Steps", day.count)
            )
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let frame: CGRect
                                if #available(iOS 17, *) {
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    frame = geometry[plotFrame]
                                } else {
                                    frame = geometry[proxy.plotAreaFrame]
                                }
                                let x = value.location.x - frame.origin.x

                                guard x >= 0, x <= frame.size.width else { return }
                                selectedDate = proxy.value(atX: x, as: Date.self)
                            }
                            .onEnded { _ in
                                selectedDate = nil
                            }
                    )
            }
        }
    }
}
```

The example above uses `plotFrame` on iOS 17+ and falls back to `plotAreaFrame` on iOS 16.

`ChartProxy` gives you lower-level access to:

- `value(atX:as:)`, `value(atY:as:)`, and `value(at:as:)` for converting gesture coordinates into chart values
- `position(forX:)`, `position(forY:)`, and `position(for:)` for placing custom overlays or indicators
- `selectXValue(at:)`, `selectYValue(at:)`, `selectXRange(from:to:)`, and `selectYRange(from:to:)` for driving built-in selection from custom gestures
- `plotFrame` (iOS 17+) or `plotAreaFrame` (iOS 16) with `plotSize` for converting between gesture coordinates and the plot area

`select*` ChartProxy selection methods and `chartGesture` are available on iOS 17+.

## Modifier Scope

Apply chart-wide modifiers to the `Chart` container and mark-specific modifiers to the individual mark.

```swift
Chart(data) { item in
    LineMark(
        x: .value("Day", item.date),
        y: .value("Value", item.value)
    )
    .interpolationMethod(.monotone)   // Mark-level modifier
}
.chartXAxis { AxisMarks() }            // Chart-level modifier
.chartYScale(domain: 0...100)          // Chart-level modifier
.chartPlotStyle { $0.background(.thinMaterial) }
```

## Complete Examples

### Interactive Line Chart

```swift
import Charts
import SwiftUI

struct DailyStepsChart: View {
    let steps: [DailySteps]
    @State private var selectedDate: Date?

    var body: some View {
        Chart(steps) { day in
            LineMark(
                x: .value("Day", day.date),
                y: .value("Steps", day.count)
            )
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Day", day.date),
                y: .value("Steps", day.count)
            )

            if let selectedDate {
                RuleMark(x: .value("Selected Day", selectedDate))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) {
                AxisGridLine()
                AxisTick(length: .label)
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
        .chartYAxisLabel("Steps")
        .chartXSelection(value: $selectedDate)
    }
}
```

### Range-Selectable Bar Chart

```swift
import Charts
import SwiftUI

struct RevenueRangeChart: View {
    let weeks: [WeeklyRevenue]
    @State private var selectedWeeks: ClosedRange<Int>?

    var body: some View {
        Chart(weeks) { week in
            BarMark(
                x: .value("Week", week.index),
                y: .value("Revenue", week.revenue)
            )
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 8)
        .chartXSelection(range: $selectedWeeks)
    }
}
```

## Fallback Strategies

### Gate Advanced APIs by OS Version

```swift
if #available(iOS 17, *) {
    Chart(data) { item in
        LineMark(
            x: .value("X", item.x),
            y: .value("Y", item.y)
        )
    }
    .chartXSelection(value: $selectedX)
} else {
    Chart(data) { item in
        LineMark(
            x: .value("X", item.x),
            y: .value("Y", item.y)
        )
    }
}
```

### Version Breakdown

- iOS 16+: `Chart`, custom axes, scales, `BarMark`, `LineMark`, `AreaMark`, `PointMark`, `RectangleMark`, `RuleMark`
- iOS 17+: `SectorMark`, `chartXSelection`, `chartYSelection`, `chartAngleSelection`, `chartScrollableAxes`, visible-domain scrolling APIs
- iOS 18+: `AreaPlot`, `BarPlot`, `LinePlot`, `PointPlot`, `RectanglePlot`, `RulePlot`, `SectorPlot`

## Best Practices

### Do

- Use semantic `.value(_, _)` labels so axes and accessibility read clearly
- Prefer `Identifiable` models (or explicit `id:`) for stable chart data identity
- Use `RuleMark` for goals, thresholds, and selected-value indicators
- Use explicit `AxisMarks(values:)` when automatic tick generation gets crowded
- Use `chartXScale` and `chartYScale` when you need stable visual comparisons
- Use `chartXSelection(range:)` or `chartYSelection(range:)` for brushed selection
- Gate iOS 17+ APIs such as `SectorMark` and selection with `#available`

### Don't

- Put chart-wide modifiers such as `chartXAxis` or `chartXSelection` on individual marks
- Rely on unstable identities when chart data can be inserted, removed, or reordered
- Use string values for naturally numeric or date-based axes unless you want categorical behavior
- Stack unrelated series by default just because `BarMark` and `AreaMark` allow it
- Force every tick label to display when collision handling or stride values would be clearer
- Assume selection returns a model object; it only returns the plottable axis value
- Forget that range selection is available only for X and Y axes, not angle selection

## Checklist

- [ ] Deployment target matches the APIs used (`Chart` on iOS 16+, selection and `SectorMark` on iOS 17+)
- [ ] Chart data models use `Identifiable` (or `Chart(data, id:)` is provided)
- [ ] All chart families are represented with the correct mark type
- [ ] Axes use `AxisMarks` when default ticks are too dense or unclear
- [ ] `chartXScale` or `chartYScale` is set when fixed domains matter
- [ ] Chart-wide modifiers are applied to `Chart`, not individual marks
- [ ] Single-value selection uses `chartXSelection(value:)` or `chartYSelection(value:)`
- [ ] Range selection uses `chartXSelection(range:)` or `chartYSelection(range:)`
- [ ] `SectorMark` selection uses `chartAngleSelection(value:)`
- [ ] iOS 17+ and iOS 18+ APIs are guarded when needed
