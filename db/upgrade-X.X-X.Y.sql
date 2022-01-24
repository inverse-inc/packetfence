--
-- PacketFence SQL schema upgrade from 10.3 to 11.0
--


\! echo "altering pki_certs"
ALTER TABLE pki_certs
    ADD COLUMN IF NOT EXISTS `scep` BOOLEAN DEFAULT FALSE AFTER ip_addresses;

\! echo "set pki_certs.scep to true if private key is empty"
UPDATE pki_certs
    SET `scep`=1 WHERE `key` = "";


\! echo "Alter table pki_certs"
ALTER TABLE `pki_certs`
  MODIFY valid_until DATETIME,
  MODIFY date DATETIME DEFAULT CURRENT_TIMESTAMP,
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table pki_cas"
ALTER TABLE `pki_cas`
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table pki_profiles"
ALTER TABLE `pki_profiles`
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table pki_revoked_certs"
ALTER TABLE `pki_revoked_certs`
  MODIFY valid_until DATETIME,
  MODIFY date DATETIME DEFAULT CURRENT_TIMESTAMP,
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;


\! echo "Upgrade completed successfully.";
