# Implementation Plan: Additional Features Enhancement

## Overview

This implementation plan adds 4 major systems to the Couple Quest iOS app: Partner Pairing System, Profile Management, Theme System (Dark/Light Mode), and Localization System (Thai/English). The implementation follows a phased approach starting with database migrations, then service layers, data models, ViewModels, and finally UI components. All code will be written in Swift using SwiftUI + MVVM architecture with Supabase backend.

## Tasks

- [x] 1. Database Migration and Setup
  - Run database migration to add new columns to profiles table (username, partner_code, profile_picture_url, theme_preference, language_preference)
  - Create pairing_requests table with proper constraints and indexes
  - Create database functions (generate_partner_code, cleanup_old_pairing_requests, accept_pairing_request)
  - Set up Row Level Security policies for pairing_requests table
  - Create Supabase Storage bucket "profile-pictures" with proper policies
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 13.1_

- [ ] 2. Extend Profile Model
  - [x] 2.1 Add new fields to Profile struct
    - Add username, partnerCode, profilePictureUrl, themePreference, languagePreference fields
    - Update CodingKeys enum with snake_case mappings
    - _Requirements: 3.1, 3.2, 4.1, 5.1, 7.2, 9.2, 12.1_

  - [ ]\* 2.2 Write property test for Profile model extensions
    - **Property 28: Partner Code Service Extension**
    - **Validates: Requirements 12.7**

  - [x] 2.3 Add validation methods to Profile
    - Implement isValidUsername() static method (1-50 chars, alphanumeric + spaces/hyphens/underscores)
    - Implement isValidPartnerCode() static method (6-8 chars, alphanumeric only)
    - _Requirements: 3.3, 3.4, 1.2_

  - [ ]\* 2.4 Write property tests for Profile validation
    - **Property 2: Partner Code Format Validation**
    - **Property 10: Username Validation**
    - **Validates: Requirements 1.2, 3.3, 3.4**

- [ ] 3. Create PairingRequest Model
  - [x] 3.1 Implement PairingRequest struct
    - Define struct with id, requesterId, recipientId, status, createdAt, updatedAt
    - Add RequestStatus enum (pending, accepted, rejected)
    - Add CodingKeys for snake_case mapping
    - Add computed properties: requesterProfile, recipientProfile, isPending, isExpired
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

  - [ ]\* 3.2 Write property tests for PairingRequest model
    - **Property 25: Pairing Request Data Completeness**
    - **Property 27: Automatic Request Cleanup**
    - **Validates: Requirements 13.2, 13.8**

- [ ] 4. Implement PairingService
  - [x] 4.1 Create PairingService class with singleton pattern
    - Set up shared instance
    - Add Supabase client reference
    - Define PairingError enum with all error cases
    - _Requirements: 1.1, 13.1_

  - [x] 4.2 Implement partner code management methods
    - Implement generatePartnerCode(userId:) using database function
    - Implement findUserByPartnerCode(\_:) to query profiles table
    - _Requirements: 1.1, 1.2, 6.2_

  - [ ]\* 4.3 Write property tests for partner code generation
    - **Property 1: Partner Code Uniqueness**
    - **Property 2: Partner Code Format Validation**
    - **Validates: Requirements 1.1, 1.2, 6.2**

  - [x] 4.4 Implement pairing request management methods
    - Implement createPairingRequest(from:to:) with full validation
    - Implement fetchPendingRequests(userId:) to query requests
    - Implement acceptPairingRequest(requestId:) using database function
    - Implement rejectPairingRequest(requestId:) to update status
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 13.2, 13.3, 13.4, 13.6, 13.7_

  - [ ]\* 4.5 Write property tests for pairing request operations
    - **Property 3: Pairing Request Creation**
    - **Property 5: Pairing Request Rejection**
    - **Property 6: Self-Pairing Prevention**
    - **Property 7: Already-Paired Prevention**
    - **Property 26: Pairing Request Status Transitions**
    - **Validates: Requirements 1.3, 1.6, 1.7, 1.8, 13.7**

  - [x] 4.5 Implement pairing operations
    - Implement pairUsers(userId:partnerId:) for bidirectional pairing
    - Implement unpairUsers(userId:) for bidirectional unpairing
    - _Requirements: 1.5, 1.9, 2.1, 2.2, 2.3, 2.4_

  - [ ]\* 4.6 Write property tests for pairing operations
    - **Property 4: Bidirectional Partner Relationship**
    - **Property 8: Bidirectional Unpairing**
    - **Property 9: Re-pairing After Unpair**
    - **Validates: Requirements 1.5, 1.9, 2.3, 2.4, 2.5**

  - [x] 4.7 Implement real-time subscriptions
    - Implement subscribeToRequests(userId:handler:) for real-time updates
    - Implement unsubscribeFromRequests() to clean up subscriptions
    - _Requirements: 13.9, 13.10_

  - [ ]\* 4.8 Write unit tests for PairingService error handling
    - Test network error handling
    - Test validation error messages
    - Test edge cases (duplicate requests, expired requests)

