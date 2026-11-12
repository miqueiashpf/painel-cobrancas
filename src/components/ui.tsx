import type { ComponentProps, ReactNode } from "react";

const cx = (...c: (string | false | null | undefined)[]) => c.filter(Boolean).join(" ");

export function Botao({ variante = "secundario", className, ...props }: ComponentProps<"button"> & { variante?: "primario" | "secundario" | "perigo" | "fantasma" }) {
  return (
    <button
      {...props}
      className={cx(
        "inline-flex items-center justify-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-50",
        variante === "primario" && "bg-destaque text-sobre-destaque hover:bg-destaque-forte",
        variante === "secundario" && "border border-borda bg-superficie text-texto hover:bg-superficie-2",
        variante === "perigo" && "border border-borda bg-superficie text-perigo hover:bg-perigo-fundo",
        variante === "fantasma" && "text-suave hover:bg-superficie-2 hover:text-texto",
        className,
      )}
    />
  );
}

export function Campo({ rotulo, id, children, dica }: { rotulo: string; id: string; children: ReactNode; dica?: string }) {
  return (
    <div className="grid gap-1.5">
      <label htmlFor={id} className="text-xs font-semibold uppercase tracking-wider text-suave">{rotulo}</label>
      {children}
      {dica && <p className="text-xs text-suave">{dica}</p>}
    </div>
  );
}

export const classeEntrada =
  "w-full min-w-0 rounded-lg border border-borda bg-fundo px-3 py-2 text-sm text-texto placeholder:text-suave/70";

export function Painel({ titulo, acao, children, className }: { titulo?: string; acao?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section className={cx("min-w-0 rounded-xl border border-borda bg-superficie", className)}>
      {(titulo || acao) && (
        <header className="flex flex-wrap items-center justify-between gap-3 border-b border-borda px-5 py-3.5">
          {titulo && <h2 className="font-display text-base font-semibold">{titulo}</h2>}
          {acao}
        </header>
      )}
      <div className="p-5">{children}</div>
    </section>
  );
}

export function Selo({ tom, children }: { tom: "ok" | "alerta" | "perigo" | "neutro"; children: ReactNode }) {
  return (
    <span
      className={cx(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-semibold",
        tom === "ok" && "bg-ok-fundo text-ok",
        tom === "alerta" && "bg-alerta-fundo text-alerta",
        tom === "perigo" && "bg-perigo-fundo text-perigo",
        tom === "neutro" && "bg-superficie-2 text-suave",
      )}
    >
      <span aria-hidden className="size-1.5 rounded-full bg-current" />
      {children}
    </span>
  );
}

export function Mensagem({ tom, children }: { tom: "ok" | "perigo"; children: ReactNode }) {
  return (
    <p role={tom === "perigo" ? "alert" : "status"} className={cx("rounded-lg px-3 py-2 text-sm", tom === "ok" ? "bg-ok-fundo text-ok" : "bg-perigo-fundo text-perigo")}>
      {children}
    </p>
  );
}

export function TituloPagina({ titulo, descricao, acao }: { titulo: string; descricao?: string; acao?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight text-balance">{titulo}</h1>
        {descricao && <p className="mt-1 max-w-prose text-sm text-suave">{descricao}</p>}
      </div>
      {acao}
    </div>
  );
}

export { cx };
