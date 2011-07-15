<?php

  require_once 'Log.php';
  // TODO port hard-coded path to get_pf_path
  $logger_file = &Log::factory('file', '/usr/local/pf/logs/admin_debug_log');
  $logger = &Log::singleton('composite', '', '', '', PEAR_LOG_INFO);
  $logger->addChild($logger_file);

  $logger_file->setMask(Log::MAX(PEAR_LOG_INFO));

