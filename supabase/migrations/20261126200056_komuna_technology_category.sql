insert into donaplus.categories (id, name, icon)
values ('cat-tecnologia', 'Tecnología', 'devices')
on conflict (id) do nothing;
