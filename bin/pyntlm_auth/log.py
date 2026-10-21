import logging
import os


def detect_default_logging_level():
    available_logging_levels = {'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'}
    logging_level_str = os.getenv('LOG_LEVEL')

    if not logging_level_str:
        logging_level_str = 'DEBUG'

    if logging_level_str not in available_logging_levels:
        logging_level_str = 'DEBUG'

    logging_level = logging.DEBUG

    logging_level_str = logging_level_str.upper()
    if logging_level_str == 'INFO':
        logging_level = logging.INFO
    elif logging_level_str == 'WARNING':
        logging_level = logging.WARNING
    elif logging_level_str == 'ERROR':
        logging_level = logging.ERROR
    elif logging_level_str == 'CRITICAL':
        logging_level = logging.CRITICAL

    return logging_level


def init_logging():
    logger_ntlm = logging.getLogger("ntlm-auth")
    logging_level = detect_default_logging_level()
    logger_ntlm.setLevel(logging_level)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging_level)

    formatter = logging.Formatter('%(asctime)s [%(process)d] [%(levelname)s] %(message)s', datefmt="[%Y-%m-%d %H:%M:%S %z]")
    console_handler.setFormatter(formatter)

    logger_ntlm.addHandler(console_handler)

    return logger_ntlm


def debug(msg):
    default_logger.debug(msg)


def info(msg):
    default_logger.info(msg)


def warning(msg):
    default_logger.warning(msg)


def error(msg):
    default_logger.error(msg)


def critical(msg):
    default_logger.critical(msg)


default_logger = init_logging()
