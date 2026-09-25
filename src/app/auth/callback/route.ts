import { NextResponse } from "next/server";
import { db } from '@/lib/db';

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    try {
      
      const { error } = await db.auth.exchangeCodeForSession(code);
      if (!error) {
        return NextResponse.redirect(`${origin}${next}`);
      }
    } catch {
      // Ignore errors and fallback to redirect
    }
  }

  // Return user to login if authentication fails
  return NextResponse.redirect(`${origin}/login?error=Could%20not%20authenticate%20user`);
}
