#!/usr/bin/env python3
"""
Generates Shah Brothers demo data from ONE source so that local demo mode
and Supabase always contain the same records:

  assets/demo/seed.json   -> loaded by the app in local demo mode
  supabase/seed.sql       -> run in Supabase after migrations/0001_init.sql

Dates are stored relative to the day the data is loaded (days_ago +
minute of day), so the dashboards always show recent activity.

Billing maths here mirrors lib/domain/billing_calculator.dart and the
create_sale_internal() SQL function; the seed itself is a parity check
(Supabase rejects a seeded sale if the payment total does not match).

Usage:  python3 tool/generate_seed.py
"""
import hashlib
import json
import os
import random
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NS = uuid.UUID("6b1e2e00-5b5b-4a11-9a7c-5a4b2b1c0d00")
rng = random.Random(20261113)


def uid(kind, key):
    return str(uuid.uuid5(NS, f"{kind}:{key}"))


def password_hash(email, password):
    # Local demo mode only (Supabase uses bcrypt via auth.users)
    return hashlib.sha256(f"shahbrothers:{email.lower()}:{password}".encode()).hexdigest()


# ------------------------------------------------------------------ staff
STAFF = [
    # name, email, phone, role, password, perf weight, achievement factor
    ("Rajesh Shah", "owner@shahbrothers.in", "9820012345", "owner", "Owner@123", 0, 0),
    ("Amit Shah", "manager@shahbrothers.in", "9820023456", "manager", "Manager@123", 0, 0),
    ("Neha Mehta", "neha.manager@shahbrothers.in", "9820034567", "manager", "Manager@123", 0, 0),
    ("Priya Sharma", "priya@shahbrothers.in", "9867012340", "salesperson", "Sales@123", 30, 1.28),
    ("Rahul Verma", "rahul@shahbrothers.in", "9867023451", "salesperson", "Sales@123", 22, 1.06),
    ("Kavita Patel", "kavita@shahbrothers.in", "9867034562", "salesperson", "Sales@123", 18, 0.93),
    ("Suresh Iyer", "suresh@shahbrothers.in", "9867045673", "salesperson", "Sales@123", 13, 0.82),
    ("Anjali Desai", "anjali@shahbrothers.in", "9867056784", "salesperson", "Sales@123", 10, 0.68),
    ("Imran Shaikh", "imran@shahbrothers.in", "9867067895", "salesperson", "Sales@123", 7, 0.55),
]
JOINED_DAYS_AGO = {"owner": 4000, "manager": 1500, "salesperson": 600}

staff = []
for i, (name, email, phone, role, pwd, w, ach) in enumerate(STAFF):
    staff.append({
        "id": uid("user", email),
        "full_name": name,
        "email": email,
        "phone": phone,
        "role": role,
        "password": pwd,
        "password_hash": password_hash(email, pwd),
        "monthly_target": 0,
        "is_active": True,
        "joined_days_ago": JOINED_DAYS_AGO[role] - i * 37,
        "_weight": w,
        "_ach": ach,
    })
salespeople = [s for s in staff if s["role"] == "salesperson"]
managers = [s for s in staff if s["role"] == "manager"]

