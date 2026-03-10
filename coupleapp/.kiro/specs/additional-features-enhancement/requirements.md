# Requirements Document

## Introduction

เอกสารนี้กำหนดความต้องการสำหรับฟีเจอร์เพิ่มเติมของ Couple Quest iOS App ประกอบด้วย 4 ระบบหลัก: Partner Pairing System, Profile Management System, Theme System (Dark/Light Mode), และ Localization System (Thai/English) ฟีเจอร์เหล่านี้จะเพิ่มความสมบูรณ์ให้กับแอพพลิเคชันที่มีอยู่แล้ว โดยรักษา backward compatibility กับ database และ architecture ที่มีอยู่

## Glossary

- **User**: ผู้ใช้งานที่ลงทะเบียนและเข้าสู่ระบบแล้ว
- **Partner**: ผู้ใช้งานอีกคนหนึ่งที่เชื่อมต่อกับ User ผ่านระบบ pairing
- **Pairing_System**: ระบบที่จัดการการเชื่อมต่อระหว่าง User และ Partner
- **Profile_System**: ระบบที่จัดการข้อมูลส่วนตัวของ User
- **Theme_System**: ระบบที่จัดการรูปแบบการแสดงผล (Dark/Light Mode)
- **Localization_System**: ระบบที่จัดการภาษาที่แสดงในแอพพลิเคชัน
- **Partner_Code**: รหัสเฉพาะที่ใช้สำหรับการ pair กับ Partner
- **Pairing_Request**: คำขอเชื่อมต่อจาก User ไปยัง Partner
- **Theme_Preference**: การตั้งค่าธีมที่ User เลือก (dark, light, หรือ system)
- **Language_Preference**: การตั้งค่าภาษาที่ User เลือก (Thai หรือ English)
- **Profile_Picture**: รูปภาพโปรไฟล์ของ User
- **Display_Name**: ชื่อที่แสดงของ User ในแอพพลิเคชัน
- **Database_Schema**: โครงสร้างของฐานข้อมูล Supabase PostgreSQL
- **UserDefaults**: ระบบจัดเก็บข้อมูลการตั้งค่าบนอุปกรณ์ของ iOS

## Requirements

### Requirement 1: Partner Pairing with Code

**User Story:** ในฐานะ User ฉันต้องการเชื่อมต่อกับ Partner โดยใช้ Partner_Code เพื่อให้สามารถแชร์ quests และ rewards ร่วมกันได้

#### Acceptance Criteria

1. THE Pairing_System SHALL generate a unique Partner_Code for each User
2. THE Pairing_System SHALL ensure Partner_Code is 6-8 characters long and contains alphanumeric characters only
3. WHEN User enters a valid Partner_Code, THE Pairing_System SHALL send a Pairing_Request to the Partner
4. WHEN Partner receives a Pairing_Request, THE Pairing_System SHALL display the request with User's Display_Name
5. WHEN Partner accepts a Pairing_Request, THE Pairing_System SHALL create a bidirectional relationship in the Database_Schema
6. WHEN Partner rejects a Pairing_Request, THE Pairing_System SHALL remove the request and notify the User
7. IF User enters their own Partner_Code, THEN THE Pairing_System SHALL display an error message
8. IF User enters a Partner_Code of an already paired Partner, THEN THE Pairing_System SHALL display an error message
9. WHEN pairing is successful, THE Pairing_System SHALL update both User and Partner profiles with partner_id
10. THE Pairing_System SHALL display pairing status as "Paired" or "Unpaired" on the profile screen

### Requirement 2: Partner Unpairing

**User Story:** ในฐานะ User ฉันต้องการยกเลิกการเชื่อมต่อกับ Partner เพื่อให้สามารถ pair กับคนใหม่ได้

#### Acceptance Criteria

1. WHEN User is paired, THE Pairing_System SHALL display an unpair option
2. WHEN User initiates unpair, THE Pairing_System SHALL request confirmation
3. WHEN User confirms unpair, THE Pairing_System SHALL remove partner_id from both User and Partner profiles
4. WHEN unpair is successful, THE Pairing_System SHALL update the pairing status to "Unpaired"
5. WHEN unpair is successful, THE Pairing_System SHALL allow User to pair with a new Partner

### Requirement 3: Profile Display Name Management

**User Story:** ในฐานะ User ฉันต้องการแก้ไข Display_Name ของฉัน เพื่อให้ Partner เห็นชื่อที่ฉันต้องการ

#### Acceptance Criteria

1. THE Profile_System SHALL display current Display_Name on the profile screen
2. WHEN User taps edit Display_Name, THE Profile_System SHALL show an input field
3. THE Profile_System SHALL validate Display_Name is 1-50 characters long
4. THE Profile_System SHALL validate Display_Name contains no special characters except spaces, hyphens, and underscores
5. WHEN User saves a valid Display_Name, THE Profile_System SHALL update the Database_Schema
6. WHEN Display_Name update is successful, THE Profile_System SHALL display the new name immediately
7. IF Display_Name is invalid, THEN THE Profile_System SHALL display a validation error message

