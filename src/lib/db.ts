/* eslint-disable @typescript-eslint/no-explicit-any */
type QueryResult = { data: any; error: any; count?: number | null };

function createChainable(): any {
  const resultPromise = Promise.resolve({ data: [], error: null, count: 0 });

  const handler: ProxyHandler<any> = {
    get(_target, prop) {
      if (prop === "then") {
        return (onfulfilled?: (value: QueryResult) => any, onrejected?: (reason: any) => any) =>
          resultPromise.then(onfulfilled, onrejected);
      }
      if (prop === "catch") {
        return (onrejected?: (reason: any) => any) => resultPromise.catch(onrejected);
      }
      if (prop === "single") {
        return () => Promise.resolve({ data: null, error: null });
      }
      if (prop === "maybeSingle") {
        return () => Promise.resolve({ data: null, error: null });
      }
      return () => proxy;
    },
  };

  const proxy: any = new Proxy({}, handler);
  return proxy;
}

export const db = {
  from: (_table: string) => createChainable(),
  auth: {
    getUser: () => Promise.resolve({ data: { user: { id: "mock-user-id", email: "user@example.com", user_metadata: { full_name: "Admin User" }, created_at: "", updated_at: "" } }, error: null }),
    signUp: (_args?: any) => Promise.resolve({ data: { user: { id: "mock-user-id" } }, error: null }),
    exchangeCodeForSession: (_code: string) => Promise.resolve({ error: null }),
    onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
  },
  rpc: (_fn: string, _args?: any) => Promise.resolve({ data: null, error: null }),
};

export const isDbConfigured = () => false;
