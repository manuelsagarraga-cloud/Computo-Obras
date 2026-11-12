-- 2026-11-12 · Hormigones sin asentamiento + versión con binder de cada tipo + H25 con binder en losas y muros + casetones 40x40
-- Correr POR PASOS. Cada paso de escritura tiene antes su SELECT de verificación.
-- Los materiales se referencian por NOMBRE en coeficientes.mats[].matRef y como CLAVE en mediciones.mat_overrides:
-- el renombre y la actualización de referencias van en la misma transacción.

-- =====================================================================
-- PASO 0 · Verificación (solo lectura). Esperado al 12-nov:
--   MAT-034 H17 as.8 $207.582 · MAT-035 H21 as.8 $219.222 · MAT-036 H21 as.12,5 $225.000
--   MAT-160 H8 as.8 $0 · MAT-161 H25 as.8 $0
--   20 tareas usan "H17 asentamiento 8"; 5 mediciones con mat_overrides (2 → MAT-035, 3 → MAT-036)
--   24 mediciones en 4.19 (8), 4.28 (5), 4.29 (3), 4.31 (8)
-- =====================================================================
select cod, id, nombre, precio from materiales where cod in ('MAT-034','MAT-035','MAT-036','MAT-160','MAT-161') order by cod;
select c.rubro, c.cod, c.nombre, m->>'matRef' ref
  from coeficientes c, jsonb_array_elements(c.mats) m
 where m->>'matRef' ilike 'Hormigón elaborado H% asentamiento%' order by 1,2;
select m.id, c.cod, m.mat_overrides from mediciones m join coeficientes c on c.id::text = m.coef_id
 where m.mat_overrides is not null and m.mat_overrides::text <> '{}';

-- =====================================================================
-- PASO 1 · Respaldo (esquema respaldo, no public)
-- =====================================================================
create table respaldo.materiales_20261112   as select * from public.materiales;
create table respaldo.coeficientes_20261112 as select * from public.coeficientes;
create table respaldo.mediciones_ovr_20261112 as select id, mat_overrides, descripcion from public.mediciones;

-- =====================================================================
-- PASO 2 · Quitar el asentamiento y fusionar H21 (MAT-036 → MAT-035)
-- =====================================================================
begin;
-- 2a. Nombres sin asentamiento
update materiales set nombre = 'Hormigón elaborado H17' where cod = 'MAT-034' and nombre = 'Hormigón elaborado H17 asentamiento 8';
update materiales set nombre = 'Hormigón elaborado H21' where cod = 'MAT-035' and nombre = 'Hormigón elaborado H21 asentamiento 8';
update materiales set nombre = 'Hormigón elaborado H8'  where cod = 'MAT-160' and nombre = 'Hormigón elaborado H8 asentamiento 8';
update materiales set nombre = 'Hormigón elaborado H25'  where cod = 'MAT-161' and nombre = 'Hormigón elaborado H25 asentamiento 8';

-- 2b. Tareas que apuntan a los nombres viejos
update coeficientes c set mats = (
  select jsonb_agg(case m->>'matRef'
      when 'Hormigón elaborado H17 asentamiento 8'   then jsonb_set(m, '{matRef}', '"Hormigón elaborado H17"')
      when 'Hormigón elaborado H21 asentamiento 8'   then jsonb_set(m, '{matRef}', '"Hormigón elaborado H21"')
      when 'Hormigón elaborado H21 asentamiento 12,5' then jsonb_set(m, '{matRef}', '"Hormigón elaborado H21"')
      when 'Hormigón elaborado H8 asentamiento 8'    then jsonb_set(m, '{matRef}', '"Hormigón elaborado H8"')
      when 'Hormigón elaborado H25 asentamiento 8'   then jsonb_set(m, '{matRef}', '"Hormigón elaborado H25"')
      else m end order by ord)
  from jsonb_array_elements(c.mats) with ordinality as t(m, ord))
where c.mats::text ilike '%asentamiento%';

