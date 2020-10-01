import i18n from '@/utils/locale'
import pfButton from '@/components/pfButton'
import pfFieldApiMethodParameters from '@/components/pfFieldApiMethodParameters'
import pfFieldRuleSyslogParserRegex from '@/components/pfFieldRuleSyslogParserRegex'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasSyslogParsers,
  syslogParserExists
} from '@/globals/pfValidators'
import {
  maxLength,
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'status',
    label: 'Status', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'id',
    label: 'Detector', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Detector'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'syslogParser', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by detector or type'),
    searchableOptions: {
      searchApiEndpoint: 'config/syslog_parsers',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'syslogParsers' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition },
            { field: 'type', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const regexRuleActions = {
  add_person: {
    value: 'add_person',
    text: i18n.t('Create new user account'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'pid, $pid'
  },
  close_security_event: {
    value: 'close_security_event',
    text: i18n.t('Close security event'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, vid, VID',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  deregister_node_ip: {
    value: 'deregister_node_ip',
    text: i18n.t('Deregister node by IP'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'ip, $ip',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  dynamic_register_node: {
    value: 'dynamic_register_node',
    text: i18n.t('Register node by MAC'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, username, $username',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  modify_node: {
    value: 'modify_node',
    text: i18n.t('Modify node by MAC'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  modify_person: {
    value: 'modify_person',
    text: i18n.t('Modify existing user'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'pid, $pid',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  reevaluate_access: {
    value: 'reevaluate_access',
    text: i18n.t('Reevaluate access by MAC'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, reason, $reason',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  register_node: {
    value: 'register_node',
    text: i18n.t('Register a new node by PID'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, pid, $pid',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  register_node_ip: {
    value: 'register_node_ip',
    text: i18n.t('Register node by IP'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'ip, $ip, pid, $pid',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  release_all_security_events: {
    value: 'release_all_security_events',
    text: i18n.t('Release all security events for node by MAC'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: '$mac',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  role_detail: {
    value: 'role_detail',
    text: i18n.t('role_detail'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'role, $role',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  trigger_scan: {
    value: 'trigger_scan',
    text: i18n.t('Launch a scan for the device'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: '$ip, mac, $mac, net_type, TYPE',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  trigger_security_event: {
    value: 'trigger_security_event',
    text: i18n.t('Trigger a security event'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, tid, TYPEID, type, TYPE',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  unreg_node_for_pid: {
    value: 'unreg_node_for_pid',
    text: i18n.t('Deregister node by PID'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'pid, $pid',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  update_ip4log: {
    value: 'update_ip4log',
    text: i18n.t('Update ip4log by IP and MAC'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, ip, $ip',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  update_ip6log: {
    value: 'update_ip6log',
    text: i18n.t('Update ip6log by IP and MAC'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'mac, $mac, ip, $ip',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  },
  update_role_configuration: {
    value: 'update_role_configuration',
    text: i18n.t('Update role configuration'),
    types: [fieldType.SUBSTRING],
    defaultApiParameters: 'role, $role',
    validators: {
      api_parameters: {
        [i18n.t('API Parameters required.')]: required
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    invalidForm = false,
    syslogParserType = null,
    dryRunTest = () => {},
    dryRunResponseHtml = null // html from dry run
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Detector'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id', 'Detector'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Enabled'),
          cols: [
            {
              namespace: 'status',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Alert pipe'),
          cols: [
            {
              namespace: 'path',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'path')
            }
          ]
        },
        {
          label: i18n.t('Tenant'),
          cols: [
            {
              namespace: 'tenant_id',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'tenant_id')
            }
          ]
        },
        {
          if: syslogParserType !== 'regex', // all but 'regex'
          label: i18n.t('Rate limit'),
          cols: [
            {
              namespace: 'rate_limit.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'rate_limit.interval')
            },
            {
              namespace: 'rate_limit.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'rate_limit.unit')
            }
          ]
        },
        {
          if: ['regex'].includes(syslogParserType), // 'regex' only
          label: 'Rules',
          cols: [
            {
              namespace: 'rules',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Rule - New ( )'),
                sortable: true,
                field: {
                  component: pfFieldRuleSyslogParserRegex,
                  attrs: {
                    actions: {
                      component: pfFieldApiMethodParameters,
                      attrs: {
                        typeLabel: i18n.t('Select action type'),
                        valueLabel: i18n.t('Select action value'),
                        fields: [
                          regexRuleActions.deregister_node_ip,
                          regexRuleActions.role_detail,
                          regexRuleActions.modify_person,
                          regexRuleActions.register_node_ip,
                          regexRuleActions.add_person,
                          regexRuleActions.update_ip6log,
                          regexRuleActions.unreg_node_for_pid,
                          regexRuleActions.trigger_scan,
                          regexRuleActions.reevaluate_access,
                          regexRuleActions.update_ip4log,
                          regexRuleActions.update_role_configuration,
                          regexRuleActions.trigger_security_event,
                          regexRuleActions.release_all_security_events,
                          regexRuleActions.modify_node,
                          regexRuleActions.close_security_event,
                          regexRuleActions.register_node,
                          regexRuleActions.dynamic_register_node
                        ]
                      },
                      invalidFeedback: i18n.t('Action(s) contain one or more errors.')
                    }
                  }
                },
                invalidFeedback: i18n.t('Rule(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          if: ['regex'].includes(syslogParserType), // 'regex' only
          label: i18n.t('Test Syslog Parser'),
          labelSize: 'lg'
        },
        {
          if: ['regex'].includes(syslogParserType), // 'regex' only
          label: i18n.t('Sample Log Lines'),
          cols: [
            {
              namespace: 'lines',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'lines'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          if: ['regex'].includes(syslogParserType), // 'regex' only
          label: null,
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: dryRunResponseHtml
              }
            }
          ]
        },
        {
          if: ['regex'].includes(syslogParserType), // 'regex' only
          label: null,
          cols: [
            {
              component: pfButton,
              attrs: {
                variant: 'outline-warning',
                label: i18n.t('Test Dry Run'),
                class: 'col-sm-2',
                disabled: !(form.lines && !invalidForm)
              },
              listeners: {
                click: (event) => {
                  dryRunTest(event)
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    rules = []
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Syslog Parser exists.')]: not(and(required, conditional(isNew || isClone), hasSyslogParsers, syslogParserExists))
      }
    },
    path: validatorsFromMeta(meta, 'path', i18n.t('Path')),
    'rate_limit.interval': validatorsFromMeta(meta, 'rate_limit.interval', i18n.t('Interval')),
    'rate_limit.unit': validatorsFromMeta(meta, 'rate_limit.unit', i18n.t('Unit')),
    rules: {
      $each: {
        name: {
          [i18n.t('Name required.')]: required,
          [i18n.t('Maximum 255 characters.')]: maxLength(255),
          [i18n.t('Duplicate name.')]: conditional((name) => rules && !(rules.filter(r => r && r.name === name).length > 1))
        },
        regex: {
          [i18n.t('Regex required.')]: required,
          [i18n.t('Maximum 255 characters.')]: maxLength(255)
        },
        actions: {
          $each: {
            api_parameters: {
              [i18n.t('API Parameters required.')]: required
            }
          }
        }
      }
    },
    lines: validatorsFromMeta(meta, 'lines', i18n.t('Lines'))
  }
}
