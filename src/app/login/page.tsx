import { redirect } from "next/navigation";
import { lerSessao } from "@/lib/auth";
import { FormularioLogin } from "./formulario";
import { Mensagem } from "@/components/ui";

const ERROS: Record<string, string> = {
  "link-invalido": "Este link expirou ou já foi usado. Peça um novo abaixo.",
  "sem-acesso": "Este e-mail não tem acesso ao painel. Peça um convite ao administrador.",
};

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  if (await lerSessao()) redirect("/");
  const { erro } = await searchParams;
  const mensagemErro = typeof erro === "string" ? ERROS[erro] : undefined;

  return (
    <main className="grid min-h-dvh place-items-center px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex items-center gap-3">
          <Escudo />
          <div>
            <p className="font-display text-xl font-bold leading-tight">Painel da Pelada</p>
            <p className="text-sm text-suave">Segundas, 23h</p>
          </div>
        </div>
        <div className="grid gap-5 rounded-xl border border-borda bg-superficie p-6">
          <div>
            <h1 className="font-display text-lg font-semibold">Entrar</h1>
            <p className="mt-1 text-sm text-suave">Digite seu e-mail e enviaremos um link de acesso. Sem senha.</p>
          </div>
          {mensagemErro && <Mensagem tom="perigo">{mensagemErro}</Mensagem>}
          <FormularioLogin />
        </div>
        <p className="mt-6 text-center text-xs text-suave">O acesso é só por convite do administrador.</p>
      </div>
    </main>
  );
}

function Escudo() {
  return (
    <svg width="40" height="40" viewBox="0 0 40 40" aria-hidden className="shrink-0">
      <rect width="40" height="40" rx="10" className="fill-destaque" />
      <circle cx="20" cy="20" r="9" fill="none" strokeWidth="2" className="stroke-sobre-destaque" />
      <path d="M20 4v32M4 20h7M29 20h7" strokeWidth="2" className="stroke-sobre-destaque" />
    </svg>
  );
}
