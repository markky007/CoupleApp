# Requirements Document

## Introduction

The Partner-Approved Reward Creation feature enables users to create custom rewards that require partner approval before becoming active. This feature adds personalization to the reward system while maintaining couple collaboration and ensuring both partners agree on rewards before they become redeemable. The feature extends the existing reward system in the Couple Quest iOS app to support user-generated content alongside system-defined rewards.

## Glossary

- **Reward_System**: The component managing reward creation, approval, storage, and retrieval
- **Custom_Reward**: A reward created by a user that requires partner approval
- **System_Reward**: A pre-defined reward created by administrators, visible to all users
- **Reward_Proposal**: A custom reward in pending status awaiting partner approval
- **Creator**: The user who creates a custom reward
- **Partner**: The user paired with the creator who must approve reward proposals
- **Reward_Shop**: The interface displaying active rewards available for redemption
- **Approval_Queue**: The interface displaying pending reward proposals requiring approval
- **RLS_Policy**: Row Level Security policy controlling database access permissions
- **Reward_Service**: The service layer handling reward-related business logic and API calls

## Requirements

### Requirement 1: Create Custom Reward Proposals

**User Story:** As a user, I want to create custom reward proposals with a title and point cost, so that I can personalize rewards for my relationship.

#### Acceptance Criteria

1. WHEN a user submits a reward creation form with valid title and point cost, THE Reward_System SHALL create a reward proposal with status "pending"
2. THE Reward_System SHALL associate the reward proposal with the creator's user ID
3. THE Reward_System SHALL set isSystemReward to false for custom reward proposals
4. WHEN a user submits a reward with an empty title, THE Reward_System SHALL return a validation error
5. WHEN a user submits a reward with a point cost less than 1, THE Reward_System SHALL return a validation error
6. THE Reward_System SHALL store the creation timestamp for each reward proposal

### Requirement 2: Pending Reward Visibility

**User Story:** As a user, I want my pending reward proposals to be hidden from the reward shop, so that only approved rewards are redeemable.

#### Acceptance Criteria

1. WHEN the Reward_Shop loads active rewards, THE Reward_System SHALL exclude rewards with status "pending"
2. WHEN the Reward_Shop loads active rewards, THE Reward_System SHALL exclude rewards with status "rejected"
3. WHEN the Reward_Shop loads active rewards, THE Reward_System SHALL include rewards with status "approved"
4. WHEN the Reward_Shop loads active rewards, THE Reward_System SHALL include all system rewards regardless of status

### Requirement 3: Partner Approval Queue

**User Story:** As a partner, I want to see pending reward proposals that need my approval, so that I can review and approve or reject them.

#### Acceptance Criteria

1. WHEN the Approval_Queue loads, THE Reward_System SHALL retrieve all pending rewards where the current user is the partner of the creator
2. THE Approval_Queue SHALL display the reward title, point cost, and creator information for each pending reward
3. WHEN no pending rewards exist for approval, THE Approval_Queue SHALL display an empty state message
4. THE Reward_System SHALL exclude the user's own pending reward proposals from their approval queue

### Requirement 4: Approve Reward Proposals

**User Story:** As a partner, I want to approve reward proposals, so that they become active and redeemable in our reward shop.

#### Acceptance Criteria

1. WHEN a partner approves a pending reward, THE Reward_System SHALL update the reward status to "approved"
2. WHEN a partner approves a pending reward, THE Reward_System SHALL set isActive to true
3. WHEN a reward status changes to approved, THE Reward_System SHALL make the reward visible in the Reward_Shop for both the creator and partner
4. THE Reward_System SHALL record the approval timestamp
5. WHEN a partner attempts to approve a reward they did not create and are not partnered with the creator, THE Reward_System SHALL reject the approval request

### Requirement 5: Reject Reward Proposals

**User Story:** As a partner, I want to reject reward proposals that I don't agree with, so that they don't become active in our reward shop.

#### Acceptance Criteria

1. WHEN a partner rejects a pending reward, THE Reward_System SHALL update the reward status to "rejected"
2. WHEN a reward status changes to rejected, THE Reward_System SHALL exclude the reward from the Reward_Shop
3. WHEN a reward status changes to rejected, THE Reward_System SHALL exclude the reward from the Approval_Queue
4. THE Reward_System SHALL record the rejection timestamp
5. WHEN a partner attempts to reject a reward they did not create and are not partnered with the creator, THE Reward_System SHALL reject the rejection request

### Requirement 6: Custom Reward Privacy

