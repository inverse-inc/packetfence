-- Local combinations can no longer be managed; drop any that would
-- still override the upstream Fingerbank result.
DELETE FROM "combination";
