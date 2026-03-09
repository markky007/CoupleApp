# Implementation Plan: Couple Quest iOS Application

## Overview

This implementation plan breaks down the Couple Quest iOS application into 8 sequential phases, from foundation setup through deployment. Each task builds incrementally on previous work, with checkpoints to ensure quality and correctness. The app uses SwiftUI with MVVM architecture and Supabase for backend services.

## Tasks

- [ ] 1. Phase 1: Foundation & Authentication
  - [x] 1.1 Initialize project structure and configure Supabase
    - Create Xcode project with SwiftUI and minimum iOS 16.0 deployment target
    - Add Supabase Swift SDK via Swift Package Manager (version 2.0.0+)
    - Create SupabaseConfig.swift with client initialization
    - Set up folder structure: Models/, Services/, Views/, ViewModels/
    - _Requirements: System architecture, authentication foundation_

  - [x] 1.2 Implement AuthService with session management
    - Create AuthService.swift as @MainActor ObservableObject singleton
    - Implement signUp(email:password:) async throws method
    - Implement signIn(email:password:) async throws method
    - Implement signOut() async throws method
    - Implement resetPassword(email:) async throws method
    - Add @Published session property with auth state listener
    - _Requirements: User authentication, session persistence_

  - [x] 1.3 Create authentication views and navigation
    - Create LoginView with email/password fields and sign in button
    - Create SignUpView with email/password fields and sign up button
    - Create ForgotPasswordView for password reset flow
    - Implement AuthViewModel to handle auth business logic
    - Add form validation and error display
    - Create main navigation structure (ContentView) with authenticated/unauthenticated routing
    - _Requirements: User interface, authentication flow_

  - [ ]\* 1.4 Write unit tests for AuthService
    - Test successful sign up with valid credentials
    - Test sign in with correct credentials
    - Test sign in failure with incorrect credentials
    - Test sign out clears session state
    - Test session persistence across app launches
    - _Requirements: Authentication correctness_

  - [x] 1.5 Checkpoint - Verify authentication flow
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 2. Phase 2: Profile & Partner Pairing
  - [x] 2.1 Create Profile model and ProfileService
    - Create Profile.swift model with Codable conformance
    - Create ProfileService.swift with CRUD operations
    - Implement fetchProfile(userId:) async throws method
    - Implement createProfile(userId:displayName:) async throws method
    - Implement updateDisplayName(userId:newName:) async throws method
    - Implement pairWithPartner(userId:partnerId:) async throws method
    - Implement updatePoints(userId:delta:) async throws method
    - _Requirements: Profile management, data models_

  - [x] 2.2 Set up database RLS policies in Supabase
    - Create RLS policy: Users can view own and partner profile
    - Create RLS policy: Users can update own profile only
    - Create RLS policy: Prevent unauthorized profile access
    - Test RLS policies with different user scenarios
    - _Requirements: Data security, access control_

  - [x] 2.3 Implement profile views and partner pairing UI
    - Create ProfileView to display user profile and partner info
    - Create ProfileViewModel with profile state management
    - Add display name editing functionality
    - Create PairingView with partner ID input field
    - Implement pairing confirmation flow
    - Add error handling for pairing failures
    - _Requirements: Profile UI, partner pairing interface_

  - [ ]\* 2.4 Write property test for bidirectional partner relationship
    - **Property 2: Bidirectional Partner Relationship**
    - **Validates: Partner relationships are always bidirectional**
    - Test that if user A pairs with user B, then B.partnerId == A.id and A.partnerId == B.id
    - _Requirements: Partner pairing correctness_

  - [ ]\* 2.5 Write unit tests for ProfileService
    - Test profile creation with valid data
    - Test profile fetch returns correct data
    - Test partner pairing creates bidirectional relationship
    - Test pairing fails when user already paired
    - Test point update increases/decreases balance correctly
    - Test point update fails when result would be negative
    - _Requirements: Profile service correctness_

  - [x] 2.6 Checkpoint - Verify profile and pairing functionality
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 3. Phase 3: Quest System
  - [x] 3.1 Create Quest model and QuestService
    - Create Quest.swift model with QuestStatus enum
    - Create QuestService.swift with quest operations
    - Implement fetchActiveQuests() async throws method
    - Implement createQuest(title:points:createdBy:eventId:expireAt:) async throws method
    - Implement completeQuest(questId:userId:) async throws method
    - Implement deleteQuest(questId:) async throws method
    - Add quest expiration filtering logic
    - _Requirements: Quest management, data models_

  - [x] 3.2 Implement quest completion workflow with atomic operations
    - Create database transaction for quest completion
    - Update quest status to 'completed'
    - Award points to user using ProfileService.updatePoints
    - Create transaction record via TransactionService
    - Ensure all operations succeed or rollback on failure
    - _Requirements: Quest completion, point awarding, atomicity_

  - [x] 3.3 Set up realtime subscription for quest synchronization
    - Implement subscribeToQuestChanges(handler:) async throws method
    - Subscribe to quests table INSERT, UPDATE, DELETE events
    - Handle realtime updates on main thread for UI safety
    - Implement subscription cleanup on view dismissal
    - Add reconnection logic with exponential backoff
    - _Requirements: Real-time synchronization, quest board updates_

  - [x] 3.4 Create quest board UI with realtime updates
    - Create QuestBoardView with LazyVStack for quest list
    - Create QuestRowView component for individual quests
    - Create QuestViewModel with @Published quests array
    - Implement pull-to-refresh functionality
    - Add quest creation sheet with form validation
    - Display loading states and empty states
    - _Requirements: Quest UI, user interaction_

  - [x] 3.5 Set up RLS policies for quests
    - Create RLS policy: Users can view quests created by themselves or partner
    - Create RLS policy: Users can complete quests (UPDATE status only)
    - Create RLS policy: Users can create quests
    - Test RLS policies with different user scenarios
    - _Requirements: Quest security, access control_

  - [ ]\* 3.6 Write property test for quest completion idempotency
    - **Property 3: Quest Completion Idempotency**
    - **Validates: Completed quests cannot be completed again**
    - Test that completing a quest multiple times only awards points once
    - _Requirements: Quest completion correctness_

  - [ ]\* 3.7 Write property test for active quest filtering
    - **Property 9: Active Quest Filtering**
    - **Validates: Active quests have pending status and valid expiration**
    - Test that fetchActiveQuests only returns pending, non-expired quests
    - _Requirements: Quest filtering correctness_

  - [ ]\* 3.8 Write unit tests for QuestService
    - Test quest creation with valid parameters
    - Test fetch active quests excludes completed and expired
    - Test quest completion updates status and awards points
    - Test quest completion fails for already completed quest
    - Test quest completion creates transaction record
    - Test expired quests are filtered from active list
    - _Requirements: Quest service correctness_

  - [x] 3.9 Checkpoint - Verify quest system functionality
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Phase 4: Reward System & Transaction History
  - [x] 4.1 Create Reward and Transaction models
    - Create Reward.swift model with Codable conformance
    - Create Transaction.swift model with TransactionType enum
    - Define validation rules for both models
    - _Requirements: Reward and transaction data models_

  - [x] 4.2 Implement RewardService
    - Create RewardService.swift with reward operations
    - Implement fetchActiveRewards() async throws method
    - Implement createReward(title:pointsCost:) async throws method
    - Implement redeemReward(rewardId:userId:) async throws method
    - Implement toggleRewardActive(rewardId:isActive:) async throws method
    - Add balance validation before redemption
    - _Requirements: Reward management, redemption logic_

  - [x] 4.3 Implement reward redemption workflow with atomic operations
    - Create database transaction for reward redemption
    - Validate user has sufficient points
    - Deduct points using ProfileService.updatePoints
    - Create transaction record with type='redeem'
    - Ensure all operations succeed or rollback on failure
    - _Requirements: Reward redemption, point deduction, atomicity_

  - [x] 4.4 Implement TransactionService
    - Create TransactionService.swift with transaction queries
    - Implement fetchUserTransactions(userId:limit:) async throws method
    - Implement fetchPartnerTransactions(userId:partnerId:limit:) async throws method
    - Implement createTransaction(userId:type:amount:description:) async throws method
    - Add pagination support for transaction history
    - _Requirements: Transaction history, audit trail_

  - [x] 4.5 Create reward shop UI
    - Create RewardShopView with LazyVStack for reward list
    - Create RewardRowView component showing title and cost
    - Create RewardViewModel with @Published rewards array
    - Implement reward redemption confirmation dialog
    - Display user's current point balance
    - Add error handling for insufficient points
    - _Requirements: Reward UI, redemption interface_

  - [x] 4.6 Create transaction history UI
    - Create TransactionHistoryView with transaction list
    - Create TransactionRowView showing type, amount, description, date
    - Implement filtering by transaction type (earn/redeem)
    - Add pull-to-refresh functionality
    - Display combined history for both partners
    - _Requirements: Transaction history UI_

  - [x] 4.7 Set up RLS policies for rewards and transactions
    - Create RLS policy: All users can view active rewards
    - Create RLS policy: Users can only view their own transactions
    - Create RLS policy: Transactions are immutable after creation
    - Test RLS policies with different user scenarios
    - _Requirements: Reward and transaction security_

  - [ ]\* 4.8 Write property test for point balance non-negativity
    - **Property 1: Point Balance Integrity**
    - **Validates: User point balances never go negative**
    - Test that all point-modifying operations maintain non-negative balance
    - _Requirements: Point system integrity_

  - [ ]\* 4.9 Write property test for sufficient balance for redemption
    - **Property 8: Sufficient Balance for Redemption**
    - **Validates: Redemptions only succeed with sufficient points**
    - Test that redemption fails when user.totalPoints < reward.pointsCost
    - _Requirements: Redemption validation_

  - [ ]\* 4.10 Write property test for atomic reward redemption
    - **Property 7: Atomic Reward Redemption**
    - **Validates: Redemption is atomic (points deducted and transaction created together)**
    - Test that failed redemptions leave no partial state
    - _Requirements: Redemption atomicity_

  - [ ]\* 4.11 Write unit tests for RewardService and TransactionService
    - Test reward redemption with sufficient balance
    - Test redemption fails with insufficient balance
    - Test redemption deducts correct point amount
    - Test redemption creates transaction record
    - Test fetch active rewards excludes inactive rewards
    - Test transaction history queries return correct data
    - _Requirements: Reward and transaction service correctness_

  - [x] 4.12 Checkpoint - Verify reward system and transaction history
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Phase 5: Events & Notifications
  - [x] 5.1 Create Event model and EventService
    - Create Event.swift model with Codable conformance
    - Create EventService.swift with event operations
    - Implement fetchUpcomingEvents() async throws method
    - Implement createEvent(title:eventDate:isRecurring:) async throws method
    - Implement updateEvent(eventId:title:eventDate:isRecurring:) async throws method
    - Implement deleteEvent(eventId:) async throws method
    - Implement calculateDaysUntil(event:) -> Int method
    - _Requirements: Event management, countdown calculations_

  - [x] 5.2 Implement NotificationService
    - Create NotificationService.swift with notification operations
    - Implement requestAuthorization() async throws -> Bool method
    - Implement scheduleEventReminder(event:daysBeforeArray:) async throws method
    - Implement cancelEventReminder(eventId:) async throws method
    - Implement cancelAllNotifications() async method
    - Implement getPendingNotifications() async -> [UNNotificationRequest] method
    - _Requirements: Local notifications, event reminders_

  - [x] 5.3 Create event management UI
    - Create EventListView with upcoming events sorted by date
    - Create EventRowView showing title, date, and days until
    - Create EventViewModel with @Published events array
    - Implement event creation sheet with date picker
    - Add recurring event toggle
    - Display countdown for each event
    - _Requirements: Event UI, event creation interface_

  - [x] 5.4 Integrate notifications with event lifecycle
    - Request notification permission on first event creation
    - Schedule notifications (3 days and 1 day before) when event created
    - Cancel notifications when event deleted
    - Reschedule notifications when event date updated
    - Handle notification permission denial gracefully
    - _Requirements: Notification integration, event lifecycle_

  - [x] 5.5 Set up RLS policies for events
    - Create RLS policy: Users can view events created by themselves or partner
    - Create RLS policy: Users can create, update, delete their own events
    - Test RLS policies with different user scenarios
    - _Requirements: Event security, access control_

  - [ ]\* 5.6 Write property test for notification scheduling validity
    - **Property 11: Notification Scheduling Validity**
    - **Validates: Scheduled notifications have future trigger dates before event date**
    - Test that all scheduled notifications meet date constraints
    - _Requirements: Notification scheduling correctness_

  - [ ]\* 5.7 Write unit tests for EventService and NotificationService
    - Test event creation with valid date
    - Test calculateDaysUntil returns correct value for future events
    - Test calculateDaysUntil returns 0 for today
    - Test calculateDaysUntil returns negative for past events
    - Test recurring events show next occurrence
    - Test notification scheduling for future events
    - Test notification scheduling skips past dates
    - Test notification cancellation removes pending notifications
    - _Requirements: Event and notification service correctness_

  - [x] 5.8 Checkpoint - Verify event and notification functionality
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Phase 6: Dashboard & Polish
  - [ ] 6.1 Create unified dashboard view
    - Create DashboardView as main authenticated screen
    - Display point balances for user and partner
    - Show upcoming event countdown widget
    - Display recent quests (last 5)
    - Show available rewards preview
    - Add navigation to all major sections
    - _Requirements: Dashboard UI, information architecture_

  - [ ] 6.2 Implement dashboard ViewModel with data aggregation
    - Create DashboardViewModel with all required data
    - Fetch profile, quests, events, rewards on load
    - Subscribe to realtime updates for all data types
    - Implement pull-to-refresh for all data
    - Add loading states and error handling
    - _Requirements: Dashboard business logic, data aggregation_

  - [ ] 6.3 Add UI polish and animations
    - Implement smooth view transitions with .transition() modifiers
    - Add haptic feedback for button taps and completions
    - Create skeleton loading screens for initial loads
    - Add success animations for quest completion and redemption
    - Implement swipe gestures for quest completion
    - Polish color scheme and typography
    - _Requirements: User experience, visual polish_

  - [ ] 6.4 Implement comprehensive error handling
    - Create centralized error alert system
    - Add user-friendly error messages for all error types
    - Implement retry logic for transient failures
    - Add offline mode indicators
    - Display connection status in UI
    - Log errors for debugging
    - _Requirements: Error handling, user feedback_

  - [ ] 6.5 Add empty states and onboarding
    - Create empty state views for quests, rewards, events
    - Add onboarding flow for new users
    - Create tutorial tooltips for key features
    - Implement first-time user experience
    - _Requirements: User onboarding, empty states_

  - [ ] 6.6 Checkpoint - Verify dashboard and polish
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Phase 7: Testing & Optimization
  - [ ]\* 7.1 Write property test for transaction immutability
    - **Property 4: Transaction Immutability**
    - **Validates: Transaction records are never modified after creation**
    - Test that transactions cannot be updated or deleted
    - _Requirements: Transaction audit trail integrity_

  - [ ]\* 7.2 Write property test for point change traceability
    - **Property 5: Point Change Traceability**
    - **Validates: Every point change has corresponding transaction**
    - Test that sum of transactions equals current balance
    - _Requirements: Point system audit trail_

  - [ ]\* 7.3 Write property test for atomic quest completion
    - **Property 6: Atomic Quest Completion**
    - **Validates: Quest completion is atomic (all or nothing)**
    - Test that failed completions leave no partial state
    - _Requirements: Quest completion atomicity_

  - [ ]\* 7.4 Write property test for realtime consistency
    - **Property 10: Realtime Consistency**
    - **Validates: Data changes propagate to subscribed clients within 100ms**
    - Test realtime update delivery time
    - _Requirements: Real-time synchronization performance_

  - [ ]\* 7.5 Write property test for transaction amount consistency
    - **Property 13: Transaction Amount Consistency**
    - **Validates: Earn transactions positive, redeem transactions negative**
    - Test transaction amount signs match transaction types
    - _Requirements: Transaction data integrity_

  - [ ]\* 7.6 Write integration tests for end-to-end flows
    - Test complete authentication flow
    - Test complete quest workflow (create → complete → verify points)
    - Test reward redemption flow
    - Test partner pairing and synchronization
    - Test event notification flow
    - Test database transaction integrity
    - _Requirements: End-to-end functionality_

  - [ ] 7.7 Perform performance optimization
    - Profile app with Instruments (Time Profiler, Allocations)
    - Optimize database queries with proper indexes
    - Implement caching strategy for profile and quest data
    - Optimize realtime subscription management
    - Reduce network requests with batching
    - Ensure 60 FPS scrolling in all lists
    - _Requirements: Performance targets, responsiveness_

  - [ ] 7.8 Conduct security audit
    - Review all RLS policies for correctness
    - Test unauthorized access scenarios
    - Verify point system cannot be manipulated
    - Check for SQL injection vulnerabilities
    - Validate input sanitization
    - Test session security and expiration
    - _Requirements: Security, data protection_

  - [ ] 7.9 Fix bugs and edge cases
    - Test app with poor network conditions
    - Test concurrent operations (multiple devices)
    - Test edge cases (empty data, maximum values)
    - Fix any crashes or unexpected behavior
    - Test on different iOS versions and devices
    - _Requirements: Stability, edge case handling_

  - [ ] 7.10 Checkpoint - Verify testing and optimization complete
    - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Phase 8: Deployment & Documentation
  - [ ] 8.1 Configure production Supabase project
    - Create production Supabase project
    - Set up production database with migrations
    - Configure RLS policies in production
    - Set up environment-specific configuration
    - Test production backend thoroughly
    - _Requirements: Production environment, backend setup_

  - [ ] 8.2 Prepare app for App Store submission
    - Create app icons in all required sizes
    - Design launch screen
    - Configure app metadata (name, description, keywords)
    - Create App Store screenshots (6.7", 6.5", 5.5")
    - Write app description and release notes
    - Set up App Store Connect account
    - _Requirements: App Store assets, metadata_

  - [ ] 8.3 Configure app signing and provisioning
    - Create App ID in Apple Developer Portal
    - Configure app capabilities (Push Notifications if needed)
    - Create distribution certificate and provisioning profile
    - Configure Xcode project with signing settings
    - _Requirements: Code signing, distribution_

  - [ ] 8.4 Submit app for TestFlight beta testing
    - Archive app build in Xcode
    - Upload build to App Store Connect
    - Configure TestFlight testing information
    - Invite beta testers
    - Gather feedback from beta testers
    - _Requirements: Beta testing, user feedback_

  - [ ] 8.5 Create user documentation
    - Write user guide covering all features
    - Create FAQ document
    - Write privacy policy
    - Write terms of service
    - Create in-app help content
    - _Requirements: User documentation, legal documents_

  - [ ] 8.6 Create developer documentation
    - Document architecture and design decisions
    - Write API documentation for services
    - Create setup guide for development environment
    - Document database schema and RLS policies
    - Write contribution guidelines
    - _Requirements: Developer documentation, maintainability_

  - [ ] 8.7 Set up analytics and monitoring
    - Configure Supabase Analytics (or alternative)
    - Set up error tracking and crash reporting
    - Implement usage analytics for key features
    - Create monitoring dashboard
    - Set up alerts for critical issues
    - _Requirements: Analytics, monitoring, observability_

  - [ ] 8.8 Submit app for App Store review
    - Complete App Store Connect submission form
    - Submit app for review
    - Respond to any review feedback
    - Monitor review status
    - Prepare for launch
    - _Requirements: App Store submission, launch readiness_

  - [ ] 8.9 Final checkpoint - Deployment complete
    - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional testing tasks and can be skipped for faster MVP
- Each phase builds on previous phases - complete phases sequentially
- Checkpoints ensure quality and provide opportunities for user feedback
- Property tests validate universal correctness properties from design document
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end workflows
- All tasks reference specific requirements and design specifications
- Estimated timeline: 8 weeks for single developer working full-time