# --------------------------------------------------------------- products
# name, category, fabric, color, price
PRODUCTS = [
    ("Katan Silk Banarasi with Kadhua Buti", "Banarasi", "Pure Katan Silk", "Ruby Red", 18500),
    ("Banarasi Georgette Jaal", "Banarasi", "Georgette", "Bottle Green", 9800),
    ("Tissue Banarasi Bridal", "Banarasi", "Silk Tissue", "Gold & Maroon", 32500),
    ("Kanjeevaram Temple Border", "Kanjeevaram", "Pure Mulberry Silk", "Mustard", 24500),
    ("Kanjeevaram Korvai Contrast", "Kanjeevaram", "Pure Mulberry Silk", "Peacock Blue", 28900),
    ("Soft Silk Kanjeevaram", "Kanjeevaram", "Soft Silk", "Lavender", 12900),
    ("Yeola Paithani Muniya Border", "Paithani", "Pure Silk", "Purple", 21500),
    ("Semi Paithani Peacock Pallu", "Paithani", "Art Silk", "Rani Pink", 6800),
    ("Rajkot Single Ikat Patola", "Patola", "Silk", "Red & Black", 15800),
    ("Patan Double Ikat Patola", "Patola", "Pure Silk", "Multicolour", 44500),
    ("Chanderi Silk Cotton Butta", "Chanderi", "Silk Cotton", "Ivory", 4200),
    ("Chanderi Zari Checks", "Chanderi", "Silk Cotton", "Mint", 5600),
    ("Jamnagar Gharchola Bandhani", "Bandhani", "Gaji Silk", "Red", 13500),
    ("Bandhani Georgette Daily Wear", "Bandhani", "Georgette", "Yellow", 3450),
    ("Sequinned Georgette Party Saree", "Georgette", "Georgette", "Black", 7900),
    ("Printed Georgette Floral", "Georgette", "Georgette", "Peach", 2650),
    ("Chiffon Ombre with Lace", "Chiffon", "Pure Chiffon", "Coral", 3850),
    ("Bengal Tant Cotton", "Cotton", "Cotton", "White & Red", 1650),
    ("Mulmul Cotton Block Print", "Cotton", "Mulmul Cotton", "Indigo", 1950),
    ("Pure Linen Silver Zari", "Linen", "Linen", "Grey", 5200),
    ("Organza Hand-Embroidered", "Organza", "Organza", "Powder Blue", 8900),
    ("Tussar Silk Madhubani Hand-Painted", "Tussar", "Tussar Silk", "Beige", 11200),
    ("Kota Doria Zari Border", "Kota Doria", "Cotton Silk", "Lemon", 2950),
    ("Mysore Crepe Silk", "Mysore Silk", "Crepe Silk", "Emerald", 9600),
    ("Designer Bridal Lehenga Saree", "Designer", "Net & Silk", "Maroon", 38500),
    ("Designer Satin Ready-to-Wear", "Designer", "Satin", "Wine", 6500),
    ("Gadwal Silk Cotton", "Gadwal", "Silk Cotton", "Orange", 7400),
    ("Pochampally Ikat Silk", "Ikat", "Silk", "Navy", 10500),
]
CAT_CODE = {
    "Banarasi": "BAN", "Kanjeevaram": "KAN", "Paithani": "PAI", "Patola": "PAT",
    "Chanderi": "CHN", "Bandhani": "BDH", "Georgette": "GEO", "Chiffon": "CHF",
    "Cotton": "COT", "Linen": "LIN", "Organza": "ORG", "Tussar": "TUS",
    "Kota Doria": "KOT", "Mysore Silk": "MYS", "Designer": "DSG", "Gadwal": "GAD",
    "Ikat": "IKT",
}
products = []
counters = {}
for name, cat, fabric, color, price in PRODUCTS:
    code = CAT_CODE[cat]
    counters[code] = counters.get(code, 0) + 1
    sku = f"{code}-{counters[code]:03d}"
    products.append({
        "id": uid("product", sku),
        "sku": sku,
        "name": name,
        "category": cat,
        "fabric": fabric,
        "color": color,
        "description": f"{fabric} saree in {color.lower()}.",
        "selling_price": price,
        "stock_qty": 0,
        "is_active": True,
    })

