import "server-only";
import { z } from "zod";

const schema = z.object({
  SUPABASE_URL: z.url(),
  SUPABASE_ANON_KEY: z.string().min(20),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20),
  SITE_URL: z.url().transform((u) => u.replace(/\/+$/, "")),
});

let cache: z.infer<typeof schema> | null = null;

/** Lê e valida as variáveis de ambiente na primeira vez que forem usadas. */
export function env() {
  if (!cache) {
    const parsed = schema.safeParse(process.env);
    if (!parsed.success) {
      const faltando = parsed.error.issues.map((i) => i.path.join(".")).join(", ");
      throw new Error(`Variáveis de ambiente inválidas ou ausentes: ${faltando}`);
    }
    cache = parsed.data;
  }
  return cache;
}
