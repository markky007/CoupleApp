# 💑 Couple Quest

A gamified iOS app for couples to track daily chores, celebrate special events, and earn points to redeem rewards together.

## 🎯 Features

- **Authentication & Pairing**: Secure login and partner linking system
- **Shared Dashboard**: View point balances and upcoming events
- **Real-time Quest Board**: Create and complete quests with instant synchronization
- **Reward Shop**: Redeem points for couple rewards
- **Event Management**: Track anniversaries with countdown and notifications
- **Transaction History**: Complete audit trail of all point changes

## 🛠 Tech Stack

- **Platform**: iOS 16.0+
- **Language**: Swift 5+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Concurrency**: Swift async/await
- **Backend**: Supabase (PostgreSQL + Realtime)
- **Package Manager**: Swift Package Manager

## 📋 Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Supabase CLI (for local development)
- Node.js 18+ (for Supabase CLI)

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd couple-quest
```

### 2. Set Up Supabase Local Development

```bash
# Install Supabase CLI
npm install -g supabase

# Start local Supabase instance
supabase start

# Apply migrations
supabase db reset
```

### 3. Configure Supabase

Update `coupleapp/Core/SupabaseConfig.swift` with your Supabase credentials:

```swift
static let url = URL(string: "YOUR_SUPABASE_URL")!
static let anonKey = "YOUR_SUPABASE_ANON_KEY"
```

For local development, use:

- URL: `http://127.0.0.1:54321`
- Anon Key: (provided by `supabase start` command)

### 4. Open in Xcode

```bash
open coupleapp.xcodeproj
```

### 5. Build and Run

- Select a simulator or device
- Press `Cmd + R` to build and run

## 📁 Project Structure

```
coupleapp/
├── Core/               # Configuration and utilities
│   ├── SupabaseConfig.swift
│   └── AppConstants.swift
├── Models/             # Data models
│   ├── Profile.swift
│   ├── Quest.swift
│   ├── Reward.swift
│   ├── Event.swift
│   └── Transaction.swift
├── Services/           # Backend service layer
│   ├── AuthService.swift
│   ├── ProfileService.swift
│   ├── QuestService.swift
│   ├── RewardService.swift
│   ├── EventService.swift
│   ├── TransactionService.swift
│   └── NotificationService.swift
├── ViewModels/         # Business logic layer
│   ├── AuthViewModel.swift
│   ├── ProfileViewModel.swift
│   ├── QuestViewModel.swift
│   ├── RewardViewModel.swift
│   ├── EventViewModel.swift
│   └── DashboardViewModel.swift
└── Views/              # SwiftUI views
    ├── Authentication/
    ├── Dashboard/
    ├── Profile/
    ├── Quests/
    ├── Rewards/
    ├── Events/
    └── Components/
```

## 🗄 Database Schema

### Tables

- **profiles**: User profiles with point balances
- **events**: Special dates and anniversaries
- **quests**: Tasks and chores with point values
- **rewards**: Redeemable items from point shop
- **transactions**: Immutable audit trail of point changes

### Security

All tables use Row Level Security (RLS) policies to ensure:

- Users can only access their own data and their partner's data
- Point balances cannot be manipulated directly
- Transaction history is immutable

## 🧪 Testing

### Run Unit Tests

```bash
# In Xcode
Cmd + U
```

### Run Property-Based Tests

Property-based tests validate universal correctness properties:

- Point balance never goes negative
- Partner relationships are bidirectional
- Quest completion is idempotent
- Transactions are immutable

## 🔧 Build Verification

### Automated Build Check

```bash
# Verify build before committing
./scripts/verify-build.sh
```

### Fix Common Build Issues

```bash
# Interactive menu to fix common issues
./scripts/fix-common-issues.sh
```

### Manual Build Steps

1. **Clean Build Folder**: `Cmd + Shift + K` in Xcode
2. **Resolve Packages**: `File > Packages > Resolve Package Versions`
3. **Clean DerivedData**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
4. **Build**: `Cmd + B` in Xcode

### Build Checklist

See [BUILD_CHECKLIST.md](BUILD_CHECKLIST.md) for detailed guidelines on preventing build errors.

## 📱 Development Workflow

### Phase 1: Foundation & Authentication ✅

- [x] Project structure setup
- [x] Supabase configuration
- [ ] AuthService implementation
- [ ] Authentication views

### Phase 2: Profile & Partner Pairing

- [ ] Profile model and service
- [ ] Partner pairing logic
- [ ] Profile views

### Phase 3: Quest System

- [ ] Quest model and service
- [ ] Real-time synchronization
- [ ] Quest board UI

### Phase 4: Reward System

- [ ] Reward model and service
- [ ] Transaction history
- [ ] Reward shop UI

### Phase 5: Events & Notifications

- [ ] Event model and service
- [ ] Local notifications
- [ ] Event management UI

### Phase 6: Dashboard & Polish

- [ ] Unified dashboard
- [ ] UI polish and animations
- [ ] Error handling

### Phase 7: Testing & Optimization

- [ ] Property-based tests
- [ ] Integration tests
- [ ] Performance optimization

### Phase 8: Deployment

- [ ] App Store preparation
- [ ] Beta testing
- [ ] Production release

## 🔒 Security Best Practices

- Never commit Supabase service role key
- Use environment-specific configuration
- Implement proper input validation
- Follow RLS policy guidelines
- Regular security audits

## 📄 License

[Your License Here]

## 👥 Contributors

[Your Team Here]

## 📞 Support

For issues and questions, please open an issue on GitHub.

To install dependencies:

```bash
bun install
```

To run:

```bash
bun run index.ts
```

This project was created using `bun init` in bun v1.3.5. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.