# -------------------------------------------------------------- customers
CUSTOMERS = [
    ("Meera Joshi", "Dadar"), ("Sunita Agarwal", "Ghatkopar"), ("Pooja Kulkarni", "Thane"),
    ("Kiran Malhotra", "Bandra"), ("Deepa Nair", "Chembur"), ("Lata Deshpande", "Vile Parle"),
    ("Rekha Gupta", "Borivali"), ("Shalini Reddy", "Powai"), ("Asha Patil", "Dombivli"),
    ("Nisha Kapoor", "Andheri"), ("Bhavna Shah", "Malad"), ("Hema Rao", "Matunga"),
    ("Smita Jain", "Kandivali"), ("Gayatri Iyer", "Sion"), ("Rupali Sawant", "Parel"),
    ("Farah Khan", "Mahim"), ("Jyoti Mishra", "Mulund"), ("Swati Bhosale", "Vashi"),
    ("Anita Chopra", "Juhu"), ("Mamta Soni", "Goregaon"), ("Neelam Thakkar", "Santacruz"),
    ("Pallavi Gokhale", "Girgaon"), ("Radhika Menon", "Worli"), ("Seema Pandey", "Kurla"),
    ("Usha Bhatt", "Bhayandar"), ("Vandana Singh", "Mira Road"), ("Sneha Pawar", "Panvel"),
    ("Archana Dubey", "Kalyan"), ("Komal Mehta", "Colaba"), ("Tanvi Naik", "Lower Parel"),
    ("Priyanka Chavan", "Kharghar"), ("Madhuri Vora", "Bhuleshwar"), ("Ritu Saxena", "Wadala"),
    ("Kavya Hegde", "Byculla"),
]
customers = []
used_phones = set(s["phone"] for s in staff)
CHANNELS = ["whatsapp", "whatsapp", "whatsapp", "sms", "telegram", "email"]
for i, (name, city) in enumerate(CUSTOMERS):
    while True:
        phone = rng.choice("9876") + "".join(str(rng.randint(0, 9)) for _ in range(9))
        if phone not in used_phones:
            used_phones.add(phone)
            break
    consent = rng.random() < 0.62
    channel = rng.choice(CHANNELS) if consent else "none"
    first = name.split()[0].lower()
    c = {
        "id": uid("customer", phone),
        "name": name,
        "phone": phone,
        "email": f"{first}.{name.split()[1].lower()}@example.in" if rng.random() < 0.5 else None,
        "city": city,
        "notes": None,
        "preferred_language": rng.choice(["en", "hi", "mr", "gu"]),
        "preferred_channel": channel,
        "marketing_consent": consent,
        "consent_days_ago": rng.randint(5, 110) if consent else None,
        "marketing_consent_source": rng.choice(["in_store_verbal", "signed_form"]) if consent else None,
        "whatsapp_opt_in": consent and channel == "whatsapp",
        "sms_opt_in": consent and channel == "sms",
        "email_opt_in": consent and channel == "email",
        "telegram_opt_in": consent and channel == "telegram",
        "date_of_birth": f"{rng.randint(1962, 1998)}-{rng.randint(1, 12):02d}-{rng.randint(1, 28):02d}" if rng.random() < 0.4 else None,
        "anniversary": f"{rng.randint(1985, 2022)}-{rng.randint(1, 12):02d}-{rng.randint(1, 28):02d}" if rng.random() < 0.25 else None,
        "tags": rng.sample(["bridal", "silk-lover", "festive", "regular", "corporate"], k=rng.randint(0, 2)),
        "created_days_ago": None,
    }
    customers.append(c)

# ---------------------------------------------------------- billing maths
def line_discount(gross, dtype, value):
    if not value:
        return 0
    if dtype == "percent":
        bp = round(value * 100)
        return (gross * bp + 5000) // 10000
    d = round(value * 100)
    assert d <= gross
    return d