- [x] 5. Checkpoint - Ensure pairing service tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement ThemeManager
  - [x] 6.1 Create ThemeManager class with ObservableObject
    - Set up shared instance with @MainActor
    - Define ThemeMode enum (light, dark, system) with display names and icons
    - Add @Published currentTheme property
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 6.2 Implement theme management methods
    - Implement setTheme(\_:) to update and persist theme
    - Implement loadSavedTheme() to load from UserDefaults
    - Implement getColorScheme() to return appropriate ColorScheme
    - _Requirements: 7.4, 7.5, 7.6, 8.1, 8.2_

  - [ ]\* 6.3 Write property tests for ThemeManager
    - **Property 15: Theme Mode Validation**
    - **Property 16: Theme Persistence Round-Trip**
    - **Property 17: Theme Independence from Auth**
    - **Property 18: System Theme Mode**
    - **Validates: Requirements 7.1, 7.4, 7.5, 7.6, 8.1, 8.2, 8.3**

  - [ ]\* 6.4 Write unit tests for ThemeManager
    - Test default theme is .system
    - Test theme changes trigger UI updates
    - Test invalid values fallback to .system

- [ ] 7. Implement LocalizationManager
  - [x] 7.1 Create LocalizationManager class with ObservableObject
    - Set up shared instance with @MainActor
    - Define Language enum (english, thai) with display names, flags, and locales
    - Add @Published currentLanguage property
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 7.2 Implement localization methods
    - Implement setLanguage(\_:) to update and persist language
    - Implement loadSavedLanguage() to load from UserDefaults
    - Implement localized(\_:) for string lookup with fallback
    - Implement localized(_:_:) for formatted strings with arguments
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 10.8_

  - [ ]\* 7.3 Write property tests for LocalizationManager
    - **Property 20: Language Mode Validation**
    - **Property 21: Language Persistence Round-Trip**
    - **Property 23: Locale-Specific Formatting**
    - **Property 24: Translation Fallback**
    - **Validates: Requirements 9.1, 9.4, 9.5, 9.7, 10.8**

  - [ ]\* 7.4 Write unit tests for LocalizationManager
    - Test default language is English
    - Test missing translations fallback to English
    - Test date/number formatting by locale

- [ ] 8. Create Localization Files
  - [x] 8.1 Create English Localizable.strings
    - Add all translation keys for pairing system (10 keys)
    - Add all translation keys for profile management (8 keys)
    - Add all translation keys for theme system (5 keys)
    - Add all translation keys for settings (6 keys)
    - Add all error message keys (15 keys)
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 8.2 Create Thai Localizable.strings
    - Translate all keys from English to Thai
    - Ensure all keys match English file
    - _Requirements: 10.6, 10.7_

  - [ ]\* 8.3 Write property test for translation completeness
    - **Property 22: Translation Key Completeness**
    - **Validates: Requirements 9.6, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7**

