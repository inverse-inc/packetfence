alter table iplog drop foreign key 0_63;
alter table iplog add constraint 0_63 foreign key(mac) references node(mac) on delete cascade on update cascade;
