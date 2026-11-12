import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { criarClienteSupabase } from "@/lib/supabase/server";

// Só os tipos de link que este sistema envia.
const TIPOS_ACEITOS: EmailOtpType[] = ["email", "magiclink", "invite"];

/**
 * Destino dos links enviados por e-mail (convite e acesso).
 * Valida o token no servidor, cria a sessão e confere o convite.
 */
export async function GET(request: NextRequest) {
  const tokenHash = request.nextUrl.searchParams.get("token_hash");
  const tipo = request.nextUrl.searchParams.get("type") as EmailOtpType | null;
  const destino = (caminho: string) => NextResponse.redirect(new URL(caminho, request.nextUrl.origin));

  if (!tokenHash || !tipo || !TIPOS_ACEITOS.includes(tipo) || tokenHash.length > 200) {
    return destino("/login?erro=link-invalido");
  }

  const supabase = await criarClienteSupabase();
  const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: tipo });
  if (error) return destino("/login?erro=link-invalido");

  // Primeiro acesso: transforma o convite em usuário. Depois: confere se segue ativo.
  const { data: papel, error: erroConvite } = await supabase.rpc("aceitar_convite");
  if (erroConvite || !papel) {
    await supabase.auth.signOut();
    return destino("/login?erro=sem-acesso");
  }
  return destino("/");
}