- [ ] 9. Extend AppTheme for Dark Mode
  - [x] 9.1 Add adaptive color properties to AppTheme
    - Add primaryBackground, secondaryBackground, tertiaryBackground
    - Add primaryText, secondaryText, tertiaryText
    - Add separator, cardBackground
    - Use Color(.systemBackground) and semantic colors
    - _Requirements: 7.7, 7.8_

  - [x] 9.2 Add dark mode gradient properties
    - Add primaryGradientDark, secondaryGradientDark, backgroundGradientDark
    - Implement adaptiveGradient(light:dark:) helper function
    - _Requirements: 7.7_

  - [ ]\* 9.3 Write property test for color contrast
    - **Property 19: Text Contrast Accessibility**
    - **Validates: Requirements 7.8**

  - [ ]\* 9.4 Write unit tests for AppTheme extensions
    - Test adaptive colors return different values in light/dark
    - Test semantic color names are consistent

- [x] 10. Checkpoint - Ensure theme and localization tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Extend ProfileService
  - [x] 11.1 Add partner code methods to ProfileService
    - Implement updatePartnerCode(userId:code:) to update profiles table
    - Implement fetchProfileByPartnerCode(\_:) to query by partner_code
    - _Requirements: 6.2, 6.3_

  - [x] 11.2 Add profile picture methods to ProfileService
    - Create ProfilePictureUpload helper struct with resizeImage() method
    - Implement uploadProfilePicture(userId:imageData:) with resize and upload
    - Implement deleteProfilePicture(userId:) to remove from Storage
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]\* 11.3 Write property tests for profile picture operations
    - **Property 13: Profile Picture Resize**
    - **Property 14: Profile Picture Storage Round-Trip**
    - **Validates: Requirements 5.4, 5.5, 5.6**

  - [x] 11.4 Add username methods to ProfileService
    - Implement updateUsername(userId:username:) with validation
    - Implement validateUsername(\_:) using Profile.isValidUsername()
    - _Requirements: 3.3, 3.4, 3.5, 3.6_

  - [ ]\* 11.5 Write property tests for username operations
    - **Property 11: Username Persistence**
    - **Property 12: Invalid Username Rejection**
    - **Validates: Requirements 3.5, 3.7**

  - [x] 11.6 Add preference methods to ProfileService
    - Implement updateThemePreference(userId:theme:) for database sync
    - Implement updateLanguagePreference(userId:language:) for database sync
    - _Requirements: 7.2, 9.2_

  - [ ]\* 11.7 Write unit tests for ProfileService extensions
    - Test all new methods work correctly
    - Test existing ProfileService methods still work (backward compatibility)

- [ ] 12. Implement PairingViewModel
  - [x] 12.1 Create PairingViewModel class
    - Set up @Published properties (partnerCode, pendingRequests, isLoading, errorMessage)
    - Add PairingService and ProfileService references
    - _Requirements: 1.1, 1.4, 13.5_

  - [x] 12.2 Implement partner code methods
    - Implement loadPartnerCode() to fetch or generate code
    - Implement copyPartnerCode() to copy to clipboard
    - _Requirements: 1.1, 1.2_

  - [x] 12.3 Implement pairing request methods
    - Implement sendPairingRequest(code:) with validation
    - Implement loadPendingRequests() to fetch requests
    - Implement acceptRequest(\_:) to accept pairing
    - Implement rejectRequest(\_:) to reject pairing
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 13.3, 13.4, 13.6_

  - [x] 12.4 Implement real-time subscription
    - Subscribe to pairing requests in init or onAppear
    - Update pendingRequests when new requests arrive
    - Clean up subscription in deinit
    - _Requirements: 13.9, 13.10_

  - [ ]\* 12.5 Write unit tests for PairingViewModel
    - Test state management
    - Test error handling
    - Test real-time updates

- [ ] 13. Implement SettingsViewModel
  - [x] 13.1 Create SettingsViewModel class
    - Set up @Published properties (currentTheme, currentLanguage, profile)
    - Add ThemeManager, LocalizationManager, ProfileService references
    - _Requirements: 7.3, 9.3, 11.1_

  - [x] 13.2 Implement theme methods
    - Implement changeTheme(\_:) to update ThemeManager
    - Bind currentTheme to ThemeManager.currentTheme
    - _Requirements: 7.3, 7.4, 8.1_

  - [x] 13.3 Implement language methods
    - Implement changeLanguage(\_:) to update LocalizationManager
    - Bind currentLanguage to LocalizationManager.currentLanguage
    - _Requirements: 9.3, 9.4_

  - [x] 13.4 Implement unpairing method
    - Implement unpairPartner() to call PairingService.unpairUsers()
    - Show confirmation dialog before unpairing
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ]\* 13.5 Write unit tests for SettingsViewModel
    - Test theme changes propagate correctly
    - Test language changes propagate correctly
    - Test unpairing updates state

