--
-- Trigger to delete the node_useragent associated with a mac when deleting this mac from the node table
--

DROP TRIGGER IF EXISTS node_useragent_delete_trigger;
DELIMITER /
CREATE TRIGGER node_useragent_delete_trigger AFTER DELETE ON node
FOR EACH ROW
BEGIN
  DELETE FROM node_useragent WHERE mac = OLD.mac;
END /
DELIMITER ;
