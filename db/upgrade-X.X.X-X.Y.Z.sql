---
--- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
---

---
--- Alter for machine_account
---

ALTER TABLE node
    ADD `machine_account` varchar(255) DEFAULT NULL;


---
--- Alter for bypass_role
---
ALTER TABLE node
    ADD `bypass_role` varchar(255) DEFAULT NULL;
