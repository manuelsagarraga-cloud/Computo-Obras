-- Emitir / reabrir un certificado en UNA transacción (todo o nada).
-- Antes: el cliente mandaba los ítems en tandas y después cambiaba el estado; si se cortaba a mitad,
-- quedaban ítems congelados y otros no, o el certificado en borrador con precios a medias.
-- SECURITY INVOKER: corre con los permisos del usuario, así que las políticas RLS de
-- certificados y cert_items se aplican igual que hoy.
create or replace function public.cert_cambiar_estado(p_cert_id uuid, p_estado text, p_items jsonb)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_estado text;
  v_n int := 0;
  v_esperados int := coalesce(jsonb_array_length(p_items), 0);
begin
  if p_estado not in ('emitido', 'borrador') then
    raise exception 'Estado inválido: %', p_estado;
  end if;

  -- Bloquea el certificado: dos emisiones simultáneas no se pisan
  select estado into v_estado from certificados where id = p_cert_id for update;
  if not found then
    raise exception 'Certificado no encontrado o sin permiso';
  end if;
  if p_estado = 'emitido' and v_estado = 'emitido' then
    raise exception 'El certificado ya está emitido';
  end if;
  if p_estado = 'borrador' and v_estado is distinct from 'emitido' then
    raise exception 'Solo se puede reabrir un certificado emitido';
  end if;

  update cert_items ci set
    contratista      = x.contratista,
    costo_unit       = x.costo_unit,
    pct_actual       = x.pct_actual,
    economia_demasia = x.economia_demasia,
    pct_ed           = x.pct_ed,
    precio_manual    = coalesce(x.precio_manual, false)
  from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb))
       as x(id uuid, contratista text, costo_unit numeric, pct_actual numeric,
            economia_demasia numeric, pct_ed numeric, precio_manual boolean)
  where ci.id = x.id and ci.cert_id = p_cert_id;
  get diagnostics v_n = row_count;

  if v_n <> v_esperados then
    raise exception 'Se esperaban % ítems y se actualizaron %: no se cambió nada', v_esperados, v_n;
  end if;

  update certificados set estado = p_estado where id = p_cert_id;
  return v_n;
end
$$;

revoke all on function public.cert_cambiar_estado(uuid, text, jsonb) from public, anon;
grant execute on function public.cert_cambiar_estado(uuid, text, jsonb) to authenticated;