- [ ] 14. Implement ProfileEditViewModel
  - [x] 14.1 Create ProfileEditViewModel class
    - Set up @Published properties (username, profileImage, isUploading, errorMessage)
    - Add ProfileService reference
    - _Requirements: 3.1, 4.1, 5.1_

  - [x] 14.2 Implement username editing
    - Implement updateUsername(\_:) with validation
    - Show inline validation errors
    - _Requirements: 3.3, 3.4, 3.5, 3.6, 3.7_

  - [x] 14.3 Implement profile picture editing
    - Implement selectProfilePicture() to show image picker
    - Implement uploadProfilePicture(\_:) with progress indicator
    - Implement deleteProfilePicture() to remove picture
    - _Requirements: 4.2, 4.3, 5.2, 5.3, 5.4_

  - [ ]\* 14.4 Write unit tests for ProfileEditViewModel
    - Test username validation
    - Test image upload flow
    - Test error handling

- [x] 15. Checkpoint - Ensure ViewModels tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 16. Create PairingView UI
  - [x] 16.1 Create PairingView SwiftUI view
    - Display user's partner code in large, copyable format
    - Add "Copy Code" button with haptic feedback
    - Add TextField for entering partner code
    - Add "Send Request" button with loading state
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 16.2 Add pending requests section
    - Display list of pending requests with requester info
    - Show requester username and profile picture
    - Add "Accept" and "Reject" buttons for each request
    - Show empty state when no requests
    - _Requirements: 1.4, 13.5_

  - [x] 16.3 Add paired partner section
    - Show partner's username and profile picture when paired
    - Add "Unpair" button with confirmation dialog
    - Show empty state when not paired
    - _Requirements: 1.5, 2.1, 2.2_

  - [x] 16.4 Add error handling and loading states
    - Show error alerts for pairing failures
    - Show loading indicators during operations
    - Disable buttons during loading
    - _Requirements: 1.7, 1.8_

  - [ ]\* 16.5 Write UI tests for PairingView
    - Test partner code display and copy
    - Test request sending flow
    - Test request acceptance/rejection
    - Test unpairing flow

- [ ] 17. Create SettingsView UI
  - [x] 17.1 Create SettingsView SwiftUI view
    - Use Form with sections for Theme, Language, Partner
    - Add navigation title and styling
    - _Requirements: 11.1, 11.2_

  - [x] 17.2 Add theme selection section
    - Display Picker with all ThemeMode options
    - Show icon and localized name for each option
    - Bind to SettingsViewModel.currentTheme
    - _Requirements: 7.3, 8.1, 11.3_

  - [x] 17.3 Add language selection section
    - Display Picker with all Language options
    - Show flag and display name for each option
    - Bind to SettingsViewModel.currentLanguage
    - _Requirements: 9.3, 11.4_

  - [x] 17.4 Add partner management section
    - Show "View Partner Code" navigation link to PairingView
    - Show "Unpair Partner" button when paired
    - Show confirmation dialog before unpairing
    - _Requirements: 2.1, 2.2, 11.5_

  - [x] 17.5 Add profile editing section
    - Show "Edit Profile" navigation link to ProfileEditView
    - _Requirements: 3.1, 4.1, 5.1_

  - [ ]\* 17.6 Write UI tests for SettingsView
    - Test theme switching updates UI
    - Test language switching updates text
    - Test navigation to other views

