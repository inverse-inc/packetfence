--
-- Add a column to store the portal used for email/sponsor activation
--

ALTER TABLE email_activation ADD `portal` varchar(255) default NULL AFTER `type`;

--
-- Add column to store portal and source in person table
--
ALTER TABLE person ADD `portal` varchar(255) default NULL;
ALTER TABLE person ADD `source` varchar(255) default NULL;
