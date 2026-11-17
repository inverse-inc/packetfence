--
-- Create the chatbot (NACBot) conversation tables if they are missing.
-- Idempotent. pf-schema-*.sql and the db upgrade create them too; this covers
-- databases created by an earlier build of the same version, which no upgrade
-- script touches. Run by sbin/chatbot-docker-wrapper before each start.
--

--
-- CreateChatbotTables: create the chatbot_* tables if missing. The pid column
-- mirrors person.pid's exact type/charset/collation, since a mismatch makes
-- the foreign key fail with errno 150 (e.g. utf8mb4_0900_ai_ci on MySQL 8).
--
DROP PROCEDURE IF EXISTS CreateChatbotTables;
DELIMITER //
CREATE PROCEDURE CreateChatbotTables()
BEGIN
    DECLARE pid_ddl TEXT;

    SELECT CONCAT(COLUMN_TYPE,
                  IF(CHARACTER_SET_NAME IS NULL, '', CONCAT(' CHARACTER SET ', CHARACTER_SET_NAME)),
                  IF(COLLATION_NAME IS NULL, '', CONCAT(' COLLATE ', COLLATION_NAME)))
      INTO pid_ddl
      FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME   = 'person'
       AND COLUMN_NAME  = 'pid';

    SET @ddl = CONCAT(
        'CREATE TABLE IF NOT EXISTS `chatbot_thread` (',
        '`pid` ', pid_ddl, ' NOT NULL,',
        '`thread_id` bigint NOT NULL AUTO_INCREMENT,',
        '`title` varchar(255) NOT NULL,',
        '`created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,',
        '`updated` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,',
        'PRIMARY KEY (`pid`,`thread_id`),',
        'UNIQUE KEY `uk_thread_id` (`thread_id`),',
        'KEY `idx_thread_recent` (`pid`,`updated`),',
        'FULLTEXT KEY `ft_thread_title` (`title`),',
        'CONSTRAINT `fk_chatbot_thread_person` FOREIGN KEY (`pid`) ',
        'REFERENCES `person` (`pid`) ON DELETE CASCADE',
        ') ENGINE=InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @ddl = CONCAT(
        'CREATE TABLE IF NOT EXISTS `chatbot_message` (',
        '`pid` ', pid_ddl, ' NOT NULL,',
        '`thread_id` bigint NOT NULL,',
        '`id` bigint NOT NULL AUTO_INCREMENT,',
        '`role` varchar(16) NOT NULL,',
        '`content` mediumtext NOT NULL,',
        '`activity` mediumtext DEFAULT NULL,',
        '`created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,',
        '`feedback` tinyint NOT NULL DEFAULT 0,',
        'PRIMARY KEY (`id`),',
        'KEY `idx_msg_thread` (`pid`,`thread_id`,`id`),',
        'KEY `idx_msg_feedback` (`pid`,`feedback`,`id`),',
        'FULLTEXT KEY `ft_msg_content` (`content`),',
        'CONSTRAINT `fk_chatbot_msg_thread` FOREIGN KEY (`pid`,`thread_id`) ',
        'REFERENCES `chatbot_thread` (`pid`,`thread_id`) ON DELETE CASCADE',
        ') ENGINE=InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @ddl = CONCAT(
        'CREATE TABLE IF NOT EXISTS `chatbot_usage` (',
        '`pid` ', pid_ddl, ' NOT NULL,',
        '`id` bigint NOT NULL AUTO_INCREMENT,',
        '`ts` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,',
        '`provider` varchar(32) NOT NULL,',
        '`model` varchar(128) NOT NULL,',
        '`input_tokens` int NOT NULL DEFAULT 0,',
        '`output_tokens` int NOT NULL DEFAULT 0,',
        '`thread_id` bigint DEFAULT NULL,',
        'PRIMARY KEY (`pid`,`id`),',
        'UNIQUE KEY `uk_usage_id` (`id`),',
        'KEY `idx_usage_ts` (`pid`,`ts`),',
        'CONSTRAINT `fk_chatbot_usage_person` FOREIGN KEY (`pid`) ',
        'REFERENCES `person` (`pid`) ON DELETE CASCADE',
        ') ENGINE=InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @ddl = CONCAT(
        'CREATE TABLE IF NOT EXISTS `chatbot_file` (',
        '`pid` ', pid_ddl, ' NOT NULL,',
        '`thread_id` bigint NOT NULL,',
        '`id` bigint NOT NULL AUTO_INCREMENT,',
        '`message_id` bigint DEFAULT NULL,',
        '`kind` varchar(8) NOT NULL,',
        '`name` varchar(255) NOT NULL,',
        '`mime` varchar(128) NOT NULL DEFAULT ''application/octet-stream'',',
        '`size_bytes` bigint NOT NULL,',
        '`sha256` char(64) NOT NULL,',
        '`content` mediumblob DEFAULT NULL,',
        '`disk_path` varchar(255) DEFAULT NULL,',
        '`created` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,',
        'PRIMARY KEY (`id`),',
        'KEY `idx_file_thread` (`pid`,`thread_id`,`created`),',
        'KEY `idx_file_msg` (`pid`,`message_id`),',
        'KEY `idx_file_sha` (`sha256`),',
        'CONSTRAINT `fk_chatbot_file_thread` FOREIGN KEY (`pid`,`thread_id`) ',
        'REFERENCES `chatbot_thread` (`pid`,`thread_id`) ON DELETE CASCADE',
        ') ENGINE=InnoDB DEFAULT CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END
//
DELIMITER ;

CALL CreateChatbotTables();
DROP PROCEDURE IF EXISTS CreateChatbotTables;
