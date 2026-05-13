#!/bin/bash

# 1. Download Flutter
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi

# 2. Add to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Enable Web
flutter config --enable-web

# 4. Navigate to example project and build
cd example
flutter pub get
flutter build web --release --base-href / --wasm