**User Story:** As a user, I want only my partner and I to see our custom rewards, so that our personalized rewards remain private to our relationship.

#### Acceptance Criteria

1. WHEN the Reward_Shop loads, THE RLS_Policy SHALL filter custom rewards to only those created by the current user or their partner
2. WHEN the Reward_Shop loads, THE RLS_Policy SHALL include all system rewards for all users
3. WHEN a user queries reward data, THE RLS_Policy SHALL prevent access to custom rewards created by users outside their partnership
4. WHERE a user has no partner, THE RLS_Policy SHALL only show the user's own custom rewards and system rewards

### Requirement 7: System Reward Visibility

**User Story:** As a user, I want to see all system-defined rewards in the reward shop, so that I have access to standard rewards alongside custom ones.

#### Acceptance Criteria

1. THE Reward_System SHALL mark rewards with isSystemReward true as visible to all users
2. WHEN the Reward_Shop loads, THE Reward_System SHALL include all active system rewards regardless of the current user
3. THE Reward_System SHALL exclude system rewards from the partner approval workflow
4. WHEN an administrator creates a reward, THE Reward_System SHALL set isSystemReward to true and status to "approved"

### Requirement 8: Database Schema Updates

**User Story:** As a developer, I want the database schema to support custom reward creation and approval workflow, so that the feature can be implemented correctly.

#### Acceptance Criteria

1. THE Reward_System SHALL store a createdBy field containing the creator's user ID for each reward
2. THE Reward_System SHALL store a status field with allowed values "pending", "approved", or "rejected"
3. THE Reward_System SHALL store an isSystemReward boolean field indicating whether the reward is system-defined
4. WHERE a reward is a system reward, THE Reward_System SHALL allow createdBy to be null
5. THE Reward_System SHALL maintain existing fields: id, title, pointsCost, isActive, createdAt, updatedAt

### Requirement 9: Atomic Approval Operations

**User Story:** As a developer, I want approval and rejection operations to be atomic, so that data consistency is maintained under concurrent access.

#### Acceptance Criteria

1. WHEN a partner approves a reward, THE Reward_System SHALL update status and isActive in a single atomic transaction
2. WHEN a partner rejects a reward, THE Reward_System SHALL update status in a single atomic transaction
3. IF a database error occurs during approval or rejection, THEN THE Reward_System SHALL rollback all changes and return an error
4. WHEN two partners attempt to approve the same reward simultaneously, THE Reward_System SHALL process only the first request and reject the second

### Requirement 10: Reward Service API

**User Story:** As a developer, I want the Reward_Service to provide methods for custom reward operations, so that the UI layer can interact with the reward system.

#### Acceptance Criteria

1. THE Reward_Service SHALL provide a createRewardProposal method accepting title and pointsCost parameters
2. THE Reward_Service SHALL provide a fetchPendingApprovals method returning rewards awaiting the current user's approval
3. THE Reward_Service SHALL provide an approveReward method accepting a reward ID parameter
4. THE Reward_Service SHALL provide a rejectReward method accepting a reward ID parameter
5. THE Reward_Service SHALL provide a fetchActiveRewards method returning approved rewards visible to the current user
6. WHEN any Reward_Service method encounters an error, THE Reward_Service SHALL return a descriptive error message

### Requirement 11: User Interface Components

**User Story:** As a user, I want intuitive interfaces for creating rewards and managing approvals, so that I can easily use the custom reward feature.

#### Acceptance Criteria

1. THE Reward_System SHALL provide a reward creation form with fields for title and point cost
2. THE Reward_System SHALL provide an approval queue view displaying pending rewards with approve and reject actions
3. THE Reward_System SHALL provide visual feedback when approval or rejection actions complete successfully
4. WHEN a reward operation fails, THE Reward_System SHALL display an error message to the user
5. THE Reward_Shop SHALL visually distinguish between system rewards and custom rewards

### Requirement 12: Partner Relationship Validation

**User Story:** As a developer, I want the system to validate partner relationships before allowing approval operations, so that only legitimate partners can approve rewards.

#### Acceptance Criteria

1. WHEN a user attempts to approve a reward, THE Reward_System SHALL verify the user's partnerId matches the reward creator's user ID
2. WHEN a user attempts to reject a reward, THE Reward_System SHALL verify the user's partnerId matches the reward creator's user ID
3. IF the partner relationship validation fails, THEN THE Reward_System SHALL return an authorization error
4. WHERE a user has no partner, THE Reward_System SHALL prevent the user from approving any rewards
