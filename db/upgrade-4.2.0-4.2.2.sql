--
-- Add a column to store the portal used for email/sponsor activation
--

ALTER TABLE email_activation ADD `portal` varchar(255) default NULL AFTER `type`;

