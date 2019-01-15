import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/configuration/pfConfiguration'
import {
  or,
  and,
  not,
  conditional,
  scanExists,
  isFQDN,
  isPort
} from '@/globals/pfValidators'

const {
  required,
  alphaNum,
  integer,
  ipAddress,
  maxLength,
  minValue
} = require('vuelidate/lib/validators')

export const pfConfigurationScanEngineListColumns = [
  { ...pfConfigurationListColumns.id, ...{ label: i18n.t('Name') } }, // re-label
  pfConfigurationListColumns.ip,
  pfConfigurationListColumns.port,
  pfConfigurationListColumns.type,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationScanEngineListFields = [
  { ...pfConfigurationListFields.id, ...{ text: i18n.t('Name') } }, // re-text
  pfConfigurationListFields.ip,
  pfConfigurationListFields.port,
  pfConfigurationListFields.type
]

export const pfConfigurationScanEngineListConfig = (context = {}) => {
  const { $i18n } = context
  return {
    columns: pfConfigurationScanEngineListColumns,
    fields: pfConfigurationScanEngineListFields,
    rowClickRoute (item, index) {
      return { name: 'scanEngine', params: { id: item.id } }
    },
    searchPlaceholder: $i18n.t('Search by name, ip, port or type'),
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

export const pfConfigurationScanEngineWmiRules = [ // TODO - make dynamic once API endpoint is available
  { text: 'Software_Installed', value: 'Software_Installed' },
  { text: 'logged_user', value: 'logged_user' },
  { text: 'Process_Running', value: 'Process_Running' },
  { text: 'SCCM', value: 'SCCM' },
  { text: 'FireWall', value: 'FireWall' },
  { text: 'Antivirus', value: 'Antivirus' },
  { text: 'AntiSpyware', value: 'AntiSpyware' }
]

export const pfConfigurationScanEngineViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    scanType = null, // from router,
    roles = [],
    scanEngine = {} // the form
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Name'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Name required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Alphanumeric characters only.')]: alphaNum,
                [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), scanExists))
              }
            }
          ]
        },
        {
          label: i18n.t('Hostname or IP Address'),
          fields: [
            {
              key: 'ip',
              component: pfFormInput,
              validators: {
                [i18n.t('Hostname or IP Address required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Invalid Hostname or IP Address.')]: or(isFQDN, ipAddress)
              }
            }
          ]
        },
        {
          label: i18n.t('Username'),
          fields: [
            {
              key: 'username',
              component: pfFormInput,
              validators: {
                [i18n.t('Username required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Password'),
          fields: [
            {
              key: 'password',
              component: pfFormPassword,
              validators: {
                [i18n.t('Password required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7'].includes(scanType),
          label: i18n.t('Port of the service'),
          text: i18n.t('If you use an alternative port, please specify.'),
          fields: [
            {
              key: 'port',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Invalid Port.')]: isPort
              }
            }
          ]
        },
        {
          if: ['nessus', 'nessus6'].includes(scanType),
          label: i18n.t('Nessus client policy'),
          text: i18n.t('Name of the policy to use on the nessus server.'),
          fields: [
            {
              key: 'nessus_clientpolicy',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['nessus6'].includes(scanType),
          label: i18n.t('Nessus scanner name'),
          text: i18n.t('Name of the scanner to use on the nessus server.'),
          fields: [
            {
              key: 'scannername',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['openvas'].includes(scanType),
          label: i18n.t('Alert ID'),
          text: i18n.t('ID of the alert configuration on the OpenVAS server.'),
          fields: [
            {
              key: 'openvas_alertid',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['openvas'].includes(scanType),
          label: i18n.t('Scan config ID'),
          text: i18n.t('ID of the scanning configuration on the OpenVAS server.'),
          fields: [
            {
              key: 'openvas_configid',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['openvas'].includes(scanType),
          label: i18n.t('Report format ID'),
          text: i18n.t('ID of the "CSV Results" report format on the OpenVAS server.'),
          fields: [
            {
              key: 'openvas_reportformatid',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Verify Hostname'),
          text: i18n.t('Verify hostname of server when connecting to the API.'),
          fields: [
            {
              key: 'verify_hostname',
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
          fields: [
            {
              key: 'engine_id',
              component: pfFormSelect,
              attrs: {
                disabled: true // TODO - Populate scan engines
              }
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Scan Template'),
          text: i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.'),
          fields: [
            {
              key: 'template_id',
              component: pfFormSelect,
              attrs: {
                disabled: true // TODO - Populate scan templates
              }
            }
          ]
        },
        {
          if: ['rapid7'].includes(scanType),
          label: i18n.t('Site'),
          text: i18n.t('After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.'),
          fields: [
            {
              key: 'site_id',
              component: pfFormSelect,
              attrs: {
                disabled: true // TODO - Populate sites
              }
            }
          ]
        },
        {
          label: i18n.t('Roles'),
          text: i18n.t('Nodes with the selected roles will be affected.'),
          fields: [
            {
              key: 'categories',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a role'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: roles.map(role => { return { value: role.id, text: role.id } })
              }
            }
          ]
        },
        {
          label: i18n.t('OS'),
          text: i18n.t('Nodes with the selected OS will be affected.'),
          fields: [
            {
              key: 'oses',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add an OS'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: [] // TODO: Add fingerbank search
              }
            }
          ]
        },
        {
          label: i18n.t('Duration'),
          text: i18n.t('Approximate duration of a scan. User being scanned on registration are presented a progress bar for this duration, afterwards the browser refreshes until scan is complete.'),
          fields: [
            {
              key: 'duration.interval',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Integer values required.')]: integer,
                [i18n.t('Positive values required.')]: minValue(0)
              }
            },
            {
              key: 'duration.unit',
              component: pfFormSelect,
              attrs: {
                options: [
                  { value: 's', text: i18n.t('seconds') },
                  { value: 'm', text: i18n.t('minutes') },
                  { value: 'h', text: i18n.t('hours') },
                  { value: 'D', text: i18n.t('days') },
                  { value: 'W', text: i18n.t('weeks') },
                  { value: 'M', text: i18n.t('months') },
                  { value: 'Y', text: i18n.t('years') }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Scan before registration'),
          text: i18n.t('If this option is enabled, the PF system will scan host before the registration.'),
          fields: [
            {
              key: 'pre_registration',
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
          fields: [
            {
              key: 'registration',
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
          fields: [
            {
              key: 'post_registration',
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
          fields: [
            {
              key: 'wmi_rules',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Rule'),
                emptyText: i18n.t('With no WMI rules specified, the scan engine will not be triggered.'),
                maxFields: pfConfigurationScanEngineWmiRules.length,
                sortable: true,
                field: {
                  component: pfField,
                  attrs: {
                    field: {
                      component: pfFormChosen,
                      attrs: {
                        collapseObject: true,
                        placeholder: i18n.t('Click to select a rule'),
                        trackBy: 'value',
                        label: 'text',
                        options: pfConfigurationScanEngineWmiRules
                      },
                      validators: {
                        [i18n.t('Rule required.')]: required,
                        [i18n.t('Duplicate Rule.')]: conditional((value) => {
                          return !(scanEngine.wmi_rules.filter(v => v === value).length > 1)
                        })
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

export const pfConfigurationScanEngineViewDefaults = (context = {}) => {
  const { scanType = null } = context
  switch (scanType) {
    case 'nessus':
      return {
        id: null,
        port: 8834
      }
    case 'nessus6':
      return {
        id: null,
        port: 8834,
        scannername: 'Local Scanner'
      }
    case 'openvas':
      return {
        id: null,
        port: 9390
      }
    case 'rapid7':
      return {
        id: null,
        port: 3780
      }
    default:
      return {
        id: null
      }
  }
}
