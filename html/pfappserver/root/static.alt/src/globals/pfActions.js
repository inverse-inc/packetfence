import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import {
  isDateFormat,
  requireAllSiblingFields,
  requireAnySiblingFields,
  restrictAllSiblingFields,
  limitSiblingFields,
  isValidUnregDateByAclUser
} from '@/globals/pfValidators'
const {
  maxValue,
  minValue,
  numeric,
  required,
  url
} = require('vuelidate/lib/validators')
import bytes from '@/utils/bytes'
import i18n from '@/utils/locale'

export const pfActions = {
  bandwidth_balance_from_source: {
    value: 'bandwidth_balance_from_source',
    text: i18n.t('Set the bandwidth balance from the auth source'),
    types: [fieldType.NONE]
  },
  default_actions: {
    value: 'default_actions',
    text: i18n.t('Execute module default actions'),
    types: [fieldType.NONE]
  },
  destination_url: {
    value: 'destination_url',
    text: i18n.t('Destination URL'),
    types: [fieldType.URL],
    validators: {
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be a URL.')]: url
      }
    }
  },
  on_failure: {
    value: 'on_failure',
    text: i18n.t('on_failure'),
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  on_success: {
    value: 'on_success',
    text: i18n.t('on_success'),
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  set_access_duration: {
    value: 'set_access_duration',
    text: i18n.t('Access duration'),
    types: [fieldType.DURATION],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_unreg_date" */
        [i18n.t('Action conflicts with "Unregistration date".')]: restrictAllSiblingFields('type', 'set_unreg_date')
      }
    }
  },
  set_access_duration_by_acl_user: {
    value: 'set_access_duration',
    text: i18n.t('Access duration'),
    types: [fieldType.DURATION_BY_ACL_USER],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_unreg_date" */
        [i18n.t('Action conflicts with "Unregistration date".')]: restrictAllSiblingFields('type', 'set_unreg_date')
      }
    }
  },
  set_access_durations: {
    value: 'set_access_durations',
    text: i18n.t('Sponsor access durations'),
    types: [fieldType.DURATIONS],
    validators: {
      type: {
        /* Require "mark_as_sponsor" */
        [i18n.t('Action requires "Mark as sponsor".')]: requireAllSiblingFields('type', 'mark_as_sponsor')
      }
    }
  },
  set_access_level: {
    value: 'set_access_level',
    text: i18n.t('Access level'),
    types: [fieldType.ADMINROLE]
  },
  set_access_level_by_acl_user: {
    value: 'set_access_level',
    text: i18n.t('Access level'),
    types: [fieldType.ADMINROLE_BY_ACL_USER]
  },
  set_bandwidth_balance: {
    value: 'set_bandwidth_balance',
    text: i18n.t('Bandwidth balance'),
    types: [fieldType.PREFIXMULTIPLIER],
    validators: {
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be greater than {min}bytes.', { min: bytes.toHuman(schema.node.bandwidth_balance.min) })]: minValue(schema.node.bandwidth_balance.min),
        [i18n.t('Value must be less than {max}bytes.', { max: bytes.toHuman(schema.node.bandwidth_balance.max) })]: maxValue(schema.node.bandwidth_balance.max)
      }
    }
  },
  mark_as_sponsor: {
    value: 'mark_as_sponsor',
    text: i18n.t('Mark as sponsor'),
    types: [fieldType.HIDDEN],
    initialValue: '1'
  },
  no_action: {
    value: 'no_action',
    text: i18n.t(`Don't do any action`),
    types: [fieldType.NONE],
    validators: {
      type: {
        /* Don't allow any other action */
        [i18n.t('No other option must be defined.')]: limitSiblingFields([], 0)
      }
    }
  },
  role_from_source: {
    value: 'role_from_source',
    text: i18n.t('Set role from the authentication source'),
    types: [fieldType.NONE]
  },
  set_role: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date')
      }
    }
  },
  set_role_by_name: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_NAME],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date')
      }
    }
  },
  set_role_by_acl_user: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_ACL_USER],
    validators: {
      type: {
        /* When "Role" is selected, either "Time Balance" or "set_unreg_date" is required */
        [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: requireAnySiblingFields('type', 'set_access_duration', 'set_unreg_date')
      }
    }
  },
  set_tenant_id: {
    value: 'set_tenant_id',
    text: i18n.t('Tenant ID'),
    types: [fieldType.TENANT],
    validators: {
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Value must be numeric.')]: numeric
      }
    }
  },
  set_time_balance: {
    value: 'set_time_balance',
    text: i18n.t('Time balance'),
    types: [fieldType.TIME_BALANCE]
  },
  set_unreg_date: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    placeholder: 'YYYY-MM-DD',
    /* TODO - Workaround for Issue #4672
     * types: [fieldType.DATETIME],
     * moments: ['1 days', '1 weeks', '1 months', '1 years'],
     */
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_access_duration" */
        [i18n.t('Action conflicts with "Access duration".')]: restrictAllSiblingFields('type', 'set_access_duration')
      },
      value: {
        [i18n.t('Invalid date.')]: isDateFormat('YYYY-MM-DD')
      }
    }
  },
  set_unreg_date_by_acl_user: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    placeholder: 'YYYY-MM-DD',
    /* TODO - Workaround for Issue #4672
     * types: [fieldType.DATETIME],
     * moments: ['1 days', '1 weeks', '1 months', '1 years'],
     */
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Require "set_role" */
        [i18n.t('Action requires "Set Role".')]: requireAllSiblingFields('type', 'set_role'),
        /* Restrict "set_access_duration" */
        [i18n.t('Action conflicts with "Access duration".')]: restrictAllSiblingFields('type', 'set_access_duration')
      },
      value: {
        [i18n.t('Invalid date.')]: isDateFormat('YYYY-MM-DD'),
        /* Limit maximum date w/ current user ACL */
        [i18n.t('Date exceeds maximum allowed by current user.')]: isValidUnregDateByAclUser('YYYY-MM-DD')
      }
    }
  },
  time_balance_from_source: {
    value: 'time_balance_from_source',
    text: i18n.t('Set the time balance from the auth source'),
    types: [fieldType.NONE]
  },
  unregdate_from_source: {
    value: 'unregdate_from_source',
    text: i18n.t('Set unregistration date from the authentication source'),
    types: [fieldType.NONE]
  },
  unregdate_from_sponsor_source: {
    value: 'unregdate_from_sponsor_source',
    text: i18n.t('Set unregistration date from the sponsor source'),
    types: [fieldType.NONE]
  }
}