- [ ] 18. Create ProfileEditView UI
  - [x] 18.1 Create ProfileEditView SwiftUI view
    - Use Form with sections for Profile Picture and Username
    - Add navigation title and save button
    - _Requirements: 3.1, 4.1, 5.1_

  - [x] 18.2 Add profile picture section
    - Display current profile picture or placeholder
    - Add "Change Photo" button to show image picker
    - Add "Remove Photo" button when picture exists
    - Show upload progress indicator
    - _Requirements: 4.2, 4.3, 5.2, 5.3_

  - [x] 18.3 Add username editing section
    - Display TextField for username input
    - Show character count (1-50)
    - Show inline validation errors
    - Disable save button when invalid
    - _Requirements: 3.3, 3.4, 3.5, 3.6, 3.7_

  - [x] 18.4 Add save functionality
    - Implement save button to update profile
    - Show success message on save
    - Navigate back on success
    - _Requirements: 3.5, 5.5_

  - [ ]\* 18.5 Write UI tests for ProfileEditView
    - Test username validation
    - Test profile picture upload
    - Test save functionality

- [ ] 19. Integrate ThemeManager into App
  - [x] 19.1 Update coupleappApp.swift
    - Initialize ThemeManager.shared in init
    - Add .preferredColorScheme() modifier to root view
    - Bind to ThemeManager.shared.currentTheme.colorScheme
    - _Requirements: 7.5, 7.6, 8.2_

  - [x] 19.2 Update existing views to use adaptive colors
    - Replace hardcoded colors with AppTheme adaptive colors
    - Test all views in both light and dark mode
    - _Requirements: 7.7, 7.8_

  - [ ]\* 19.3 Write integration tests for theme system
    - Test theme persists across app launches
    - Test theme changes apply immediately
    - Test system theme follows iOS settings

- [ ] 20. Integrate LocalizationManager into App
  - [x] 20.1 Update coupleappApp.swift
    - Initialize LocalizationManager.shared in init
    - Add .environment() modifier to inject LocalizationManager
    - _Requirements: 9.5_

  - [x] 20.2 Update existing views to use localized strings
    - Replace hardcoded strings with LocalizationManager.shared.localized()
    - Update all button labels, titles, and messages
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_

  - [ ]\* 20.3 Write integration tests for localization system
    - Test language persists across app launches
    - Test language changes apply immediately
    - Test all keys have translations

- [ ] 21. Add Navigation to New Views
  - [x] 21.1 Update ContentView navigation
    - Add "Settings" tab or button to navigate to SettingsView
    - Add "Partner" tab or button to navigate to PairingView
    - _Requirements: 11.1, 11.2_

  - [x] 21.2 Update navigation styling
    - Apply adaptive colors to navigation bars
    - Ensure navigation works in both light and dark mode
    - _Requirements: 7.7_

- [ ] 22. Final Integration and Testing
  - [x] 22.1 Test complete pairing flow end-to-end
    - Test two users can pair successfully
    - Test real-time notifications work
    - Test unpairing works for both users
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3_

  - [x] 22.2 Test complete profile editing flow
    - Test username updates save correctly
    - Test profile picture uploads and displays
    - Test validation prevents invalid data
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 5.1, 5.2, 5.3_

  - [x] 22.3 Test theme system across all views
    - Test theme changes apply to all screens
    - Test theme persists across app restarts
    - Test accessibility in both modes
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 8.1, 8.2, 8.3_

  - [x] 22.4 Test localization across all views
    - Test language changes apply to all screens
    - Test all translations display correctly
    - Test date/number formatting by locale
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 10.1-10.8_

  - [ ]\* 22.5 Run all property-based tests
    - Run all 28 property tests with 100+ iterations each
    - Verify all properties hold across random inputs
    - Fix any failures discovered

  - [ ]\* 22.6 Run accessibility audit
    - Test VoiceOver support on all new screens
    - Test Dynamic Type support
    - Verify color contrast ratios
    - Test keyboard navigation

- [x] 23. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end flows across multiple components
- All code uses Swift with SwiftUI + MVVM architecture
- Backend uses Supabase (PostgreSQL, Storage, Realtime)
- Theme and language preferences stored in UserDefaults for instant access
- Profile data synced to database for cross-device consistency
- Real-time subscriptions ensure partners see updates immediately
