# Row Level Security (RLS) Policies

This document describes the Row Level Security policies implemented for the Couple Quest application.

## Overview

RLS policies ensure that users can only access and modify data they are authorized to see. All tables in the database have RLS enabled.

## Rewards Table

### View Policies

**Policy: "Users can view active rewards"**

- **Operation:** SELECT
- **Rule:** `is_active = true`
- **Description:** All authenticated users can view rewards that are marked as active
- **Use Case:** Users browsing available rewards to redeem

### Management Policies

**Policy: "Service role can manage rewards"**

- **Operation:** ALL (INSERT, UPDATE, DELETE)
- **Rule:** `auth.jwt()->>'role' = 'service_role'`
- **Description:** Only the service role (admin) can create, update, or delete rewards
- **Use Case:** Admin management of reward catalog

## Transactions Table

### View Policies

**Policy: "Users can view own transactions"**

- **Operation:** SELECT
- **Rule:** `auth.uid() = user_id`
- **Description:** Users can view their own transaction history
- **Use Case:** Viewing personal point earnings and redemptions

**Policy: "Users can view partner transactions"**

- **Operation:** SELECT
- **Rule:** `auth.uid() IN (SELECT partner_id FROM profiles WHERE id = user_id)`
- **Description:** Users can view their partner's transaction history
- **Use Case:** Couples viewing each other's point activity

### Insert Policies

**Policy: "Functions can insert transactions"**

- **Operation:** INSERT
- **Rule:** `auth.jwt()->>'role' = 'service_role'`
- **Description:** Only service role can insert transactions (via SECURITY DEFINER functions)
- **Use Case:** System functions that award or deduct points

### Immutability

**No UPDATE or DELETE policies**

- **Description:** Transactions are immutable audit records
- **Enforcement:** No UPDATE or DELETE policies exist, preventing any modifications
- **Use Case:** Maintaining accurate point history for accountability

## Security Guarantees

### Rewards

1. **Public Visibility:** Active rewards are visible to all authenticated users
2. **Admin Control:** Only admins can manage the reward catalog
3. **Inactive Hiding:** Inactive rewards are hidden from users

### Transactions

1. **Privacy:** Users can only see their own and their partner's transactions
2. **Transparency:** Partners can view each other's point activity
3. **Immutability:** Transaction history cannot be modified or deleted
4. **Controlled Creation:** Transactions can only be created through authorized system functions

## Testing

All RLS policies are tested in `supabase/tests/rewards_transactions_rls_test.sql`. The test suite verifies:

- Positive cases (allowed operations succeed)
- Negative cases (blocked operations fail)
- Partner relationships work correctly
- Unpaired users have appropriate restrictions

See `supabase/tests/README.md` for instructions on running the tests.

## Implementation Notes

### Partner Relationship

The partner relationship is bidirectional and stored in the `profiles` table:

- User A has `partner_id` pointing to User B
- User B has `partner_id` pointing to User A

This allows the RLS policies to check partner relationships efficiently.

### Service Role Functions

Functions that need to insert transactions should be created with `SECURITY DEFINER` and execute as the service role:

```sql
CREATE OR REPLACE FUNCTION award_points(...)
RETURNS void AS $$
BEGIN
  -- Function logic here
  INSERT INTO transactions (...) VALUES (...);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

This pattern ensures transactions can only be created through controlled, audited code paths.
