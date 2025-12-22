# Dish Planner 🍽️

A Flutter app to plan dish ingredients for events with bilingual support (English + Kannada) and PDF export.

## Features

- **Master Lists**: Manage ingredients and dishes with English + Kannada names
- **Dish Creation**: Create dishes with ingredients (baseline for 100 people)
- **Plan Mode**: 
  - Set global people count (applies to all dishes)
  - Override per-dish if needed
  - Automatic quantity scaling
- **PDF Export**:
  - Dish-wise PDF (separate sections per dish)
  - Overall combined PDF (merged ingredient totals)
  - Bilingual support (EN / KN / BOTH)
- **Backup/Restore**: Export/import data as JSON

## Screenshots

The app has 4 main screens:
1. **Home/Plan** - Add dishes, set people count, generate PDFs
2. **Masters** - Manage ingredients and dishes
3. **Create Dish** - Add dish with ingredients (for 100 people)
4. **Preview** - View scaled quantities before PDF generation

---

## Setup Instructions (Free, No Cost)

### Step 1: Install Flutter SDK

1. Download Flutter from: https://docs.flutter.dev/get-started/install
2. Extract to a folder (e.g., `~/development/flutter`)
3. Add Flutter to PATH:
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   export PATH="$HOME/development/flutter/bin:$PATH"
   ```
4. Restart terminal and verify:
   ```bash
   flutter doctor
   ```

### Step 2: Install Android Studio (for Android SDK)

1. Download from: https://developer.android.com/studio
2. Install and open Android Studio
3. Go to: **Settings > Languages & Frameworks > Android SDK**
4. Install at least one Android SDK (e.g., Android 13 / API 33)
5. Accept licenses:
   ```bash
   flutter doctor --android-licenses
   ```

### Step 3: Run the App

```bash
cd dish_planner
flutter pub get
flutter run
```

For release APK:
```bash
flutter build apk --release
```
APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## Build APK Without Local Setup (Using GitHub Actions)

### Option A: GitHub Actions (Free)

1. Create a GitHub repository
2. Push this code to GitHub
3. Add this file as `.github/workflows/build.yml`:

```yaml
name: Build APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build APK
        run: flutter build apk --release
      
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release
          path: build/app/outputs/flutter-apk/app-release.apk
```

4. Go to **Actions** tab in GitHub → download APK artifact

### Option B: Codemagic (Free tier: 500 build minutes/month)

1. Go to https://codemagic.io
2. Sign in with GitHub
3. Add your repository
4. Build → Download APK

---

## Data Model

### Ingredients (master list)
- `id`, `nameEn`, `nameKn`, `defaultUnit`

### Dishes (master list)
- `id`, `nameEn`, `nameKn`

### DishIngredients (link table)
- `dishId`, `ingredientId`, `qtyFor100`, `unit`

### Scaling Formula
```
scaledQty = qtyFor100 × (selectedPeople / 100)
```

Example: Rice = 10kg for 100 people → 50kg for 500 people

---

## Backup Format (JSON)

```json
{
  "version": 1,
  "exportedAt": "2025-12-22T10:30:00Z",
  "ingredients": [...],
  "dishes": [...],
  "dishIngredients": [...]
}
```

---

## Tech Stack

- **Flutter** 3.x
- **SQLite** (sqflite) for local storage
- **pdf** + **printing** for PDF generation
- **file_picker** + **share_plus** for backup/restore

---

## License

MIT License - Free to use and modify.