-- 2c. Claves de mat_overrides (nombre del material base) y valor MAT-036 → MAT-035
update mediciones set mat_overrides = (
  select jsonb_object_agg(replace(replace(k, ' asentamiento 12,5', ''), ' asentamiento 8', ''),
         case when v = to_jsonb((select id::text from materiales where cod='MAT-036'))
              then to_jsonb((select id::text from materiales where cod='MAT-035')) else v end)
  from jsonb_each(mat_overrides) as e(k, v))
where mat_overrides is not null and mat_overrides::text <> '{}';

-- 2d. Verificar ANTES del commit: no debe quedar ninguna referencia con "asentamiento" ni a MAT-036
select 'coef' t, count(*) from coeficientes where mats::text ilike '%asentamiento%'
union all select 'ovr', count(*) from mediciones where mat_overrides::text ilike '%asentamiento%'
   or mat_overrides::text like '%' || (select id::text from materiales where cod='MAT-036') || '%';
-- Si las dos dan 0: commit;  si no: rollback;
commit;

-- 2e. Borrar MAT-036 (ya sin referencias). Requiere OK aparte.
-- select * from materiales where cod = 'MAT-036';
-- delete from materiales where cod = 'MAT-036' and nombre = 'Hormigón elaborado H21 asentamiento 12,5';

-- =====================================================================
-- PASO 3 · Versión con binder de cada hormigón (piedra más fina) + H25 con binder por defecto en losas y muros
-- Sin sufijo "— a definir" en el nombre a propósito: estos nombres los referencian las tareas (matRef)
-- y renombrar después rompe el vínculo. El precio 0 se ve igual en Materiales.
-- ⚠ Cargar los precios ANTES del update de tareas, o las 24 mediciones de losas/muros quedan con el Hº a $0.
-- =====================================================================
select cod from materiales where cod in ('MAT-173','MAT-174','MAT-175');   -- esperado: 0 filas
insert into materiales (cod, nombre, unidad, cat, precio, prov) values
  ('MAT-173', 'Hormigón elaborado H25 con binder', 'm³', 'Estructural', 0, null),
  ('MAT-174', 'Hormigón elaborado H17 con binder', 'm³', 'Estructural', 0, null),
  ('MAT-175', 'Hormigón elaborado H21 con binder', 'm³', 'Estructural', 0, null);
-- update materiales set precio = <PRECIO>, prov = '<PROVEEDOR>', fecha = current_date::text where cod = 'MAT-173';  -- y 161, 174, 175
select cod, nombre, mats from coeficientes
 where rubro = 'Hormigón Armado' and cod in ('4.19','4.28','4.29','4.31');
begin;
update coeficientes c set mats = (
  select jsonb_agg(case when m->>'matRef' = 'Hormigón elaborado H17'
                        then jsonb_set(m, '{matRef}', '"Hormigón elaborado H25 con binder"') else m end order by ord)
  from jsonb_array_elements(c.mats) with ordinality as t(m, ord))
where c.rubro = 'Hormigón Armado' and c.cod in ('4.19','4.28','4.29','4.31');
-- Losas nervuradas ya cargadas (4 mediciones, todas con hor=MAT-035 = el default viejo H21):
-- solo correr si se quiere pasarlas a H25 con binder.
-- update mediciones set descripcion = replace(descripcion, 'hor=MAT-035', 'hor=MAT-173') where descripcion like '%nv:%hor=MAT-035%';
commit;

-- =====================================================================
-- PASO 4 · Casetones 40x40 (precio a definir, igual que los de 60 y 80)
-- =====================================================================
select cod from materiales where cod in ('MAT-171','MAT-172');   -- esperado: 0 filas
insert into materiales (cod, nombre, unidad, cat, precio, prov)
values ('MAT-171', 'Casetón recuperable 40x40 — alquiler por m² — a definir', 'm²', 'Estructural', 0, null),
       ('MAT-172', 'Casetón EPS (telgopor) 40x40 — a definir',              'u',  'Estructural', 0, null);

notify pgrst, 'reload schema';
