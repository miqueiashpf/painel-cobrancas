const moeda = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const dataHora = new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short", timeZone: "America/Sao_Paulo" });
const mesAno = new Intl.DateTimeFormat("pt-BR", { month: "long", year: "numeric", timeZone: "UTC" });

export const reais = (centavos: number) => moeda.format(centavos / 100);
export const quando = (iso: string) => dataHora.format(new Date(iso));
export const nomeDoMes = (isoData: string) => mesAno.format(new Date(`${isoData}T00:00:00Z`));

/** Primeiro dia do mês atual no fuso de Brasília, em AAAA-MM-01. */
export function competenciaAtual(agora = new Date()) {
  const partes = new Intl.DateTimeFormat("en-CA", { timeZone: "America/Sao_Paulo", year: "numeric", month: "2-digit" }).format(agora);
  return `${partes}-01`;
}
