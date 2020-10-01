import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
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
    label: 'Name', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'ip',
    label: 'IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'port',
    label: 'Port', // i18n defer
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
    scanType = null // from router
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
                ...attributesFromMeta(meta, 'id'),
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
              attrs: attributesFromMeta(meta, 'ip')
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7', 'wmi'].includes(scanType),
          label: i18n.t('Username'),
          cols: [
            {
              namespace: 'username',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'username')
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
              attrs: attributesFromMeta(meta, 'domain')
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7', 'wmi'].includes(scanType),
          label: i18n.t('Password'),
          cols: [
            {
              namespace: 'password',
              component: pfFormPassword,
              attrs: attributesFromMeta(meta, 'password')
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
              attrs: attributesFromMeta(meta, 'port')
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
              attrs: attributesFromMeta(meta, 'nessus_clientpolicy')
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
              attrs: attributesFromMeta(meta, 'scannername')
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
              attrs: attributesFromMeta(meta, 'openvas_alertid')
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
              attrs: attributesFromMeta(meta, 'openvas_configid')
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
              attrs: attributesFromMeta(meta, 'openvas_reportformatid')
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
              component: pfFormRangeToggle,
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
              attrs: attributesFromMeta(meta, 'engine_id')
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
              attrs: attributesFromMeta(meta, 'template_id')
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
              attrs: attributesFromMeta(meta, 'site_id')
            }
          ]
        },
        {
          if: ['tenableio'].includes(scanType),
          label: i18n.t('TenableIO url'),
          text: i18n.t('URL of the tenableIO instance.'),
          fields: [
            {
              key: 'url',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'url'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'url', i18n.t('url'))
            }
          ]
        },
        {
          if: ['tenableio'].includes(scanType),
          label: i18n.t('Access Key'),
          text: i18n.t('TenableIO Access Key.'),
          fields: [
            {
              key: 'accessKey',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'accessKey'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'accessKey', i18n.t('accessKey'))
            }
          ]
        },
        {
          if: ['tenableio'].includes(scanType),
          label: i18n.t('TenableIO Secret Key'),
          text: i18n.t('TenableIO Secret Key.'),
          fields: [
            {
              key: 'secretKey',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'secretKey'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'secretKey', i18n.t('secretKey'))
            }
          ]
        },
        {
          if: ['tenableio'].includes(scanType),
          label: i18n.t('TenableIO scanner name'),
          text: i18n.t('Name of the scanner to use on the TenableIO instance.'),
          fields: [
            {
              key: 'scannername',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'scannername'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'scannername', i18n.t('scannername'))
            }
          ]
        },
        {
          if: ['tenableio'].includes(scanType),
          label: i18n.t('TenableIO client policy'),
          text: i18n.t('Name of the client policy to use.'),
          fields: [
            {
              key: 'tenableio_clientpolicy',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'tenableio_clientpolicy'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'tenableio_clientpolicy', i18n.t('tenableio_clientpolicy'))
            }
          ]
        },
        {
          if: ['tenableio'].includes(scanType),
          label: i18n.t('Folder ID'),
          text: i18n.t('Folder ID to use.'),
          fields: [
            {
              key: 'folderId',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'folderId'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'folderId', i18n.t('folderId'))
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
              attrs: attributesFromMeta(meta, 'categories')
            }
          ]
        },
        {
          if: ['nessus', 'nessus6', 'openvas', 'rapid7', 'tenableio'].includes(scanType),
          label: i18n.t('OS'),
          text: i18n.t('Nodes with the selected OS will be affected.'),
          cols: [
            {
              namespace: 'oses',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'oses')
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
              attrs: attributesFromMeta(meta, 'duration.interval')
            },
            {
              namespace: 'duration.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'duration.unit')
            }
          ]
        },
        {
          label: i18n.t('Scan before registration'),
          text: i18n.t('If this option is enabled, the PF system will scan host before the registration.'),
          cols: [
            {
              namespace: 'pre_registration',
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
                        ...attributesFromMeta(meta, 'wmi_rules'),
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
      ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasScans, scanExists))
      }
    },
    ip: validatorsFromMeta(meta, 'ip', 'IP'),
    username: validatorsFromMeta(meta, 'username', i18n.t('Username')),
    domain: validatorsFromMeta(meta, 'domain', i18n.t('Domain')),
    password: validatorsFromMeta(meta, 'password', i18n.t('Password')),
    port: validatorsFromMeta(meta, 'port', i18n.t('Port')),
    nessus_clientpolicy: validatorsFromMeta(meta, 'nessus_clientpolicy', i18n.t('Policy')),
    scannername: validatorsFromMeta(meta, 'scannername', i18n.t('Name')),
    openvas_alertid: validatorsFromMeta(meta, 'openvas_alertid', 'ID'),
    openvas_configid: validatorsFromMeta(meta, 'openvas_configid', 'ID'),
    openvas_reportformatid: validatorsFromMeta(meta, 'openvas_reportformatid', 'ID'),
    engine_id: validatorsFromMeta(meta, 'engine_id', i18n.t('Engine')),
    template_id: validatorsFromMeta(meta, 'template_id', i18n.t('Template')),
    site_id: validatorsFromMeta(meta, 'site_id', i18n.t('Site')),
    categories: validatorsFromMeta(meta, 'categories', i18n.t('Categories')),
    oses: validatorsFromMeta(meta, 'oses', 'OS'),
    'duration.interval': validatorsFromMeta(meta, 'duration.interval', i18n.t('Interval')),
    'duration.unit': validatorsFromMeta(meta, 'duration.unit', i18n.t('Unit')),
    wmi_rules: {
      $each: {
        [i18n.t('Duplicate Rule.')]: conditional((value) => {
          return !(form.wmi_rules.filter(v => v === value).length > 1)
        })
      }
    }
  }
}
