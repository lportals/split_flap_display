# 🎞️ Split Flap Display

A high-performance, cinematic split-flap display component for Flutter. Built for developers who need **silky-smooth 60fps animations** and mechanical authenticity on Web, Mobile, and Desktop.

![Split Flap Demo](https://raw.githubusercontent.com/lportals/split_flap_display/main/assets/demo.gif)

🚀 **[Live Demo](https://flip-flap-display.vercel.app/)**

---

## ✨ Features

*   **⚡ Extreme Performance**: Engineered for Flutter Web (CanvasKit/WASM) using texture atlases.
*   **🔊 Procedural Audio**: A density-aware sound engine that mixes audio in real-time based on board activity.
*   **🎨 Cinematic Aesthetics**: Built-in glassmorphism, dynamic shading, and realistic 3D perspective.
*   **📱 Fully Responsive**: Adapts perfectly to any screen size, from mobile devices to large display boards.

---

## 🛠 The Optimization Story

Creating a split-flap display with dozens of characters is a deceptive performance trap. Naive implementations using individual widgets or multiple animation controllers quickly lead to GPU context loss and frame drops. 

This library solves these challenges through a **Low-Level Engineering** approach:

### 1. Single Controller Orchestration
Instead of having 50+ tickers running simultaneously, the entire row is driven by **one single `AnimationController`**. This orchestrator calculates the phase and progress for all active units in a single pass, drastically reducing CPU overhead.

### 2. Shared Sprite Sheets (Texture Atlas)
To avoid the cost of real-time text rendering and the risk of memory fragmentation, we pre-bake the entire character set into a **Single Texture Atlas** during warmup. 
*   **Zero per-frame allocations**: Rendering is reduced to simple `drawImageRect` calls.
*   **CanvasKit Stable**: Eliminates engine crashes on Flutter Web caused by texture overflow.

### 3. Bit-Efficient State Management
Board states are managed using **primitive integer arrays** (`_currentIndices`, `_targetIndices`). By avoiding heavy object-oriented state per character, the engine can update hundreds of units with near-zero latency.

### 4. Density-Aware Procedural Audio
Audio isn't just played; it's **computed**. The `FlapSoundManager` tracks the "Global Density" of the board to adjust volume and playback speed, creating a realistic "mechanical roar" when shuffling and crisp clicks when sparse.

---

## 📦 Getting Started

Add `split_flap_display` to your `pubspec.yaml`:

```yaml
dependencies:
  split_flap_display: ^0.1.0


## Usage

```dart
import 'package:split_flap_display/split_flap_display.dart';

// Initialize audio early
FlapSoundManager.instance.init();

// Use the widget
SplitFlapRow(
  text: 'HELLO',
  maxLength: 5,
  unitWidth: 20,
  unitHeight: 34,
  spacing: 2,
  textColor: Colors.amber,
)
```

## License
MIT License.
