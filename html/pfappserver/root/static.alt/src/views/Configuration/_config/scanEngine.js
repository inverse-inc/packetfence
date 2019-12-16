import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasScans,
  scanExists
} from '@/globals/pfValidators'
import { required } from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Name'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'ip',
    label: i18n.t('IP Address'),
    sortable: true,
    visible: true
  },
  {
    key: 'port',
    label: i18n.t('Port'),
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'ip',
    text: i18n.t('IP Address'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'port',
    text: i18n.t('Port'),
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
      return { name: 'scanEngine', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name, ip, port or type'),
    searchableOptions: {
      searchApiEndpoint: 'config/scans',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'ip', op: 'contains', value: null },
            { field: 'port', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'scanEngines' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'ip', op: 'contains', value: quickCondition },
              { field: 'port', op: 'contains', value: quickCondition },
              { field: 'type', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    scanType = null, // from router
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Name'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7'].includes(scanType),
          label: i18n.t('Hostname or IP Address'),
          cols: [
            {
              namespace: 'ip',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ip')
            }
          ]
        },
        {
          label: i18n.t('Username'),
          cols: [
            {
              namespace: 'username',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'username')
            }
          ]
        },
        {
          if: ['wmi'].includes(scanType),
          label: i18n.t('Domain'),
          cols: [
            {
              namespace: 'domain',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'domain')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          cols: [
            {
              namespace: 'password',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'password')
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7'].includes(scanType),
          label: i18n.t('Port of the service'),
          text: i18n.t('If you use an alternative port, please specify.'),
          cols: [
            {
              namespace: 'port',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'port')
            }
          ]
        },
        {
          if: ['nessus', 'nessus6'].includes(scanType),
          label: i18n.t('Nessus client policy'),
          text: i18n.t('Name of the policy to use on the nessus server.'),
          cols: [
            {
              namespace: 'nessus_clientpolicy',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'nessus_clientpolicy')
            }
          ]
        },
        {
          if: ['nessus6'].includes(scanType),
          label: i18n.t('Nessus scanner name'),
          text: i18n.t('Name of the scanner to use on the nessus server.'),
          cols: [
            {
              namespace: 'scannername',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'scannername')
            }
          ]
        },
        {
          if: ['openvas'].includes(scanType),
          label: i18n.t('Alert ID'),
          text: i18n.t('ID of the alert configuration on the OpenVAS server.'),
          cols: [
            {
              namespace: 'openvas_alertid',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'openvas_alertid')
            }
          ]
        },
        {
          if: ['openvas'].includes(scanType),
          label: i18n.t('Scan config ID'),
          text: i18n.t('ID of the scanning configuration on the OpenVAS server.'),
          cols: [
            {
              namespace: 'openvas_configid',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'openvas_configid')
            }
          ]
        },
        {
          if: ['openvas'].includes(scanType),
          label: i18n.t('Report format ID'),
          text: i18n.t('ID of the "CSV Results" report format on the OpenVAS server.'),
          cols: [
            {
              namespace: 'openvas_reportformatid',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'openvas_reportformatid')
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Verify Hostname'),
          text: i18n.t('Verify hostname of server when connecting to the API.'),
          cols: [
            {
              namespace: 'verify_hostname',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Scan Engine'),
          text: i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.'),
          cols: [
            {
              namespace: 'engine_id',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'engine_id')
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Scan Template'),
          text: i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.'),
          cols: [
            {
              namespace: 'template_id',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'template_id')
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Site'),
          text: i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.'),
          cols: [
            {
              namespace: 'site_id',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'site_id')
            }
          ]
        },
        {
          label: i18n.t('Roles'),
          text: i18n.t('Nodes with the selected roles will be affected.'),
          cols: [
            {
              namespace: 'categories',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'categories')
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7'].includes(scanType),
          label: i18n.t('OS'),
          text: i18n.t('Nodes with the selected OS will be affected.'),
          cols: [
            {
              namespace: 'oses',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'oses')
            }
          ]
        },
        {
          label: i18n.t('Duration'),
          text: i18n.t('Approximate duration of a scan. User being scanned on registration are presented a progress bar for this duration, afterwards the browser refreshes until scan is complete.'),
          cols: [
            {
              namespace: 'duration.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'duration.interval')
            },
            {
              namespace: 'duration.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'duration.unit')
            }
          ]
        },
        {
          label: i18n.t('Scan before registration'),
          text: i18n.t('If this option is enabled, the PF system will scan host before the registration.'),
          cols: [
            {
              namespace: 'pre_registration',
              component: pfFormToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
              }
            }
          ]
        },
        {
          label: i18n.t('Scan on registration'),
          text: i18n.t('If this option is enabled, the PF system will scan each host after registration is complete.'),
          cols: [
            {
              namespace: 'registration',
              component: pfFormToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
              }
            }
          ]
        },
        {
          label: i18n.t('Scan after registration'),
          text: i18n.t('If this option is enabled, the PF system will scan host after on the production vlan.'),
          cols: [
            {
              namespace: 'post_registration',
              component: pfFormToggle,
              attrs: {
                values: { checked: 1, unchecked: 0 }
              }
            }
          ]
        },
        {
          if: ['wmi'].includes(scanType),
          label: i18n.t('WMI Rules'),
          text: i18n.t('If this option is enabled, the PF system will scan host after on the production vlan.'),
          cols: [
            {
              namespace: 'wmi_rules',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Rule'),
                emptyText: i18n.t('With no WMI rules specified, the scan engine will not be triggered.'),
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        ...pfConfigurationAttributesFromMeta(meta, 'wmi_rules'),
                        ...{
                          collapseObject: true,
                          placeholder: i18n.t('Click to select a rule'),
                          trackBy: 'value',
                          label: 'text',
                          multiple: false
                        }
                      }
                    }

                  }
                },
                invalidFeedback: [
                  { [i18n.t('Rule(s) contain one or more errors.')]: true }
                ]
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
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...pfConfigurationValidatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasScans, scanExists))
      }
    },
    ip: pfConfigurationValidatorsFromMeta(meta, 'ip', 'IP'),
    username: pfConfigurationValidatorsFromMeta(meta, 'username', i18n.t('Username')),
    domain: pfConfigurationValidatorsFromMeta(meta, 'domain', i18n.t('Domain')),
    password: pfConfigurationValidatorsFromMeta(meta, 'password', i18n.t('Password')),
    port: pfConfigurationValidatorsFromMeta(meta, 'port', i18n.t('Port')),
    nessus_clientpolicy: pfConfigurationValidatorsFromMeta(meta, 'nessus_clientpolicy', i18n.t('Policy')),
    scannername: pfConfigurationValidatorsFromMeta(meta, 'scannername', i18n.t('Name')),
    openvas_alertid: pfConfigurationValidatorsFromMeta(meta, 'openvas_alertid', 'ID'),
    openvas_configid: pfConfigurationValidatorsFromMeta(meta, 'openvas_configid', 'ID'),
    openvas_reportformatid: pfConfigurationValidatorsFromMeta(meta, 'openvas_reportformatid', 'ID'),
    engine_id: pfConfigurationValidatorsFromMeta(meta, 'engine_id', i18n.t('Engine')),
    template_id: pfConfigurationValidatorsFromMeta(meta, 'template_id', i18n.t('Template')),
    site_id: pfConfigurationValidatorsFromMeta(meta, 'site_id', i18n.t('Site')),
    categories: pfConfigurationValidatorsFromMeta(meta, 'categories', i18n.t('Categories')),
    oses: pfConfigurationValidatorsFromMeta(meta, 'oses', 'OS'),
    'duration.interval': pfConfigurationValidatorsFromMeta(meta, 'duration.interval', i18n.t('Interval')),
    'duration.unit': pfConfigurationValidatorsFromMeta(meta, 'duration.unit', i18n.t('Unit')),
    wmi_rules: {
      $each: {
        [i18n.t('Duplicate Rule.')]: conditional((value) => {
          return !(form.wmi_rules.filter(v => v === value).length > 1)
        })
      }
    }
  }
}