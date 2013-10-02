--
-- category of temporary password is not mandatory
--

ALTER TABLE `temporary_password` MODIFY category int DEFAULT NULL;