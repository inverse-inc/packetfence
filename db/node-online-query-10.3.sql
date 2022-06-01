\! echo "Updating bandwidth_accounting indexes";
ALTER TABLE bandwidth_accounting
  DROP INDEX IF EXISTS bandwidth_accounting_tenant_id_mac,
  ADD INDEX bandwidth_accounting_tenant_id_mac_last_updated (tenant_id, mac, last_updated);
