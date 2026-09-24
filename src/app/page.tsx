import { redirect } from "next/navigation";

/**
 * Root page — redirects to /dashboard if authenticated,
 * or to /login if not (handled by middleware).
 * The middleware will intercept before this renders for unauthenticated users.
 */
export default function RootPage() {
  redirect("/dashboard");
}
