#!/usr/bin/env python3
"""Role / RLS / billing tests for the Supabase schema, run against a local
PostgreSQL that has supabase_stub.sql + migrations + seed loaded.
Usage: see supabase/tests/run_tests.sh"""
import json, os, re, shlex, subprocess, sys, uuid
PSQL = shlex.split(os.environ.get('PSQL', 'psql -d sb')) + ['-tA', '-v', 'ON_ERROR_STOP=1']
NS = uuid.UUID("6b1e2e00-5b5b-4a11-9a7c-5a4b2b1c0d00")
uid = lambda k, key: str(uuid.uuid5(NS, f"{k}:{key}"))
OWNER, MGR, PRIYA, RAHUL = (uid('user', e) for e in ['owner@shahbrothers.in','manager@shahbrothers.in','priya@shahbrothers.in','rahul@shahbrothers.in'])
fails = 0
def run(sql, as_user=None, role='authenticated'):
    pre = ""
    if as_user or role == 'anon':
        pre = f"set role {role}; set request.jwt.claim.sub = '{as_user or ''}';"
    p = subprocess.run(PSQL, input=pre + "\n" + sql, capture_output=True, text=True)
    out = [l for l in p.stdout.strip().split('\n') if l and not re.match(r'^(SET|UPDATE \d+|INSERT \d+ \d+)$', l)]
    return p.returncode, out, p.stderr.strip()
def check(name, cond, detail=''):
    global fails
    print(('PASS ' if cond else 'FAIL ') + name + ('' if cond else f'  -> {detail}'))
    if not cond: fails += 1

