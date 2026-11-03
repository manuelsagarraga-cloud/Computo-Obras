-- Tarea nueva: 3.21 Zapata excéntrica de medianera (media zapata) con Hº elaborado.
-- Rubro Fundaciones. Hormigón H17 por defecto (H21 se elige por medición con mat_overrides, igual que el resto).
-- Hierros: NO van en la tarea; los calcula el widget estructural (tipoEstructural('3.21') = 'zapata_excentrica').
-- Materiales de la tarea = los mismos que 3.8 / 3.18: Hº elaborado H17 1 m³ + alambre 0,7 kg por m³.
-- 3.20 queda libre a propósito: MAP_HO lo reserva para el cabezal H21.
--
-- PASO 1 — verificación previa (debe devolver 0 filas de 3.21 y las 2 filas de materiales con estos nombres exactos):
--   select cod, nombre, rubro from coeficientes where cod = '3.21';
--   select cod, nombre from materiales where nombre in ('Hormigón elaborado H17 asentamiento 8', 'Alambre negro nº17');
--
-- PASO 2 — alta (idempotente: si ya existe una 3.21 de la base común, no inserta nada).
insert into coeficientes (cod, nombre, rubro, unidad, mo_id, mo_rend, mats, empresa, cuadrilla)
select '3.21', 'Zapata excéntrica de medianera con Hº elaborado', 'Fundaciones', 'm3', null, 0,
       '[{"un":"m³","coef":1,"matRef":"Hormigón elaborado H17 asentamiento 8","divisor":1,"unComercial":"m³"},
         {"un":"kg","coef":0.7,"matRef":"Alambre negro nº17","divisor":1,"unComercial":"kg"}]'::jsonb,
       null, null
where not exists (select 1 from coeficientes where cod = '3.21' and empresa is null);

-- PASO 3 — verificación posterior (debe devolver exactamente 1 fila, con los 2 materiales):
--   select id, cod, nombre, rubro, unidad, mats from coeficientes where cod = '3.21';
