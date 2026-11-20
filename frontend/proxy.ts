import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { TOKEN_COOKIE } from "@/lib/auth";

const LOGIN_PATH = "/login";

// Optimistic auth check: only verifies a token cookie exists.
// The API remains the source of truth and returns 401 for invalid tokens.
export function proxy(request: NextRequest) {
  const token = request.cookies.get(TOKEN_COOKIE)?.value;
  const isLoginPage = request.nextUrl.pathname === LOGIN_PATH;

  if (!token && !isLoginPage) {
    return NextResponse.redirect(new URL(LOGIN_PATH, request.nextUrl));
  }

  if (token && isLoginPage) {
    return NextResponse.redirect(new URL("/", request.nextUrl));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!api|_next/|__nextjs|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