def compute(items, rate):
    sub = disc = 0
    for it in items:
        g = it['quantity'] * round(it['unit_price']*100); sub += g
        v = it.get('discount_value', 0)
        if it.get('discount_type') == 'percent': disc += (g*round(v*100)+5000)//10000
        else: disc += round(v*100)
    tax = sub-disc; gst = (tax*round(rate*100)+5000)//10000; pre = tax+gst; tot = ((pre+50)//100)*100
    return dict(sub=sub, disc=disc, tax=tax, gst=gst, cgst=(gst+1)//2, round=tot-pre, total=tot)

total_sales = int(run("select count(*) from sales")[1][0])
priya_sales = int(run(f"select count(*) from sales where salesperson_id='{PRIYA}'")[1][0])

# --- salesperson
rc, out, err = run("select count(*) from sales", PRIYA)
check("salesperson sees only own sales", int(out[0]) == priya_sales, out)
rc, out, err = run("select count(*) from sale_items si join sales s on s.id=si.sale_id where s.salesperson_id <> auth.uid()", PRIYA)
check("salesperson sees no other sale items", out[0] == '0', out)
rc, out, err = run("select count(*) from customers", PRIYA)
exp = run(f"select count(distinct customer_id) from sales where salesperson_id='{PRIYA}'")[1][0]
check("salesperson sees only own customers", out[0] == exp, (out, exp))
rc, out, err = run("select count(distinct salesperson_id) from bonuses", PRIYA)
check("salesperson sees only own bonuses", out[0] == '1', out)
rc, out, err = run("select public.create_sale('{}'::jsonb)", PRIYA)
check("salesperson cannot create bills", rc != 0 and 'Only owners and managers' in err, err)
rc, out, err = run("update products set selling_price = 1 returning id", PRIYA)
check("salesperson cannot edit products", out == [] , out)
rc, out, err = run("select count(*) from invoice_counters", PRIYA)
check("invoice counters hidden", out[0] == '0', out)
rc, out, err = run(f"select public.create_sale_internal('{{}}'::jsonb, '{PRIYA}', now())", PRIYA)
check("internal sale function not callable", rc != 0 and 'permission denied' in err, err)
rc, out, err = run("update users set role='owner' where id = auth.uid() returning id", PRIYA)
check("salesperson cannot escalate role", out == [], out)

# --- anon
rc, out, err = run("select count(*) from sales", None, 'anon')
check("anon sees no sales", out and out[0] == '0', (out, err))

# --- manager creates a bill
items = [
  {"product_id": uid('product','KAN-001'), "product_name": "Kanjeevaram Temple Border", "product_code": "KAN-001", "quantity": 1, "unit_price": 24500, "discount_type": "percent", "discount_value": 7.5},
  {"product_id": None, "product_name": "Fall & pico", "product_code": "SRV", "quantity": 3, "unit_price": 149.99, "discount_type": "amount", "discount_value": 50.5},
]
c = compute(items, 5.0)
stock_before = int(run(f"select stock_qty from products where sku='KAN-001'")[1][0])
pay_ok = [{"method":"cash","amount":5000},{"method":"upi","amount": c['total']/100 - 5000, "reference":"UPI123"}]
payload = {"customer":{"name":"Test Customer","phone":"9123456780"},"salesperson_id":RAHUL,"items":items,"payments":[{"method":"cash","amount":c['total']/100 - 1}]}
rc, out, err = run(f"select public.create_sale('{json.dumps(payload)}'::jsonb)", MGR)
check("payment mismatch rejected", rc != 0 and 'do not match' in err, err)
payload["payments"] = pay_ok
rc, out, err = run(f"select public.create_sale('{json.dumps(payload)}'::jsonb)", MGR)
check("manager creates split bill", rc == 0, err)
sid = out[0] if out else None
rc, out, err = run(f"select subtotal*100, discount_total*100, taxable_amount*100, gst_amount*100, cgst_amount*100, round_off*100, total*100, payment_mode, invoice_number, manager_id from sales where id='{sid}'", MGR)
row = out[0].split('|') if out else []
got = dict(sub=int(float(row[0])), disc=int(float(row[1])), tax=int(float(row[2])), gst=int(float(row[3])), cgst=int(float(row[4])), round=int(float(row[5])), total=int(float(row[6]))) if row else {}
check("server totals == reference maths", got == c, (got, c))
check("split payment mode", row and row[7] == 'split', row)
import datetime as _dt
_t = _dt.datetime.now(_dt.timezone(_dt.timedelta(hours=5, minutes=30)))
_fy = _t.year if _t.month >= 4 else _t.year - 1
check("invoice number sequential", row and row[8] == f"SB/{_fy % 100:02d}-{(_fy + 1) % 100:02d}/{total_sales+1:05d}", row)
check("bill linked to manager", row and row[9] == MGR, row)
check("stock decremented", int(run("select stock_qty from products where sku='KAN-001'")[1][0]) == stock_before - 1)
payload2 = dict(payload); payload2["customer"] = {"name": "Different Name", "phone": "9123456780"}
payload2["items"] = [{"product_name":"X","product_code":"X","quantity":1,"unit_price":1000,"discount_type":"amount","discount_value":0}]
payload2["payments"] = [{"method":"card","amount":1050}]
rc, out, err = run(f"select public.create_sale('{json.dumps(payload2)}'::jsonb)", MGR)
check("same phone reuses customer", rc == 0 and run("select count(*), max(name) from customers where phone='9123456780'")[1][0] == '1|Test Customer', (err, run("select count(*), max(name) from customers where phone='9123456780'")))
bad = dict(payload2); bad["items"] = [{"product_name":"X","product_code":"X","quantity":1,"unit_price":1000,"discount_type":"amount","discount_value":1500}]
rc, out, err = run(f"select public.create_sale('{json.dumps(bad)}'::jsonb)", MGR)
check("discount > item value rejected", rc != 0 and 'more than the item value' in err, err)
bad = dict(payload2); bad["customer"] = {"name":"Y","phone":"12345"}
rc, out, err = run(f"select public.create_sale('{json.dumps(bad)}'::jsonb)", MGR)
check("invalid phone rejected", rc != 0 and '10-digit' in err, err)
bad = dict(payload2); bad["salesperson_id"] = MGR
rc, out, err = run(f"select public.create_sale('{json.dumps(bad)}'::jsonb)", MGR)
check("non-salesperson rejected", rc != 0 and 'valid salesperson' in err, err)
rc, out, err = run("select count(*) from bonuses", MGR)
check("manager cannot see bonuses", out[0] == '0', out)
rc, out, err = run("update app_settings set gst_rate = 12 returning id", MGR)
check("manager cannot change GST", out == [], out)
rc, out, err = run(f"select public.cancel_sale('{sid}', 'test')", MGR)
check("manager cannot cancel", rc != 0, err)
rc, out, err = run("select public.finalize_bonuses(date_trunc('month', now() - interval '1 month')::date)", MGR)
check("manager cannot finalise bonuses", rc != 0, err)
rc, out, err = run("select count(*) from sales", MGR)
check("manager sees all sales", int(out[0]) == total_sales + 2, out)
rc, out, err = run("insert into customers(name, phone, marketing_consent, whatsapp_opt_in) values ('Z','9000000001', false, true)", MGR)
check("opt-in without consent rejected", rc != 0 and 'optin_requires_consent' in err, err)

# --- owner
rc, out, err = run("update app_settings set gst_rate = 12 returning gst_rate", OWNER)
check("owner can change GST", out == ['12.00'], (out, err))
run("update app_settings set gst_rate = 5", OWNER)
rc, out, err = run(f"select public.cancel_sale('{sid}', 'Customer returned')", OWNER)
check("owner cancels invoice", rc == 0, err)
check("cancel restores stock", int(run("select stock_qty from products where sku='KAN-001'")[1][0]) == stock_before)
rc, out, err = run(f"select public.cancel_sale('{sid}', 'again')", OWNER)
check("double cancel rejected", rc != 0, err)
rc, out, err = run("select public.finalize_bonuses(date_trunc('month', now() at time zone 'Asia/Kolkata')::date)", OWNER)
check("current month cannot be finalised", rc != 0 and 'completed months' in err, err)
rc, out, err = run("select public.finalize_bonuses((date_trunc('month', now() at time zone 'Asia/Kolkata') - interval '1 month')::date)", OWNER)
check("owner finalises last month", rc == 0 and out[0] == '6', (out, err))
rc, out, err = run("select count(*) from bonuses where status='paid'", OWNER)
check("paid bonuses untouched by re-finalise", out[0] == '12', out)
rc, out, err = run("select count(*), sum(total_spent) > 0 from customer_stats where purchase_count > 0", OWNER)
check("customer_stats view works", rc == 0 and out[0].startswith('35|t'), (out, err))
rc, out, err = run("select count(*) from customer_stats where purchase_count > 0", PRIYA)
check("customer_stats respects RLS", int(out[0]) < 35, out)
print("FAILURES:", fails)
sys.exit(1 if fails else 0)
