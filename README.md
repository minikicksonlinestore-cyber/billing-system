# Billing & Inventory Management System

A production-grade, full-stack GST Billing & Inventory Management System built with **Next.js 16 (Turbopack)**, **TypeScript**, **Tailwind CSS v4**, and **Supabase PostgreSQL & Auth**.

---

## 🚀 Key Features

- **Dashboard**: Real-time business metrics (Total Sales, Total Paid, Total Balance, Invoices, Low-Stock Alerts).
- **Product & Category Management**: Full CRUD operations with SKU, HSN/SAC codes, Purchase & Selling prices, GST rates, and stock thresholds.
- **Inventory Management**: Real-time stock tracking, manual adjustments (additions/reductions), movement audit logs, and low-stock warnings.
- **POS / New Bill Screen**: Product search, customer inline creation, line item discounts, auto-calculated GST & subtotal, and pre-confirmation bill preview.
- **Payment Processing**: Staff manual paid amount entry, automatic balance calculation (`Total - Paid`), and status handling (`PAID`, `PARTIALLY PAID`, `DUE`).
- **Atomic Invoice Confirmation**: Stored procedure transactions (`confirm_invoice_transaction`) ensuring stock is deducted **only** upon invoice confirmation.
- **Invoice History & A4 Printable Layout**: Printable GST Tax Invoice template formatted to standard A4 dimensions (210mm x 297mm) with reprinting support.
- **Customer & Due Management**: Track customer purchase history and manage outstanding invoice balances with payment history logs.
- **Reports & Analytics**: Daily, Weekly, Monthly, Yearly sales totals, Product sales reports, Customer analytics, Stock reports, and Date Range filters.
- **Shop Settings**: Dynamic store configuration (Name, Address, Phone, Email, GSTIN, Logo, Terms & Conditions) automatically integrated into printable invoices.

---

## 🛠️ Environment Configuration

Create a `.env.local` file in the root directory:

```env
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key

# App Configuration
NEXT_PUBLIC_APP_NAME="Billing & Inventory Manager"
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

---

## 💻 Getting Started

First, install dependencies and run the development server:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser.

---

## 📦 Database & Migrations

Database schema and RPC procedures are located in the `supabase/migrations/` directory:
- `001_initial_schema.sql`
- `002_add_hsn_sac.sql`
- `003_adjust_stock_rpc.sql`
- `004_add_payment_status.sql`
- `005_confirm_invoice_rpc.sql`
