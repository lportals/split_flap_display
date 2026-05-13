# Split Flap Display

A high-performance, cinematic split-flap display component for Flutter.

![Split Flap Demo](https://raw.githubusercontent.com/luisportal/split_flap_display/main/assets/demo.gif)

🚀 **[Live Demo](https://flip-flap-display.vercel.app/)**

## Features

* **High Performance**: Uses a single shared sprite sheet for rendering to avoid Engine context loss and ensure 60fps+ on Web/Mobile.
* **Procedural Audio**: Density-aware sound engine that dynamically mixes clicks and a rain-loop based on active flap count.
* **Responsive Layouts**: Designed to look stunning across desktop, tablet, and mobile with glassmorphism styling.
* **Plug & Play**: Easy to integrate `SplitFlapRow` widget.

## Getting Started

To use this plugin, add `split_flap_display` as a dependency in your pubspec.yaml file.

```yaml
dependencies:
  split_flap_display: ^0.1.0
```

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
