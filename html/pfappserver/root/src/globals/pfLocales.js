export const pfLocales = [
  {
    label: 'English', // i18n defer
    locale: 'en_US', is_ui: true
  },
  {
    label: 'German', // i18n defer
    locale: 'de_DE'
  },
  {
    label: 'Spanish', // i18n defer
    locale: 'es_ES'
  },
  {
    label: 'French', // i18n defer
    locale: 'fr_FR', is_ui: true
  },
  {
    label: 'Hebrew', // i18n defer
    locale: 'he_IL'
  },
  {
    label: 'Italian', // i18n defer
    locale: 'it_IT'
  },
  {
    label: 'Norwegian', // i18n defer
    locale: 'nb_NO'
  },
  {
    label: 'Dutch', // i18n defer
    locale: 'nl_NL'
  },
  {
    label: 'Polish', // i18n defer
    locale: 'pl_PL'
  },
  {
    label: 'Portuguese', // i18n defer
    locale: 'pt_BR'
  },
  {
    label: 'Turkish', // i18n defer
    locale: 'tr_TR', is_ui: true
  },
]

export const localeStrings = {
  SERVICES_DISABLED_SUCCESS: 'Disabled services {services}.', // i18n defer
  SERVICES_DISABLED_ERROR: 'Failed to disable services {services}. See the server error logs for more information.', // i18n defer
  SERVICES_PROTECTED_DISABLED_ERROR: 'Failed to disable services {services}. This service is required for this page to function and CLI access may be required to remediate any issues caused by the failure. See the server error logs for more information.', // i18n defer

  SERVICES_ENABLED_SUCCESS: 'Enabled services {services}.', // i18n defer
  SERVICES_ENABLED_ERROR: 'Failed to enable services {services}. See the server error logs for more information.', // i18n defer
  SERVICES_PROTECTED_ENABLED_ERROR: 'Failed to enable services {services}. This service is required for this page to function and CLI access may be required to remediate any issues caused by the failure. See the server error logs for more information.', // i18n defer

  SERVICES_RESTARTED_SUCCESS: 'Restarted services {services}.', // i18n defer
  SERVICES_RESTARTED_ERROR: 'Failed to restart services {services}. See the server error logs for more information.', // i18n defer
  SERVICES_PROTECTED_RESTARTED_ERROR: 'Failed to restart services {services}. This service is required for this page to function and CLI access may be required to remediate any issues caused by the failure. See the server error logs for more information.', // i18n defer

  SERVICES_STARTED_SUCCESS: 'Started services {services}.', // i18n defer
  SERVICES_STARTED_ERROR: 'Failed to start services {services}. See the server error logs for more information.', // i18n defer

  SERVICES_STOPPED_SUCCESS: 'Stopped services {services}.', // i18n defer
  SERVICES_STOPPED_ERROR: 'Failed to stop services {services}. See the server error logs for more information.', // i18n defer

  SYSTEMD_UPDATED_SUCCESS: 'Updated systemd for {service}.', // i18n defer
  SYSTEMD_UPDATED_ERROR: 'Failed to update systemd for {service}. See the server error logs for more information.', // i18n defer

  SERVICES_K8S_RESTARTED_SUCCESS: 'Restarted services {services}.', // i18n defer
  SERVICES_K8S_RESTARTED_ERROR: 'Failed to restart services {services}. See the server error logs for more information.', // i18n defer
}
