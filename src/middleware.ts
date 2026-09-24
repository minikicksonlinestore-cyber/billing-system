import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

function getCredentials() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  const isValidUrl =
    url &&
    url.startsWith("http") &&
    !url.includes("your_supabase_project_url") &&
    !url.includes("placeholder");

  const isValidKey =
    key &&
    key !== "your_supabase_anon_key" &&
    key !== "placeholder-key";

  return {
    supabaseUrl: isValidUrl ? url : null,
    supabaseAnonKey: isValidKey ? key : null,
  };
}

/**
 * Middleware that:
 * 1. Refreshes the Supabase Auth session on each request
 * 2. Protects dashboard routes — redirects unauthenticated users to /login
 * 3. Redirects authenticated users away from /login to the dashboard
 */
export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const { supabaseUrl, supabaseAnonKey } = getCredentials();
  const { pathname } = request.nextUrl;

  // Public routes that do not require authentication
  const publicRoutes = ["/login", "/signup", "/forgot-password", "/reset-password", "/auth/callback"];
  const isPublicRoute = publicRoutes.some((route) => pathname.startsWith(route));

  // If Supabase environment variables are not configured in deployment, allow public routes to render
  if (!supabaseUrl || !supabaseAnonKey) {
    if (isPublicRoute) {
      return supabaseResponse;
    }
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = "/login";
    return NextResponse.redirect(redirectUrl);
  }

  let user = null;

  try {
    const supabase = createServerClient(
      supabaseUrl,
      supabaseAnonKey,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value }) =>
              request.cookies.set(name, value)
            );
            supabaseResponse = NextResponse.next({ request });
            cookiesToSet.forEach(({ name, value, options }) =>
              supabaseResponse.cookies.set(name, value, options)
            );
          },
        },
      }
    );

    // Refresh the session — safe call inside try/catch
    const { data } = await supabase.auth.getUser();
    user = data?.user ?? null;
  } catch {
    // If fetching user fails due to network error or bad token, user remains null
    user = null;
  }

  // If user is not authenticated and trying to access a protected route
  if (!user && !isPublicRoute) {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = "/login";
    redirectUrl.searchParams.set("redirectedFrom", pathname);
    return NextResponse.redirect(redirectUrl);
  }

  // If user is authenticated and trying to access auth pages, redirect to dashboard
  if (user && isPublicRoute && pathname !== "/auth/callback") {
    const redirectUrl = request.nextUrl.clone();
    redirectUrl.pathname = "/dashboard";
    return NextResponse.redirect(redirectUrl);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder files (.svg, .png, .jpg, etc.)
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
