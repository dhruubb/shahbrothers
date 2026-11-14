# Shah Brothers — Saree Retail App

A Flutter app for **Shah Brothers** covering billing, GST invoices, thermal printing, customer records, salesperson targets and bonuses, and owner analytics. It runs on Android and iOS, with Supabase (PostgreSQL + Auth + Row Level Security) as the backend and a persistent offline demo mode when no Supabase keys are supplied.

---

## Demo logins

These accounts work in both offline demo mode and Supabase (after running `supabase/seed.sql`). They are also listed on the login screen, where tapping one fills in its details.

| Role | Name | Email | Password |
|---|---|---|---|
| **Owner** | Rajesh Shah | `owner@shahbrothers.in` | `Owner@123` |
| **Manager** | Amit Shah | `manager@shahbrothers.in` | `Manager@123` |
| Manager | Neha Mehta | `neha.manager@shahbrothers.in` | `Manager@123` |
| **Salesperson** (top performer) | Priya Sharma | `priya@shahbrothers.in` | `Sales@123` |
| Salesperson | Rahul Verma | `rahul@shahbrothers.in` | `Sales@123` |
| Salesperson | Kavita Patel | `kavita@shahbrothers.in` | `Sales@123` |
| Salesperson | Suresh Iyer | `suresh@shahbrothers.in` | `Sales@123` |
| Salesperson | Anjali Desai | `anjali@shahbrothers.in` | `Sales@123` |
| Salesperson | Imran Shaikh | `imran@shahbrothers.in` | `Sales@123` |

The demo data contains 9 staff, 34 customers, 28 sarees in 17 categories, 196 bills over the last 4 months (cash, UPI, card and split payments), and finalised bonuses for the last 3 months. Dates are relative to the day the data is loaded, so dashboards always show recent activity.

---

## What each role can do

| | Owner | Manager | Salesperson |
|---|:-:|:-:|:-:|
| Revenue dashboard, charts, filters, reports, PDF export | ✅ | — | — |
| Team performance, targets, bonus slabs, finalise/pay bonuses | ✅ | — | — |
| Create bills, print/share invoices | ✅ | ✅ | — |
| Billing history | all | all | own only |
| Customers (add/edit, purchase history, consent) | ✅ | ✅ | — |
| Saree catalogue (add/edit, stock) | ✅ | ✅ | — |
| Cancel an invoice (restores stock) | ✅ | — | — |
| Store details, GST rate, invoice prefix | ✅ | — | — |
| Own sales, monthly target progress, earned bonuses | — | — | ✅ |

These rules are enforced in three places: navigation guards in the app, the local demo repository, and **Row Level Security plus `security definer` RPCs in Supabase**. The Supabase layer is the authority.

---

## Quick start

**Prerequisites:** Flutter 3.27 or newer (`flutter doctor` should be clean), Android Studio with an emulator or device, and Xcode 15+ for iOS. Leave about 15–20 GB of free disk space for the SDKs and builds.

```bash
cd ~/Desktop/ShahBrothers
bash tool/setup_platforms.sh   # creates android/ & ios/, adds permissions, app name and icon
flutter run                    # starts in offline demo mode
```