### Requirement 4: Profile Information Display

**User Story:** ในฐานะ User ฉันต้องการดูข้อมูลโปรไฟล์ของฉัน เพื่อให้ทราบสถานะและข้อมูลต่างๆ

#### Acceptance Criteria

1. THE Profile_System SHALL display User's Display_Name
2. THE Profile_System SHALL display User's email address
3. THE Profile_System SHALL display User's total_points
4. WHEN User is paired, THE Profile_System SHALL display Partner's Display_Name
5. WHEN User is unpaired, THE Profile_System SHALL display "No partner" message
6. THE Profile_System SHALL display User's Partner_Code for sharing

### Requirement 5: Profile Picture Upload (Optional Feature)

**User Story:** ในฐานะ User ฉันต้องการอัพโหลด Profile_Picture เพื่อให้โปรไฟล์ของฉันมีความเป็นส่วนตัวมากขึ้น

#### Acceptance Criteria

1. WHERE Profile_Picture feature is enabled, THE Profile_System SHALL display a placeholder image when no picture is uploaded
2. WHERE Profile_Picture feature is enabled, WHEN User taps the profile picture area, THE Profile_System SHALL show image picker options
3. WHERE Profile_Picture feature is enabled, THE Profile_System SHALL allow User to select an image from photo library or camera
4. WHERE Profile_Picture feature is enabled, WHEN User selects an image, THE Profile_System SHALL resize the image to 512x512 pixels maximum
5. WHERE Profile_Picture feature is enabled, WHEN User confirms the image, THE Profile_System SHALL upload it to Supabase Storage
6. WHERE Profile_Picture feature is enabled, WHEN upload is successful, THE Profile_System SHALL update the Database_Schema with the image URL
7. WHERE Profile_Picture feature is enabled, THE Profile_System SHALL display the uploaded Profile_Picture on the profile screen

### Requirement 6: Database Schema Extension for Profiles

**User Story:** ในฐานะ Developer ฉันต้องการขยาย Database_Schema เพื่อรองรับฟีเจอร์ใหม่

#### Acceptance Criteria

1. THE Database_Schema SHALL add a username column to profiles table
2. THE Database_Schema SHALL add a partner_code column to profiles table with unique constraint
3. THE Database_Schema SHALL add a profile_picture_url column to profiles table
4. THE Database_Schema SHALL add a theme_preference column to profiles table with default value "system"
5. THE Database_Schema SHALL add a language_preference column to profiles table with default value "en"
6. THE Database_Schema SHALL maintain backward compatibility with existing data
7. THE Database_Schema SHALL create an index on partner_code column for fast lookups

### Requirement 7: Theme System Implementation

**User Story:** ในฐานะ User ฉันต้องการเปลี่ยนธีมของแอพ เพื่อให้สบายตาในการใช้งาน

#### Acceptance Criteria

1. THE Theme_System SHALL support three theme modes: "light", "dark", and "system"
2. THE Theme_System SHALL use system theme as default Theme_Preference
3. WHEN User selects a theme mode, THE Theme_System SHALL apply the theme immediately
4. WHEN User selects a theme mode, THE Theme_System SHALL save Theme_Preference to UserDefaults
5. WHEN app launches, THE Theme_System SHALL load Theme_Preference from UserDefaults
6. WHEN Theme_Preference is "system", THE Theme_System SHALL follow iOS system appearance
7. THE Theme_System SHALL update all UI components to support both dark and light modes
8. THE Theme_System SHALL ensure text contrast ratios meet accessibility standards in both modes

### Requirement 8: Theme Persistence

**User Story:** ในฐานะ User ฉันต้องการให้แอพจำการตั้งค่าธีมของฉัน เพื่อไม่ต้องตั้งค่าใหม่ทุกครั้ง

#### Acceptance Criteria

1. WHEN User changes Theme_Preference, THE Theme_System SHALL persist the preference to UserDefaults
2. WHEN app is terminated and relaunched, THE Theme_System SHALL restore the saved Theme_Preference
3. WHEN User logs out, THE Theme_System SHALL retain Theme_Preference for the next login
4. THE Theme_System SHALL sync Theme_Preference across app restarts within 100 milliseconds

### Requirement 9: Localization System Implementation

**User Story:** ในฐานะ User ฉันต้องการเปลี่ยนภาษาของแอพ เพื่อให้เข้าใจเนื้อหาได้ดีขึ้น

#### Acceptance Criteria

1. THE Localization_System SHALL support two languages: Thai and English
2. THE Localization_System SHALL use English as default Language_Preference
3. WHEN User selects a language, THE Localization_System SHALL apply the language immediately to all UI text
4. WHEN User selects a language, THE Localization_System SHALL save Language_Preference to UserDefaults
5. WHEN app launches, THE Localization_System SHALL load Language_Preference from UserDefaults
6. THE Localization_System SHALL translate all user-facing text including buttons, labels, error messages, and placeholders
7. THE Localization_System SHALL format dates and numbers according to the selected language locale

