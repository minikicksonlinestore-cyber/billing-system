const SESSION_COOKIE_NAME = "auth_session";
const DEFAULT_PASSWORD = "oldbeach@786";

export function getExpectedPassword(): string {
  return process.env.AUTH_PASSWORD || DEFAULT_PASSWORD;
}

export function createSessionToken(password: string): string {
  const secret = getExpectedPassword();
  const raw = `${password}::${secret}::billing_secure_session_2026`;
  
  let hash = 0;
  for (let i = 0; i < raw.length; i++) {
    const char = raw.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  return `sess_${Math.abs(hash).toString(36)}`;
}

export function isValidSessionToken(token: string | null | undefined): boolean {
  if (!token) return false;
  const validToken = createSessionToken(getExpectedPassword());
  return token === validToken;
}

export { SESSION_COOKIE_NAME };