`setup_platforms.sh` runs `flutter create` (without overwriting the app's own files) and then `tool/patch_platforms.py`. The patch step does the following:

- Adds the Android Internet and Bluetooth permissions.
- Adds the iOS Bluetooth and local-network usage text.
- Sets the display name to "Shah Brothers" and the minimum iOS version to 13.
- Installs the maroon-and-gold app icon.

### Working from another laptop

```bash
git clone <your-repo-url> ShahBrothers && cd ShahBrothers
bash tool/setup_platforms.sh   # android/ and ios/ are generated, not stored in git
cp env.example.json env.json   # only if using Supabase; env.json is never committed
flutter run
```

### Run the tests

```bash
flutter test
```

| Test file | What it covers |
|---|---|
| `billing_calculator_test.dart` | GST, discounts, CGST/SGST split, round-off, split-payment validation |
| `seed_parity_test.dart` | Dart totals match the generator (and therefore Supabase) for every demo bill, to the paisa |
| `local_repository_test.dart` | End-to-end billing: invoice numbering, stock, customer de-duplication, rejected payments with no side effects, cancellation, GST change, bonus finalisation, and every role permission |
| `bonus_and_permissions_test.dart` | Bonus slabs and boundaries; the role → permission map |
| `money_and_analytics_test.dart` | ₹ lakh/crore formatting, financial-year codes, dashboard aggregations |
| `widget_flow_test.dart` | Login screen shows demo accounts; each role lands on its own home screen |

The Supabase schema has its own test suite (36 checks: RLS for every role, RPC validation, and maths parity). It runs against any local PostgreSQL 15+:

```bash
PGURL="postgresql://postgres@localhost:5432/postgres" bash supabase/tests/run_tests.sh
```

---

## Connect Supabase

1. Create a project at [supabase.com](https://supabase.com). Choose the Mumbai (ap-south-1) region for low latency.
2. Open **SQL Editor** and run, in order:
   1. `supabase/migrations/0001_init.sql` creates the tables, enums, RLS policies, RPCs and views.
   2. `supabase/seed.sql` creates the 9 login accounts and all the demo data. It is safe to re-run, and doing so resets the demo data.
3. In **Authentication → Sign In / Providers**, turn off **Allow new users to sign up**. Staff accounts are created by the owner (see below).
4. In **Project Settings → API**, copy the Project URL and the anon (publishable) key.
5. Create `env.json` next to `pubspec.yaml`. It is already git-ignored:
   ```bash
   cp env.example.json env.json   # then paste your URL and key
   ```
6. Run with the keys:
   ```bash
   flutter run --dart-define-from-file=env.json
   ```
   The login screen shows a green "Supabase" badge instead of "Offline demo mode". If the keys are missing or invalid, the app falls back to demo mode.

### Adding staff (Supabase)

Logins are Supabase Auth users. To add someone:

1. Go to **Authentication → Users → Add user**, enter an email and password, and tick *Auto confirm*.
2. Set the user's role in the SQL editor:
   ```sql
   update auth.users set raw_app_meta_data = raw_app_meta_data || '{"role":"salesperson"}' where email = 'new.person@shahbrothers.in';
   insert into public.users (id, full_name, email, role, monthly_target)
   select id, 'New Person', email, 'salesperson', 100000 from auth.users where email = 'new.person@shahbrothers.in'
   on conflict (id) do update set role = excluded.role, is_active = true;
   ```
3. The person appears under **Team**, where the owner can set their target or deactivate them.

The role comes from `app_metadata`, which only admins can set. A public sign-up can therefore never give itself access: without a role, the profile is created inactive. In demo mode, the owner can add staff directly from **Team → Add staff**.

---

## How billing works

- **Flow:** customer (type a mobile number to auto-match returning customers) → salesperson → sarees (from the catalogue or entered manually; quantity, price, % or ₹ discount) → payment (cash with change calculation, UPI, card, or a split across up to 3 methods) → review → save → print or share.
- **Maths:** one formula, implemented identically in Dart (`lib/domain/billing_calculator.dart`), SQL (`create_sale_internal()`) and Python (`tool/generate_seed.py`). Everything is calculated in integer paise:
  - line discount = percent of the line (rounded half-up) or a flat ₹ amount, which can't exceed the line value
  - taxable value = subtotal − discounts
  - GST = taxable × rate, rounded half-up; CGST = ⌈GST ÷ 2⌉, SGST = the rest
  - total = taxable + GST, rounded to the nearest rupee, with the difference shown as round-off
- **GST** is 5% by default (the usual rate for sarees) and can be changed under *More → Store & GST*. New bills use the new rate. Old invoices keep their rate.
- **Server-side checks:** the database recalculates every total and rejects a bill if the payments don't add up exactly. The bill is saved atomically: header, line items, payments, stock and invoice number together.
- **Invoice numbers** follow `PREFIX/YY-YY/00001`, with a separate counter for each Indian financial year (April–March), e.g. `SB/26-27/00197`.
- **Cancelling** (owner only, reason required) keeps the invoice for audit, marks it cancelled, returns the stock and excludes it from analytics and bonuses.

## Bonuses

Each month, a salesperson's **net sales** (taxable value, excluding GST) are compared with their **monthly target**. The highest active slab they reach applies to all net sales for that month:

| Slab | From | Commission | Flat bonus |
|---|---|---|---|
| Base | 0% | 1.0% | — |
| Silver | 80% | 1.5% | — |
| Gold | 100% | 2.0% | ₹2,000 |
| Platinum | 120% | 2.5% | ₹5,000 |

The owner can edit the slabs under *More → Bonus rules*, which includes a live preview. The current month is always a live projection. After the month ends, the owner presses **Finalise**, which stores the bonuses, and then **Mark as paid**. Salespeople see their progress ring, how much more they need for the next slab, and their bonus history.

## Printing

- **Thermal receipts (ESC/POS):** 58 mm or 80 mm, over **Bluetooth** or **Wi-Fi/LAN** (raw TCP, port 9100). Set this up under *Printer* in the account menu.
  - Android supports classic Bluetooth printers; pair the printer in phone settings first.
  - iOS supports Bluetooth LE printers only.
  - The ESC/POS commands come from a small built-in builder (`lib/features/printing/escpos.dart`) with no third-party dependency.
- **PDF invoice:** a branded A4 GST tax invoice with preview, share (WhatsApp, email) and print to any AirPrint or Android printer. The ₹ symbol renders correctly because Poppins is bundled.

## Customers and future marketing

The customer table already supports future WhatsApp and Telegram campaigns. No messaging is sent yet.

- **Explicit marketing consent:** a yes/no flag, plus when it was given and how (verbally in store, signed form, or in app).
- **Per-channel opt-ins:** WhatsApp, SMS, email and Telegram. The database rejects an opt-in unless consent is recorded.
- **Other fields:** preferred channel, preferred language, birthday, anniversary, tags (bridal, festive, …) and an unsubscribe timestamp.

A future campaign sender only needs to run:

```sql
select * from customers where marketing_consent and whatsapp_opt_in and unsubscribed_at is null;
```

---

## Build for release

### Android APK

```bash
flutter build apk --release --dart-define-from-file=env.json
# → build/app/outputs/flutter-apk/app-release.apk  (install with: adb install <apk>)
flutter build appbundle --release --dart-define-from-file=env.json   # for the Play Store
```

The template signs release builds with the debug key, which is fine for testing on your own phones. For the Play Store, create an upload keystore and configure `android/key.properties`, following [Flutter's Android deployment guide](https://docs.flutter.dev/deployment/android).

### iOS

```bash
open ios/Runner.xcworkspace        # Runner → Signing & Capabilities → choose your Team
flutter build ipa --release --dart-define-from-file=env.json
# → build/ios/ipa/  (upload with Transporter or Xcode Organizer)
```

To test on your own iPhone, run `flutter run --release` with the phone connected. This needs an Apple ID set as the Team in Xcode.

Leave out `--dart-define-from-file=env.json` to build a demo-mode app.

---

## Project structure

```
lib/
  main.dart                 picks Supabase or local demo repository
  app.dart, router/         GoRouter with role guards, role-specific bottom navigation
  core/                     theme (maroon/ivory/gold), ₹ and date formatting, shared widgets, brand mark
  data/
    models/                 AppUser, Customer, Product, Sale/SaleItem/Payment, Bonus, settings
    repositories/           DataRepository interface → LocalRepository | SupabaseRepository
  domain/                   billing calculator, bonus calculator, analytics, permissions (pure Dart, unit-tested)
  providers/                Riverpod providers (auth, data, dashboard filters)
  features/
    auth/ billing/ owner/ manager/ salesperson/ customers/ products/ reports/ settings/ printing/ dashboard/
assets/
  demo/seed.json            demo data for offline mode (generated)
  fonts/                    Lora, Inter, Poppins (OFL)
  branding/                 app icon sources
supabase/
  migrations/0001_init.sql  schema + RLS + RPCs
  seed.sql                  demo logins + data (generated)
  tests/                    PostgreSQL test-suite for RLS and billing
tool/
  generate_seed.py          regenerates seed.json + seed.sql from one source
  setup_platforms.sh        creates/patches android/ and ios/
test/                       Dart unit, repository and widget tests
```

**Data source:** the app talks only to `DataRepository`. `SupabaseRepository` uses PostgREST, RPCs and Auth. `LocalRepository` stores a JSON database in the app's documents folder, seeded on first launch, and mirrors the same permission rules. To change the demo data, edit `tool/generate_seed.py` and run `python3 tool/generate_seed.py`.

## Troubleshooting

- **`flutter pub get` version conflicts:** run `flutter pub upgrade --major-versions`. If the problem is fl_chart, go_router or Riverpod, keep those at the versions in `pubspec.yaml`; the code targets those APIs.
- **The app still says "Offline demo mode":** check that `env.json` sits next to `pubspec.yaml`, the URL starts with `https://`, and you passed `--dart-define-from-file=env.json`.
- **"Invalid login credentials" on Supabase:** re-run `supabase/seed.sql`. It resets the passwords to the ones above.
- **Bluetooth printer not found:** pair it in the phone's Bluetooth settings, allow the "Nearby devices" permission (Android 12+), then tap *Find*.
- **Reset demo data:** *More → Reset demo data* (owner, demo mode only).
