# แก้ไขปัญหา: ไม่สามารถสร้าง Quest ได้

## ปัญหา

Error: `Failed to create quest: insert or update on table "quests" violates foreign key constraint "quests_created_by_fkey"`

## สาเหตุ

เมื่อ user sign up ผ่าน Supabase Auth จะมีการสร้าง record ใน `auth.users` table แต่**ไม่มีการสร้าง profile record** ใน `public.profiles` table อัตโนมัติ

เนื่องจาก `quests.created_by` มี foreign key constraint ที่อ้างอิงไปยัง `profiles.id` ดังนั้นถ้าไม่มี profile record การสร้าง quest จะ fail

## การแก้ไข

สร้าง database trigger ที่จะ**สร้าง profile อัตโนมัติ**เมื่อมี user ใหม่ sign up

### Migration: `20260309060000_auto_create_profile.sql`

```sql
-- Function to create profile for new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, total_points)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    0
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function when a new user is created
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

### คุณสมบัติ

1. **Auto-create Profile**: สร้าง profile อัตโนมัติเมื่อ user sign up
2. **Display Name**: ใช้ email prefix เป็น display name เริ่มต้น (ก่อน @)
3. **Initial Points**: เริ่มต้นด้วย 0 points
4. **Backfill**: สร้าง profiles ให้กับ users ที่มีอยู่แล้วแต่ยังไม่มี profile

## วิธีทดสอบ

### 1. ทดสอบกับ User ใหม่

```bash
# 1. Sign up user ใหม่ผ่านแอพ
# 2. ตรวจสอบว่ามี profile ถูกสร้างอัตโนมัติ

npx supabase db diff --local --schema public
```

### 2. ตรวจสอบใน Database

```sql
-- ดู users และ profiles
SELECT
  u.id,
  u.email,
  p.display_name,
  p.total_points
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id;

-- ควรเห็น profile record สำหรับทุก user
```

### 3. ทดสอบสร้าง Quest

```
1. เปิดแอพและ login
2. ไปที่ Quest Board
3. กดปุ่ม "+" เพื่อสร้าง quest
4. ใส่ title และ points
5. กด "Create Quest"
6. ✅ ควรสร้างสำเร็จโดยไม่มี error
```

## ผลลัพธ์

✅ **ก่อนแก้ไข**:

- User sign up → ไม่มี profile
- สร้าง quest → Error (foreign key constraint)

✅ **หลังแก้ไข**:

- User sign up → มี profile อัตโนมัติ
- สร้าง quest → สำเร็จ ✓

## Migrations ที่ Apply แล้ว

1. ✅ `20260309031604_initial_schema.sql` - Initial schema
2. ✅ `20260309032000_add_complete_quest_function.sql` - Atomic completion
3. ✅ `20260309040000_quest_rls_policies.sql` - Enhanced RLS policies
4. ✅ `20260309050000_fix_schema_issues.sql` - Schema fixes
5. ✅ `20260309060000_auto_create_profile.sql` - Auto-create profile (NEW)

## หมายเหตุ

- Trigger นี้จะทำงานทุกครั้งที่มี user ใหม่ sign up
- Display name จะถูกตั้งเป็น email prefix (ก่อน @)
- User สามารถเปลี่ยน display name ได้ภายหลังผ่าน ProfileView
- Existing users ที่ไม่มี profile จะถูกสร้างให้อัตโนมัติด้วย backfill query

## ขั้นตอนถัดไป

หลังจาก apply migration นี้แล้ว:

1. **ลบ users เก่า** (ถ้ามี) และ sign up ใหม่
2. **ทดสอบสร้าง quest** อีกครั้ง
3. **ตรวจสอบ profile** ว่าถูกสร้างอัตโนมัติหรือไม่

```bash
# ลบ users เก่าใน local database
npx supabase db reset --local

# หรือลบผ่าน SQL
# DELETE FROM auth.users;
```

จากนั้นลอง sign up และสร้าง quest ใหม่อีกครั้ง ควรจะทำงานได้แล้ว! 🎉
