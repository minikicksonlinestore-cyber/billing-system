import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "@/types/database";

function getCredentials() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  const isValidUrl = url && url.startsWith("http");
  return {
    supabaseUrl: isValidUrl ? url : "https://placeholder.supabase.co",
    supabaseAnonKey: key && key !== "your_supabase_anon_key" ? key : "placeholder-key",
  };
}

/**
 * Creates a Supabase client for use in browser/client components.
 * Uses the public anon key — safe to expose to the client.
 */
export function createClient() {
  const { supabaseUrl, supabaseAnonKey } = getCredentials();
  return createBrowserClient<Database>(supabaseUrl, supabaseAnonKey);
}
