import type { CookieOptionsWithName } from "@supabase/ssr";

/** Duração máxima da sessão sem uso: 8 horas. Cada requisição renova o prazo. */
export const SESSAO_SEGUNDOS = 8 * 60 * 60;

// HttpOnly: o JavaScript da página nunca lê o token de acesso,
// então um eventual XSS não consegue roubar a sessão.
export const cookieOptions: CookieOptionsWithName = {
  path: "/",
  httpOnly: true,
  secure: process.env.NODE_ENV === "production",
  sameSite: "lax",
  maxAge: SESSAO_SEGUNDOS,
};
