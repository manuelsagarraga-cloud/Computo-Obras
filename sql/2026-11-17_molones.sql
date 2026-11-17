-- 2026-11-17 · Molones EPS para losa nervurada en un sentido (precio a definir)
select cod from materiales where cod in ('MAT-176','MAT-177');   -- esperado: 0 filas
insert into materiales (cod, nombre, unidad, cat, precio, prov) values
  ('MAT-176', 'Molón EPS 40x30x25 — a definir', 'u', 'Estructural', 0, null),
  ('MAT-177', 'Molón EPS 40x40x30 — a definir', 'u', 'Estructural', 0, null);

-- Molón de otra medida (el nombre en presupuesto y compras lleva la medida cargada)
select cod from materiales where cod = 'MAT-178';   -- esperado: 0 filas
insert into materiales (cod, nombre, unidad, cat, precio, prov) values ('MAT-178', 'Molón otra medida — a definir', 'u', 'Estructural', 0, null);
