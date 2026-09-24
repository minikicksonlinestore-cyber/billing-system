"use client";

import { AlertTriangle, ExternalLink } from "lucide-react";
import { isSupabaseConfigured } from "@/lib/supabase/client";

interface DatabaseStatusBannerProps {
  error?: string | null;
}

export function DatabaseStatusBanner({ error }: DatabaseStatusBannerProps) {
  const isConfigured = isSupabaseConfigured();
  const isFetchError =
    error?.includes("Failed to fetch") ||
    error?.includes("TypeError") ||
    !isConfigured;

  if (!isFetchError && !error) return null;

  return (
    <div className="p-4 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 text-amber-900 dark:text-amber-200 text-sm space-y-2 mb-6">
      <div className="flex items-start gap-3">
        <AlertTriangle className="w-5 h-5 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5" />
        <div className="space-y-1">
          <p className="font-semibold text-amber-900 dark:text-amber-100">
            Database Connection Warning
          </p>
          <p className="text-xs text-amber-800 dark:text-amber-300 leading-relaxed">
            {!isConfigured
              ? "Supabase environment variables (NEXT_PUBLIC_SUPABASE_URL & NEXT_PUBLIC_SUPABASE_ANON_KEY) are missing in your production deployment settings."
              : "Unable to reach your Supabase database server. Please verify your Supabase project is active (not paused) and environment variables are set in Vercel."}
          </p>
          <div className="pt-1 flex flex-wrap items-center gap-4 text-xs font-medium text-amber-800 dark:text-amber-400">
            <a
              href="https://vercel.com/dashboard"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 underline hover:text-amber-900 dark:hover:text-amber-200"
            >
              Open Vercel Settings <ExternalLink className="w-3 h-3" />
            </a>
            <a
              href="https://supabase.com/dashboard"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1 underline hover:text-amber-900 dark:hover:text-amber-200"
            >
              Open Supabase Dashboard <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