def compute(items, gst_rate):
    subtotal = disc_total = 0
    for it in items:
        gross = it["quantity"] * round(it["unit_price"] * 100)
        subtotal += gross
        disc_total += line_discount(gross, it["discount_type"], it["discount_value"])
    taxable = subtotal - disc_total
    gst = (taxable * round(gst_rate * 100) + 5000) // 10000
    pre = taxable + gst
    total = ((pre + 50) // 100) * 100
    return {"subtotal": subtotal, "discount": disc_total, "taxable": taxable,
            "gst": gst, "total": total}


GST_RATE = 5.0

# ------------------------------------------------------------------ sales
N_SALES = 196
DAYS = 120
sp_weights = [s["_weight"] for s in salespeople]
cust_weights = [rng.choice([1, 1, 1, 2, 2, 3, 5]) for _ in customers]
prod_weights = []
for p in products:
    price = p["selling_price"]
    prod_weights.append(9 if price < 4000 else 7 if price < 10000 else 4 if price < 20000 else 2 if price < 35000 else 1)

day_choices = []
for _ in range(N_SALES):
    # Slightly more sales in recent weeks and on weekends
    d = 1 + int((DAYS - 1) * (rng.random() ** 1.15))
    day_choices.append(d)
day_choices.sort(reverse=True)  # oldest first

sales = []
customer_order = list(range(len(customers)))
rng.shuffle(customer_order)
for n, days_ago in enumerate(day_choices):
    minute = rng.randint(11 * 60, 20 * 60 + 45)
    if n < len(customers):
        cust = customers[customer_order[n]]
    else:
        cust = rng.choices(customers, weights=cust_weights)[0]
    sp = rng.choices(salespeople, weights=sp_weights)[0]
    mgr = managers[(days_ago // 3) % 2]
    n_items = rng.choices([1, 2, 3, 4], weights=[52, 30, 13, 5])[0]
    chosen = []
    while len(chosen) < n_items:
        p = rng.choices(products, weights=prod_weights)[0]
        if p not in chosen:
            chosen.append(p)
    items = []
    for p in chosen:
        qty = rng.choices([1, 2, 3], weights=[85, 12, 3])[0] if p["selling_price"] < 8000 else 1
        r = rng.random()
        if r < 0.22:
            dtype, dval = "percent", rng.choice([5, 10, 10, 15, 7.5])
        elif r < 0.38:
            dtype, dval = "amount", min(rng.choice([200, 300, 500, 1000, 1500]), p["selling_price"] * qty // 4)
        else:
            dtype, dval = "amount", 0
        items.append({
            "product_id": p["id"], "product_name": p["name"], "product_code": p["sku"],
            "quantity": qty, "unit_price": p["selling_price"],
            "discount_type": dtype, "discount_value": dval,
        })
    totals = compute(items, GST_RATE)
    total_rupees = totals["total"] // 100
    r = rng.random()
    if r < 0.27:
        payments = [{"method": "cash", "amount": total_rupees}]
    elif r < 0.67:
        payments = [{"method": "upi", "amount": total_rupees, "reference": f"UPI{rng.randint(10**11, 10**12 - 1)}"}]
    elif r < 0.89:
        payments = [{"method": "card", "amount": total_rupees, "reference": f"XX{rng.randint(1000, 9999)}"}]
    else:
        cash_part = max(500, (total_rupees * rng.choice([20, 30, 40, 50]) // 100) // 500 * 500)
        if cash_part >= total_rupees:
            cash_part = total_rupees // 2
        other = rng.choice(["upi", "card"])
        payments = [
            {"method": "cash", "amount": cash_part},
            {"method": other, "amount": total_rupees - cash_part,
             "reference": f"UPI{rng.randint(10**11, 10**12 - 1)}" if other == "upi" else f"XX{rng.randint(1000, 9999)}"},
        ]
    assert sum(p["amount"] for p in payments) * 100 == totals["total"]
    if cust["created_days_ago"] is None:
        cust["created_days_ago"] = days_ago + rng.randint(0, 20)
    notes = rng.choice([None] * 8 + ["Fall & pico done", "Blouse stitching requested", "Gift wrap", "Wedding order"])
    sales.append({
        "days_ago": days_ago,
        "minute_of_day": minute,
        "customer_id": cust["id"],
        "salesperson_id": sp["id"],
        "manager_id": mgr["id"],
        "items": items,
        "payments": payments,
        "notes": notes,
        "_totals": totals,
    })

# Make sure every timestamp is unique and ordered (oldest first)
sales.sort(key=lambda s: (-s["days_ago"], s["minute_of_day"]))
for c in customers:
    if c["created_days_ago"] is None:
        c["created_days_ago"] = rng.randint(1, 30)
    if c["marketing_consent"]:
        c["consent_days_ago"] = min(c["consent_days_ago"], c["created_days_ago"])

# Stock: what's left after the seeded sales, never negative
sold = {}
for s in sales:
    for it in s["items"]:
        sold[it["product_id"]] = sold.get(it["product_id"], 0) + it["quantity"]
for p in products:
    p["opening_stock"] = sold.get(p["id"], 0) + rng.randint(2, 14)
    p["stock_qty"] = p["opening_stock"] - sold.get(p["id"], 0)

# Targets: monthly net-sales (ex GST) target from each salesperson's
# average 30-day net sales and their intended achievement level.
for sp in salespeople:
    net = sum(s["_totals"]["taxable"] for s in sales if s["salesperson_id"] == sp["id"])
    monthly = net / (DAYS / 30) / 100
    target = max(25000, round(monthly / sp["_ach"] / 5000) * 5000)
    sp["monthly_target"] = target

# --------------------------------------------------------------- settings
settings = {
    "store_name": "Shah Brothers",
    "tagline": "Heritage Sarees since 1972",
    "address": "Shop 12, Hindmata Cloth Market, Dadar East, Mumbai 400014",
    "phone": "022 2414 5678",
    "email": "hello@shahbrothers.in",
    "gstin": "27AAKFS1972M1Z5",
    "gst_rate": GST_RATE,
    "invoice_prefix": "SB",
    "invoice_footer": "Thank you for shopping with Shah Brothers! Exchange within 7 days with invoice. No cash refunds.",
}
rules = [
    {"id": uid("rule", "base"), "name": "Base", "min_achievement_pct": 0, "commission_pct": 1.0, "flat_bonus": 0, "is_active": True},
    {"id": uid("rule", "silver"), "name": "Silver", "min_achievement_pct": 80, "commission_pct": 1.5, "flat_bonus": 0, "is_active": True},
    {"id": uid("rule", "gold"), "name": "Gold", "min_achievement_pct": 100, "commission_pct": 2.0, "flat_bonus": 2000, "is_active": True},
    {"id": uid("rule", "platinum"), "name": "Platinum", "min_achievement_pct": 120, "commission_pct": 2.5, "flat_bonus": 5000, "is_active": True},
]

# ------------------------------------------------------------ write JSON
def clean(d):
    return {k: v for k, v in d.items() if not k.startswith("_")}


seed = {
    "version": 1,
    "settings": settings,
    "commission_rules": rules,
    "users": [{k: v for k, v in clean(s).items() if k != "password"} for s in staff],
    "demo_credentials": [{"role": s["role"], "name": s["full_name"], "email": s["email"], "password": s["password"]} for s in staff],
    "products": [clean(p) for p in products],
    "customers": [clean(c) for c in customers],
    "sales": [clean(s) for s in sales],
    # Previous months to finalise as bonuses on first load; the older two
    # are marked paid.
    "bonus_months_back": [3, 2, 1],
    "bonus_paid_months_back": [3, 2],
    # Expected totals in paise (used by the parity unit test)
    "expected_totals": [s["_totals"] for s in sales],
}
os.makedirs(os.path.join(ROOT, "assets", "demo"), exist_ok=True)
with open(os.path.join(ROOT, "assets", "demo", "seed.json"), "w") as f:
    json.dump(seed, f, indent=1, ensure_ascii=False)

# ------------------------------------------------------------- write SQL
def q(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def ts(days_ago, minute):
    return (f"((((now() at time zone 'Asia/Kolkata')::date - {days_ago})::timestamp "
            f"+ make_interval(mins => {minute})) at time zone 'Asia/Kolkata')")


out = []
w = out.append
w("-- =====================================================================")
w("-- Shah Brothers demo data. Generated by tool/generate_seed.py — do not edit.")
w("-- Run AFTER supabase/migrations/0001_init.sql in the Supabase SQL editor.")
w("-- Creates login accounts for every staff member (see README for passwords).")
w("-- Safe to re-run: it clears existing sales/customers/products first.")
w("-- =====================================================================")
w("begin;")
w("")
w("delete from public.bonuses; delete from public.payments; delete from public.sale_items;")
w("delete from public.sales; delete from public.invoice_counters; delete from public.customers;")
w("delete from public.products; delete from public.commission_rules;")
w("")
w("-- Staff login accounts (Supabase Auth)")
for s in staff:
    meta_app = json.dumps({"provider": "email", "providers": ["email"], "role": s["role"]})
    meta_user = json.dumps({"full_name": s["full_name"], "phone": s["phone"]})
    w(f"""insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', {q(s['id'])}, 'authenticated', 'authenticated', {q(s['email'])},
  extensions.crypt({q(s['password'])}, extensions.gen_salt('bf')), now(), '', '', '', '',
  {q(meta_app)}::jsonb, {q(meta_user)}::jsonb, now(), now())
on conflict (id) do update set encrypted_password = excluded.encrypted_password,
  raw_app_meta_data = excluded.raw_app_meta_data, raw_user_meta_data = excluded.raw_user_meta_data;""")
    ident = json.dumps({"sub": s["id"], "email": s["email"], "email_verified": True})
    w(f"""insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
values ({q(uid('identity', s['email']))}, {q(s['id'])}, {q(s['id'])}, {q(ident)}::jsonb, 'email', now(), now(), now())
on conflict do nothing;""")
w("")
w("-- Staff profiles")
for s in staff:
    w(f"""insert into public.users (id, full_name, email, phone, role, monthly_target, is_active, joined_on)
values ({q(s['id'])}, {q(s['full_name'])}, {q(s['email'])}, {q(s['phone'])}, {q(s['role'])}, {s['monthly_target']}, true, current_date - {s['joined_days_ago']})
on conflict (id) do update set full_name = excluded.full_name, email = excluded.email, phone = excluded.phone,
  role = excluded.role, monthly_target = excluded.monthly_target, is_active = true, joined_on = excluded.joined_on;""")
w("")
w("-- Store settings")
w(f"""update public.app_settings set store_name = {q(settings['store_name'])}, tagline = {q(settings['tagline'])},
  address = {q(settings['address'])}, phone = {q(settings['phone'])}, email = {q(settings['email'])},
  gstin = {q(settings['gstin'])}, gst_rate = {settings['gst_rate']}, invoice_prefix = {q(settings['invoice_prefix'])},
  invoice_footer = {q(settings['invoice_footer'])}, updated_at = now() where id = 1;""")
w("")
w("-- Commission rules")
for r in rules:
    w(f"insert into public.commission_rules (id, name, min_achievement_pct, commission_pct, flat_bonus, is_active) "
      f"values ({q(r['id'])}, {q(r['name'])}, {r['min_achievement_pct']}, {r['commission_pct']}, {r['flat_bonus']}, true);")
w("")
w("-- Products (stock = opening stock; seeded sales below reduce it)")
for p in products:
    w(f"insert into public.products (id, sku, name, category, fabric, color, description, selling_price, stock_qty) values "
      f"({q(p['id'])}, {q(p['sku'])}, {q(p['name'])}, {q(p['category'])}, {q(p['fabric'])}, {q(p['color'])}, "
      f"{q(p['description'])}, {p['selling_price']}, {p['opening_stock']});")
w("")
w("-- Customers")
for c in customers:
    consent_at = (f"now() - interval '{c['consent_days_ago']} days'" if c["marketing_consent"] else "null")
    tags = "array[" + ",".join(q(t) for t in c["tags"]) + "]::text[]" if c["tags"] else "'{}'::text[]"
    w(f"insert into public.customers (id, name, phone, email, city, preferred_language, preferred_channel, "
      f"marketing_consent, marketing_consent_at, marketing_consent_source, whatsapp_opt_in, sms_opt_in, email_opt_in, "
      f"telegram_opt_in, date_of_birth, anniversary, tags, created_by, created_at) values "
      f"({q(c['id'])}, {q(c['name'])}, {q(c['phone'])}, {q(c['email'])}, {q(c['city'])}, {q(c['preferred_language'])}, "
      f"{q(c['preferred_channel'])}, {q(c['marketing_consent'])}, {consent_at}, {q(c['marketing_consent_source'])}, "
      f"{q(c['whatsapp_opt_in'])}, {q(c['sms_opt_in'])}, {q(c['email_opt_in'])}, {q(c['telegram_opt_in'])}, "
      f"{q(c['date_of_birth'])}, {q(c['anniversary'])}, {tags}, {q(managers[0]['id'])}, "
      f"now() - interval '{c['created_days_ago']} days');")
w("")
w("-- Sales: created through the same function the app uses, oldest first,")
w("-- so totals, invoice numbers and stock are computed by the database.")
for s in sales:
    payload = {
        "customer": {"id": s["customer_id"]},
        "salesperson_id": s["salesperson_id"],
        "notes": s["notes"],
        "items": s["items"],
        "payments": s["payments"],
    }
    w(f"select public.create_sale_internal({q(json.dumps(payload, ensure_ascii=False))}::jsonb, "
      f"{q(s['manager_id'])}, {ts(s['days_ago'], s['minute_of_day'])});")
w("")
w("-- Bonuses for the last three completed months (older two marked paid)")
owner_id = staff[0]["id"]
for m in seed["bonus_months_back"]:
    w(f"select public.finalize_bonuses_internal((date_trunc('month', now() at time zone 'Asia/Kolkata') - interval '{m} months')::date, {q(owner_id)});")
for m in seed["bonus_paid_months_back"]:
    w(f"update public.bonuses set status = 'paid', paid_at = (date_trunc('month', now() at time zone 'Asia/Kolkata') - interval '{m - 1} months' + interval '4 days') "
      f"where period_start = (date_trunc('month', now() at time zone 'Asia/Kolkata') - interval '{m} months')::date;")
w("")
w("commit;")

with open(os.path.join(ROOT, "supabase", "seed.sql"), "w") as f:
    f.write("\n".join(out) + "\n")

# ---------------------------------------------------------------- summary
print(f"staff={len(staff)} products={len(products)} customers={len(customers)} sales={len(sales)}")
tot = sum(s["_totals"]["total"] for s in sales) / 100
print(f"gross billed Rs {tot:,.0f}; avg bill Rs {tot / len(sales):,.0f}")
for sp in salespeople:
    n = sum(1 for s in sales if s["salesperson_id"] == sp["id"])
    print(f"  {sp['full_name']:<14} bills={n:3d} target={sp['monthly_target']}")
from collections import Counter
print(Counter(s["payments"][0]["method"] if len(s["payments"]) == 1 else "split" for s in sales))