### Requirement 10: Localization Content Completeness

**User Story:** ในฐานะ User ฉันต้องการให้ทุกส่วนของแอพแสดงภาษาที่ฉันเลือก เพื่อความสอดคล้องในการใช้งาน

#### Acceptance Criteria

1. THE Localization_System SHALL provide translations for all authentication screens
2. THE Localization_System SHALL provide translations for all quest management screens
3. THE Localization_System SHALL provide translations for all reward screens
4. THE Localization_System SHALL provide translations for all profile screens
5. THE Localization_System SHALL provide translations for all settings screens
6. THE Localization_System SHALL provide translations for all error messages
7. THE Localization_System SHALL provide translations for all success messages
8. IF a translation is missing, THEN THE Localization_System SHALL display the English text as fallback

### Requirement 11: Settings Screen

**User Story:** ในฐานะ User ฉันต้องการหน้าจอ Settings เพื่อจัดการการตั้งค่าต่างๆ ในที่เดียว

#### Acceptance Criteria

1. THE Profile_System SHALL provide a Settings screen accessible from the profile screen
2. THE Settings screen SHALL display Theme_Preference selection with three options
3. THE Settings screen SHALL display Language_Preference selection with two options
4. THE Settings screen SHALL display current app version
5. THE Settings screen SHALL provide a logout button
6. WHEN User changes settings, THE Settings screen SHALL apply changes immediately
7. THE Settings screen SHALL display all options in the selected Language_Preference

### Requirement 12: Profile Service Extension

**User Story:** ในฐานะ Developer ฉันต้องการขยาย ProfileService เพื่อรองรับฟีเจอร์ใหม่

#### Acceptance Criteria

1. THE Profile_System SHALL extend ProfileService to support Partner_Code generation
2. THE Profile_System SHALL extend ProfileService to support Partner_Code lookup
3. THE Profile_System SHALL extend ProfileService to support Profile_Picture upload
4. THE Profile_System SHALL extend ProfileService to support Display_Name update with validation
5. THE Profile_System SHALL extend ProfileService to support theme preference updates
6. THE Profile_System SHALL extend ProfileService to support language preference updates
7. THE Profile_System SHALL maintain existing ProfileService functionality without breaking changes

### Requirement 13: Pairing Request Management

**User Story:** ในฐานะ User ฉันต้องการเห็นและจัดการ Pairing_Request ที่ได้รับ เพื่อควบคุมว่าจะ pair กับใคร

#### Acceptance Criteria

1. THE Pairing_System SHALL create a pairing_requests table in Database_Schema
2. THE Pairing_System SHALL store Pairing_Request with requester_id, recipient_id, status, and timestamps
3. WHEN User receives a Pairing_Request, THE Pairing_System SHALL send a notification
4. THE Pairing_System SHALL display pending Pairing_Request on the profile screen
5. WHEN User views a Pairing_Request, THE Pairing_System SHALL show requester's Display_Name
6. THE Pairing_System SHALL allow User to accept or reject the request
7. WHEN Pairing_Request is accepted or rejected, THE Pairing_System SHALL update the request status
8. THE Pairing_System SHALL automatically delete Pairing_Request older than 7 days

### Requirement 14: AppTheme Extension for Dark Mode

**User Story:** ในฐานะ Developer ฉันต้องการอัพเดท AppTheme.swift เพื่อรองรับ Dark Mode อย่างสมบูรณ์

#### Acceptance Criteria

1. THE Theme_System SHALL define color sets for both light and dark modes in AppTheme.swift
2. THE Theme_System SHALL use SwiftUI Color with adaptive colors
3. THE Theme_System SHALL define primary, secondary, background, and text colors for both modes
4. THE Theme_System SHALL ensure all custom colors adapt to the selected theme
5. THE Theme_System SHALL provide semantic color names (e.g., primaryBackground, secondaryText)
6. THE Theme_System SHALL test color contrast ratios to ensure readability in both modes

### Requirement 15: Localization File Structure

**User Story:** ในฐานะ Developer ฉันต้องการโครงสร้างไฟล์ Localization ที่เป็นระเบียบ เพื่อง่ายต่อการบำรุงรักษา

#### Acceptance Criteria

1. THE Localization_System SHALL create Localizable.strings files for Thai and English
2. THE Localization_System SHALL organize translation keys by feature (e.g., auth.login, profile.edit)
3. THE Localization_System SHALL use dot notation for nested keys
4. THE Localization_System SHALL provide comments in Localizable.strings for context
5. THE Localization_System SHALL validate that all keys exist in both language files
6. THE Localization_System SHALL use String catalogs (if iOS 16+) for better Xcode integration
