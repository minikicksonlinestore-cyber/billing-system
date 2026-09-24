"use client";

import { useState, useEffect } from "react";
import { createClient } from "@/lib/supabase/client";
import type { Invoice, Customer, InvoiceItem, Product } from "@/types/database";
import {
  FileText,
  Plus,
  Loader2,
  AlertCircle,
  Search,
  Printer,
  Eye,
  Filter,
  Calendar,
  X,
} from "lucide-react";
import Link from "next/link";
import { cn, formatCurrency, formatDate } from "@/lib/utils";
import { A4InvoicePrint } from "@/components/invoices/A4InvoicePrint";
import { DatabaseStatusBanner } from "@/components/layout/DatabaseStatusBanner";

type InvoiceWithDetails = Invoice & {
  customer?: Customer;
  items?: (InvoiceItem & { product?: Product })[];
};

export default function InvoicesPage() {
  const supabase = createClient();

  // Data states
  const [invoices, setInvoices] = useState<InvoiceWithDetails[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Stage 8 Filter states
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [customerFilter, setCustomerFilter] = useState("all");
  const [startDateFilter, setStartDateFilter] = useState("");
  const [endDateFilter, setEndDateFilter] = useState("");

  // Modal / Print state
  const [selectedInvoice, setSelectedInvoice] = useState<InvoiceWithDetails | null>(null);
  const [isFetchingDetail, setIsFetchingDetail] = useState(false);

  const fetchInvoices = async () => {
    setIsLoading(true);
    setError(null);

    try {
      // Fetch invoices and customers
      const [{ data: invs, error: invErr }, { data: custs }] = await Promise.all([
        supabase.from("invoices").select("*, customer:customers(*)").order("created_at", { ascending: false }),
        supabase.from("customers").select("*").order("name"),
      ]);

      if (invErr) {
        setError(invErr.message);
      } else {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const mapped = (invs as any[])?.map((inv) => ({
          ...inv,
          customer: Array.isArray(inv.customer) ? inv.customer[0] : inv.customer,
        })) || [];
        setInvoices(mapped);
      }

      if (custs) setCustomers(custs);
    } catch (err: any) {
      setError(err?.message || "Failed to fetch database records");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchInvoices();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Open A4 Invoice Modal for View / Print / Reprint
  const handleOpenPrintModal = async (invoiceId: string) => {
    setIsFetchingDetail(true);
    const { data: invData, error: err } = await (supabase.from("invoices") as any)
      .select("*, customer:customers(*), items:invoice_items(*, product:products(*))")
      .eq("id", invoiceId)
      .single();

    if (err || !invData) {
      alert("Error loading invoice details for printing.");
    } else {
      const mapped: InvoiceWithDetails = {
        ...invData,
        customer: Array.isArray(invData.customer) ? invData.customer[0] : invData.customer,
        items: (invData.items as any[])?.map((it) => ({
          ...it,
          product: Array.isArray(it.product) ? it.product[0] : it.product,
        })),
      };
      setSelectedInvoice(mapped);
    }
    setIsFetchingDetail(false);
  };

  // Stage 8 Filter Logic
  const filtered = invoices.filter((inv) => {
    // 1. Search filter (Invoice #, Customer Name, Customer Phone)
    const matchesSearch =
      inv.invoice_number.toLowerCase().includes(search.toLowerCase()) ||
      (inv.customer?.name || "").toLowerCase().includes(search.toLowerCase()) ||
      (inv.customer?.phone || "").includes(search);

    // 2. Status filter
    const matchesStatus =
      statusFilter === "all" ? true : inv.status === statusFilter;

    // 3. Customer filter
    const matchesCustomer =
      customerFilter === "all" ? true : inv.customer_id === customerFilter;

    // 4. Date filter (Start Date & End Date)
    let matchesDate = true;
    if (startDateFilter) {
      matchesDate = matchesDate && inv.issue_date >= startDateFilter;
    }
    if (endDateFilter) {
      matchesDate = matchesDate && inv.issue_date <= endDateFilter;
    }

    return matchesSearch && matchesStatus && matchesCustomer && matchesDate;
  });

  const clearFilters = () => {
    setSearch("");
    setStatusFilter("all");
    setCustomerFilter("all");
    setStartDateFilter("");
    setEndDateFilter("");
  };

  const hasActiveFilters =
    search || statusFilter !== "all" || customerFilter !== "all" || startDateFilter || endDateFilter;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">Invoice History</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
            Search, filter, view, print, and reprint customer invoices
          </p>
        </div>
        <Link
          href="/dashboard/invoices/new"
          className="flex items-center justify-center gap-2 px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition-colors"
        >
          <Plus className="w-4 h-4" />
          New Invoice
        </Link>
      </div>

      <DatabaseStatusBanner error={error} />

      {/* Stage 8 Filter Controls Bar */}
      <div className="bg-white dark:bg-gray-800 p-4 rounded-xl border border-gray-200 dark:border-gray-700 space-y-3">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          {/* Search Input */}
          <div className="relative sm:col-span-2">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by Invoice #, Customer or Phone..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-9 pr-4 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          {/* Status Filter */}
          <div className="relative">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="all">All Statuses</option>
              <option value="paid">Paid</option>
              <option value="partially_paid">Partially Paid</option>
              <option value="due">Due / Sent</option>
              <option value="draft">Draft</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>

          {/* Customer Filter */}
          <div className="relative">
            <select
              value={customerFilter}
              onChange={(e) => setCustomerFilter(e.target.value)}
              className="w-full px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg dark:bg-gray-700 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="all">All Customers</option>
              {customers.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>

          {/* Clear Filters Button */}
          {hasActiveFilters && (
            <button
              onClick={clearFilters}
              className="flex items-center justify-center gap-1.5 px-3 py-2 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors border border-red-200 dark:border-red-900/50"
            >
              <X className="w-4 h-4" />
              Clear Filters
            </button>
          )}
        </div>

        {/* Date Filter Row */}
        <div className="flex flex-wrap items-center gap-3 pt-2 border-t border-gray-100 dark:border-gray-700 text-xs text-gray-600 dark:text-gray-400">
          <span className="font-semibold flex items-center gap-1">
            <Calendar className="w-3.5 h-3.5" /> Date Filter:
          </span>
          <div className="flex items-center gap-2">
            <span>From:</span>
            <input
              type="date"
              value={startDateFilter}
              onChange={(e) => setStartDateFilter(e.target.value)}
              className="px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 rounded dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div className="flex items-center gap-2">
            <span>To:</span>
            <input
              type="date"
              value={endDateFilter}
              onChange={(e) => setEndDateFilter(e.target.value)}
              className="px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 rounded dark:bg-gray-700 dark:text-white"
            />
          </div>
        </div>
      </div>

      {/* Invoice History Table */}
      {isLoading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="w-8 h-8 animate-spin text-indigo-600" />
        </div>
      ) : invoices.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
          <FileText className="w-12 h-12 text-gray-300 dark:text-gray-600 mb-4" />
          <h3 className="text-base font-medium text-gray-900 dark:text-white mb-1">No invoices found</h3>
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
            Create your first invoice to view history.
          </p>
          <Link
            href="/dashboard/invoices/new"
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition-colors"
          >
            <Plus className="w-4 h-4" />
            New Invoice
          </Link>
        </div>
      ) : (
        <div className="bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-900/50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Invoice #</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Customer</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Date</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Total</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Paid</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Balance</th>
                <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              {filtered.map((inv) => {
                const status = inv.status || "due";
                const totalAmt = Number(inv.total_amount || 0);
                const paidAmt = Number(inv.amount_paid || 0);
                const balanceAmt = Number(inv.amount_due ?? Math.max(0, totalAmt - paidAmt));

                return (
                  <tr key={inv.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-indigo-600 dark:text-indigo-400">
                      {inv.invoice_number}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                      {inv.customer?.name || "Walk-in Customer"}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                      {formatDate(inv.issue_date)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-bold text-gray-900 dark:text-white">
                      {formatCurrency(totalAmt)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-semibold text-emerald-600 dark:text-emerald-400">
                      {formatCurrency(paidAmt)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-bold text-amber-600 dark:text-amber-400">
                      {formatCurrency(balanceAmt)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-center">
                      <span
                        className={cn(
                          "inline-flex px-2.5 py-0.5 rounded-full text-xs font-bold uppercase tracking-wider",
                          status === "paid" && "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400",
                          status === "partially_paid" && "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400",
                          (status === "due" || status === "sent") && "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400",
                          status === "draft" && "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"
                        )}
                      >
                        {status === "paid" ? "PAID" : status === "partially_paid" ? "PARTIALLY PAID" : status === "draft" ? "DRAFT" : "DUE"}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => handleOpenPrintModal(inv.id)}
                        disabled={isFetchingDetail}
                        className="inline-flex items-center gap-1 px-3 py-1.5 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 hover:bg-indigo-100 dark:hover:bg-indigo-900/50 rounded-lg transition-colors text-xs font-semibold"
                      >
                        <Printer className="w-3.5 h-3.5" />
                        Print / Reprint
                      </button>
                    </td>
                  </tr>
                );
              })}
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={8} className="px-6 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                    No invoices match your filter criteria.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* A4 Printable Invoice Modal */}
      {selectedInvoice && (
        <A4InvoicePrint
          invoice={selectedInvoice}
          onClose={() => setSelectedInvoice(null)}
        />
      )}
    </div>
  );
}
