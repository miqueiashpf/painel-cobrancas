-- Gera as mensalidades no dia 1 de cada mês, às 08:00 de Brasília (11:00 UTC).
-- Requer a extensão pg_cron (Supabase: Database > Extensions > pg_cron).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule(
      'gerar-mensalidades',
      '0 11 1 * *',
      $job$ select public.gerar_mensalidades((now() at time zone 'America/Sao_Paulo')::date) $job$
    );
  else
    raise notice 'pg_cron indisponível: gere as mensalidades pelo painel.';
  end if;
end
$$;
