# Habitera - Build habits. Shape your life.

A beautiful, offline-first habit tracking mobile app built with Flutter.

## Features

✨ **Core Features**
- Create, edit, and delete habits
- Daily check-in with one-tap completion
- Smooth micro-animations
- Undo completion
- Instant visual feedback (checkmark & progress ring)

📊 **Streaks & Progress**
- Current and longest streak tracking
- Weekly & monthly summaries
- Calm analytics dashboard
- Activity heatmap calendar (soft colors)

📱 **User Experience**
- Beautiful light & dark theme support
- System theme detection
- Smooth animations and transitions
- Thoughtful empty & loading states
- Large tap targets for accessibility

⚙️ **Customization**
- Habit frequencies: daily, weekly, custom
- Optional reminder times
- Custom colors and icons per habit
- Flexible scheduling

🔒 **Privacy & Data**
- No login required
- No accounts needed
- User owns all data
- Local-only storage
- Export/import as JSON
- Global notification toggle

## Tech Stack

- **Framework**: React Native with Expo
- **Navigation**: React Navigation
- **Storage**: AsyncStorage (offline-first)
- **Notifications**: Expo Notifications
- **Animations**: React Native Reanimated
- **Icons**: Feather Icons & custom emoji
- **Theme**: Custom color system with light/dark support

## Getting Started

### Prerequisites
- Node.js 16+ and npm/yarn
- Expo CLI: `npm install -g expo-cli`
- iOS/Android development environment (optional)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

3. Choose your platform:
   - Press `i` for iOS simulator
   - Press `a` for Android emulator
   - Scan QR code with Expo Go app on your phone

### Build for Production

```bash
# Build for iOS
eas build --platform ios

# Build for Android
eas build --platform android
```

## Project Structure

```
src/
├── components/        # Reusable UI components
├── context/          # React Context for state management
├── navigation/       # Navigation setup
├── screens/          # Screen components
├── services/         # Business logic (storage, analytics, notifications)
├── theme/            # Theme configuration and colors
├── types/            # TypeScript types
└── utils/            # Utility functions
```

## Key Components

### HabitCard
Displays individual habits with completion status, emoji icon, and color indicator.

### ProgressRing
Circular progress indicator showing daily completion percentage.

### CalendarHeatmap
Activity calendar with soft color gradient based on completion percentage.

### EmptyState
Beautiful empty state UI for new users and filtered views.

### StatCard
Display habit statistics with icons and custom styling.

## Data Structure

### Habit
```typescript
{
  id: string;
  title: string;
  description?: string;
  frequency: 'daily' | 'weekly' | 'custom';
  customDays?: number;
  color?: string;
  icon?: string;
  reminderTime?: string; // HH:mm format
  createdAt: number;
  archivedAt?: number;
}
```

### Completion
```typescript
{
  id: string;
  habitId: string;
  date: string; // YYYY-MM-DD
  completedAt: number;
}
```

## Theming

The app uses a soft, neutral color palette designed for calm interaction:

- **Neutral palette**: From pure white to dark charcoal
- **Accent colors**: 8 soft habit colors (red, orange, yellow, green, blue, purple, pink, teal)
- **Semantic colors**: Success (green), warning (orange), error (red), info (blue)

Themes are automatically persisted and support:
- Light mode
- Dark mode
- System default

## Analytics

The AnalyticsService provides:
- Current and longest streak calculation
- Daily completion percentage
- Weekly and monthly completion stats
- Activity heatmap data (3 months)
- Habit completion category classification

## Storage

All data is stored locally using AsyncStorage with these keys:
- `@habitera_app_data`: Habits and completions
- `@habitera_settings`: User preferences

## Notifications

Per-habit reminder notifications with:
- Daily scheduling at specified time
- Local notifications (no server required)
- Snooze functionality
- Global disable option

## Styling Philosophy

The app follows these design principles:
- **Calm**: Soft colors, subtle animations
- **Clean**: Minimal UI, clear hierarchy
- **Beautiful**: Premium feel, rounded corners, shadows
- **Encouraging**: Progress rings, streaks, positive feedback
- **Premium**: Consistent spacing, typography, elevation
- **User-friendly**: Large tap targets, clear affordances, smooth transitions

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

---

**Built with ❤️ for habit trackers everywhere**

*Build habits. Shape your life.*
