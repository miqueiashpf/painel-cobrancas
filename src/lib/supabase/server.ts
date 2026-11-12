import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { env } from "@/lib/env";
import { cookieOptions } from "./cookies";

/**
 * Cliente do Supabase com a sessão do usuário logado.
 * Toda consulta passa pelas regras de acesso (RLS) do banco.
 */
export async function criarClienteSupabase() {
  const cookieStore = await cookies();
  const { SUPABASE_URL, SUPABASE_ANON_KEY } = env();
  return createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookieOptions,
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (lista) => {
        try {
          for (const { name, value, options } of lista) cookieStore.set(name, value, options);
        } catch {
          // Chamado durante a renderização de um Server Component: o proxy renova os cookies.
        }
      },
    },
  });
}
