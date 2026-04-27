---
name: swiftui-charts-3d
description: Create 3D data visualizations using Swift Charts. Use when the user wants to create a 3D chart, asks about Chart3D or SurfacePlot, needs interactive drag-to-rotate, or wants height-based surface coloring. Requires iOS 26 / macOS 26+.
metadata:
  author: rshankras
---

# 3D Charts with Swift Charts

Create 3D data visualizations using `Chart3D` and `SurfacePlot`. Covers math-driven surfaces, data-driven surfaces, interactive camera pose control, surface styling, and camera projection modes.

## When This Skill Activates

Use this skill when the user:
- Wants to create a 3D chart or 3D data visualization
- Asks about `Chart3D`, `SurfacePlot`, or 3D surface plots
- Needs to visualize a mathematical function as a 3D surface
- Wants interactive drag-to-rotate on a 3D chart
- Asks about 3D chart camera angles, pose, or projection
- Needs to style 3D surfaces with gradients or height-based coloring
- Wants to render multiple surfaces in a single 3D chart

## API Availability

| API | Minimum Version | Notes |
|-----|----------------|-------|
| `Chart3D` | iOS 26 / macOS 26 | Main 3D chart container |
| `SurfacePlot` | iOS 26 / macOS 26 | 3D surface mark |
| `Chart3DPose` | iOS 26 / macOS 26 | Viewing angle control |
| `Chart3DCameraProjection` | iOS 26 / macOS 26 | `.automatic`, `.perspective`, `.orthographic` |
| `Chart3DSurfaceStyle` | iOS 26 / macOS 26 | `.heightBased`, `.normalBased` |

## Quick Start

### Math-Driven Surface

```swift
import SwiftUI
import Charts

struct WaveSurfaceView: View {
    var body: some View {
        Chart3D {
            SurfacePlot(
                x: "X",
                y: "Height",
                z: "Z",
                function: { x, z in
                    sin(x) * cos(z)
                }
            )
            .foregroundStyle(.blue)
        }
    }
}
```

### Data-Driven Surface

```swift
struct DataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let z: Double
}

struct DataSurfaceView: View {
    let points: [DataPoint]

    var body: some View {
        Chart3D(points) { point in
            SurfacePlot(
                x: .value("X", point.x),
                y: .value("Height", point.y),
                z: .value("Z", point.z)
            )
        }
    }
}
```

### Interactive Rotation

```swift
struct InteractiveChartView: View {
    @State private var pose = Chart3DPose.default

    var body: some View {
        Chart3D {
            SurfacePlot(x: "X", y: "Height", z: "Z", function: { x, z in sin(x) * cos(z) })
                .foregroundStyle(.blue)
        }
        .chart3DPose($pose)
    }
}
```

## Surface Styling Patterns

### Height-Based Surface Style

```swift
SurfacePlot(x: "X", y: "Y", z: "Z", function: { x, z in sin(x) * cos(z) })
    .foregroundStyle(
        Chart3DSurfaceStyle.heightBased(
            Gradient(colors: [.blue, .cyan, .green, .yellow, .red]),
            yRange: -1...1
        )
    )
```

### Normal-Based Surface Style

```swift
SurfacePlot(x: "X", y: "Y", z: "Z", function: { x, z in sin(x) * cos(z) })
    .foregroundStyle(Chart3DSurfaceStyle.normalBased)
```

### Surface Roughness

```swift
SurfacePlot(...)
    .foregroundStyle(.blue)
    .roughness(0.3)  // 0 = reflective, 1 = matte
```

## Interactive Pose Control

### Preset Poses

```swift
.chart3DPose(.default)   // Standard 3/4 angle
.chart3DPose(.front)     // Viewing from front
.chart3DPose(.top)       // Top-down view
```

### Custom Pose

```swift
.chart3DPose(
    Chart3DPose(azimuth: .degrees(45), inclination: .degrees(30))
)
```

### Read-Only vs Interactive

```swift
// ✅ Read-only — user cannot rotate the chart
.chart3DPose(Chart3DPose.front)

// ✅ Interactive — user can drag to rotate
@State private var pose = Chart3DPose.default
.chart3DPose($pose)
```

## Camera Projection

```swift
.chart3DCameraProjection(.perspective)   // Objects farther away appear smaller (visual appeal)
.chart3DCameraProjection(.orthographic)  // No perspective distortion (scientific precision)
.chart3DCameraProjection(.automatic)     // System decides
```

## Top Mistakes

| # | Mistake | Fix |
|---|---------|-----|
| 1 | Forgetting to `import Charts` | Both `SwiftUI` and `Charts` imports are required |
| 2 | Using `.chart3DPose(.default)` and expecting drag-to-rotate | Use a `@State` binding: `.chart3DPose($pose)` |
| 3 | Setting `yRange` that does not cover actual function output | Match `yRange` to actual min/max of your function |
| 4 | Applying `.roughness()` without `.foregroundStyle()` | Set a foreground style first |
| 5 | Using orthographic projection for presentation contexts | Prefer `.perspective` for visual appeal |

## Review Checklist

- [ ] Both `import SwiftUI` and `import Charts` are present
- [ ] Deployment target is iOS 26 / macOS 26 or later
- [ ] `Chart3D` wraps all `SurfacePlot` content
- [ ] Axis labels are descriptive and meaningful
- [ ] `yRange` in `.heightBased()` matches actual output range
- [ ] Pose is `@State` binding if drag-to-rotate is intended
- [ ] Camera projection set appropriately
