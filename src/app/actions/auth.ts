"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { getExpectedPassword, createSessionToken, SESSION_COOKIE_NAME } from "@/lib/auth";

export async function loginAction(password: string): Promise<{ success: boolean; error?: string }> {
  if (!password || typeof password !== "string") {
    return { success: false, error: "Password is required." };
  }

  const expectedPassword = getExpectedPassword();

  if (password.trim() !== expectedPassword.trim()) {
    return { success: false, error: "Incorrect password. Please try again." };
  }

  const cookieStore = await cookies();
  const sessionToken = createSessionToken(expectedPassword);

  cookieStore.set(SESSION_COOKIE_NAME, sessionToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30, // 30 days
  });

  return { success: true };
}

export async function logoutAction(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE_NAME, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
  redirect("/login");
}
