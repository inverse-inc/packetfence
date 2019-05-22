import i18n from '@/utils/locale'
import pfField from '@/components/pfField'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationActions,
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional,
  hasPortalModules,
  portalModuleExists
} from '@/globals/pfValidators'

const {
  required
} = require('vuelidate/lib/validators')

const colorsList = [
  // Colors for types under `Multiple`
  // https://www.colorbox.io/#steps=4#hue_start=223#hue_end=211#hue_curve=linear#sat_start=30#sat_end=30#sat_curve=linear#sat_rate=134#lum_start=48#lum_end=100#lum_curve=linear#lock_hex=
  ['#49577a', '#647ba7', '#7ea1d3', '#98caff'],
  // Colors for types under `Authentication`
  // https://www.colorbox.io/#steps=21#hue_start=359#hue_end=257#hue_curve=linear#sat_start=15#sat_end=85#sat_curve=linear#sat_rate=200#lum_start=100#lum_end=72#lum_curve=linear#lock_hex=
  ['#ffb3b4', '#fbb0b8', '#f8aebb', '#f4abbf', '#f1a9c2', '#eda6c5', '#eaa4c8', '#e69bc9', '#e271c0', '#df30b9', '#db00be', '#d800cd', '#cc00d4', '#b700d1', '#a300cd', '#8f00c9', '#7b00c6', '#6900c2', '#5600bf', '#4500bb', '#3400b8'],
  // Colors for types under `Other`
  // https://www.colorbox.io/#steps=16#hue_start=183#hue_end=70#hue_curve=linear#sat_start=83#sat_end=62#sat_curve=linear#sat_rate=134#lum_start=48#lum_end=100#lum_curve=linear#lock_hex=
  ['#00747a', '#008379', '#008c70', '#009564', '#009e56', '#00a746', '#00af34', '#04b822', '#07c110', '#1bca0b', '#38d310', '#57dc15', '#76e41a', '#97ed1f', '#b9f625', '#dcff2b']
]

export const pfConfigurationPortalModuleTypes = () => {
  let moduleTypes = [
    {
      name: i18n.t('Multiple'),
      types: [
        { type: 'Choice', name: i18n.t('Choice') },
        { type: 'Chained', name: i18n.t('Chained') }
      ]
    },
    {
      name: i18n.t('Authentication'),
      types: [
        { type: 'Authentication::Billing', name: i18n.t('Billing') },
        { type: 'Authentication::Blackhole', name: i18n.t('Blackhole') },
        { type: 'Authentication::Choice', name: i18n.t('Choice') },
        { type: 'Authentication::Email', name: i18n.t('Email') },
        { type: 'Authentication::Login', name: i18n.t('Login') },
        { type: 'Authentication::Null', name: i18n.t('Null') },
        { type: 'Authentication::Password', name: i18n.t('Password') },
        { type: 'Authentication::OAuth::Facebook', name: 'Facebook' },
        { type: 'Authentication::OAuth::Github', name: 'Github' },
        { type: 'Authentication::OAuth::Google', name: 'Google' },
        { type: 'Authentication::OAuth::Instagram', name: 'Instagram' },
        { type: 'Authentication::OAuth::LinkedIn', name: 'LinkedIn' },
        { type: 'Authentication::OAuth::OpenID', name: 'OpenID' },
        { type: 'Authentication::OAuth::Pinterest', name: 'Pinterest' },
        { type: 'Authentication::OAuth::Twitter', name: 'Twitter' },
        { type: 'Authentication::OAuth::WindowsLive', name: 'WindowsLive' },
        { type: 'Authentication::SAML', name: 'SAML' },
        { type: 'Authentication::SMS', name: i18n.t('SMS') },
        { type: 'Authentication::Sponsor', name: i18n.t('Sponsor') }
      ]
    },
    {
      name: i18n.t('Other'),
      types: [
        { type: 'FixedRole', name: i18n.t('Fixed Role') },
        { type: 'Message', name: i18n.t('Message') },
        { type: 'Provisioning', name: i18n.t('Provisioning') },
        { type: 'SelectRole', name: i18n.t('Select Role') },
        { type: 'Survey', name: i18n.t('Survey') },
        { type: 'URL', name: i18n.t('URL') }
      ]
    }
  ]
  // Assign colors
  moduleTypes.forEach((group, i) => {
    group.types.forEach((item, j) => {
      item.color = colorsList[i][j]
    })
  })
  return moduleTypes
}

export const pfConfigurationPortalModuleTypeName = (type) => {
  let name = type
  pfConfigurationPortalModuleTypes().find(group => {
    const module = group.types.find(groupType => groupType.type === type)
    if (module) {
      name = module.name
      return group
    }
  })
  return name
}

export const pfConfigurationPortalModuleFields = {
  id: ({ isNew = false, isClone = false, options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Name'),
      fields: [
        {
          key: 'id',
          component: pfFormInput,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'id'),
            ...{
              disabled: (!isNew && !isClone)
            }
          },
          validators: {
            ...pfConfigurationValidatorsFromMeta(meta, 'id', i18n.t('Name')),
            ...{
              [i18n.t('Portal module exists.')]: not(and(required, conditional(isNew || isClone), hasPortalModules, portalModuleExists))
            }
          }
        }
      ]
    }
  },
  actions: () => {
    return {
      label: i18n.t('Actions'),
      fields: [
        {
          key: 'actions',
          component: pfFormFields,
          attrs: {
            buttonLabel: i18n.t('Add Action'),
            emptyText: i18n.t('If none are specified, the default ones of the module will be used.'),
            sortable: true,
            field: {
              component: pfFieldTypeValue,
              attrs: {
                typeLabel: i18n.t('Select action type'),
                valueLabel: i18n.t('Select action value'),
                fields: [
                  pfConfigurationActions.set_role_by_name,
                  pfConfigurationActions.set_access_duration,
                  pfConfigurationActions.set_unreg_date,
                  pfConfigurationActions.set_time_balance,
                  pfConfigurationActions.set_bandwidth_balance
                ]
              }
            }
          }
        }
      ]
    }
  },
  admin_role: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Admin Roles'),
      text: i18n.t('Which roles should have access to this module to select the role'),
      fields: [
        {
          key: 'admin_role',
          component: pfFormChosen,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'admin_role'),
            ...{
              multiple: true
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'admin_role', i18n.t('Role'))
        }
      ]
    }
  },
  aup_template: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('AUP template'),
      text: i18n.t('The template to use for the Acceptable Use Policy'),
      fields: [
        {
          key: 'aup_template',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'aup_template'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'aup_template', i18n.t('Template'))
        }
      ]
    }
  },
  custom_fields: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Mandatory fields'),
      text: i18n.t('The additionnal fields that should be required for registration'),
      fields: [
        {
          key: 'custom_fields',
          component: pfFormChosen,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'custom_fields'),
            ...{
              multiple: true
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'custom_fields', i18n.t('Fields'))
        }
      ]
    }
  },
  description: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Description'),
      text: i18n.t('The description that will be displayed to users'),
      fields: [
        {
          key: 'description',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'description'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'description', i18n.t('Description'))
        }
      ]
    }
  },
  fields_to_save: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Fields to save'),
      text: i18n.t('These fields will be saved through the registration process'),
      fields: [
        {
          key: 'fields_to_save',
          component: pfFormChosen,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'fields_to_save'),
            ...{
              multiple: true
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'fields_to_save', i18n.t('Fields'))
        }
      ]
    }
  },
  forced_sponsor: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Forced Sponsor'),
      text: i18n.t('Defines the sponsor email used. Leave empty so that the user has to specify a sponsor.'),
      fields: [
        {
          key: 'forced_sponsor',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'forced_sponsor'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'forced_sponsor', i18n.t('Email'))
        }
      ]
    }
  },
  landing_template: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Landgin template'),
      text: i18n.t('The template to use for the signup'),
      fields: [
        {
          key: 'landing_template',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'landing_template'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'landing_template', i18n.t('Template'))
        }
      ]
    }
  },
  list_role: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Roles'),
      text: i18n.t('Which roles can be select'),
      fields: [
        {
          key: 'list_role',
          component: pfFormChosen,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'list_role'),
            ...{
              multiple: true
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'list_role', i18n.t('Role'))
        }
      ]
    }
  },
  message: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Message'),
      text: i18n.t('The message that will be displayed to the user. Use with caution as the HTML contained in this field will NOT be escaped.'),
      fields: [
        {
          key: 'message',
          component: pfFormTextarea,
          attrs: pfConfigurationAttributesFromMeta(meta, 'message'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'message', i18n.t('Message'))
        }
      ]
    }
  },
  modules: (context) => {
    const {
      form = {},
      options: {
        meta: { modules = {} } = {}
      } = {}
    } = context
    return {
      label: i18n.t('Modules'),
      fields: [
        {
          key: 'modules',
          component: pfFormFields,
          attrs: {
            buttonLabel: i18n.t('Add Module'),
            sortable: true,
            field: {
              component: pfField,
              attrs: {
                field: {
                  component: pfFormChosen,
                  attrs: {
                    ...pfConfigurationAttributesFromMeta(modules, 'item'),
                    ...{
                      placeholder: i18n.t('Click to select a module'),
                      groupLabel: 'group',
                      groupValues: 'options'
                    }
                  },
                  validators: {
                    ...pfConfigurationValidatorsFromMeta(modules, 'item', i18n.t('Module')),
                    ...{
                      [i18n.t('Duplicate module.')]: conditional((value) => {
                        return !(form.modules.filter(v => v === value).length > 1)
                      })
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  },
  multi_source_ids: (context) => {
    const {
      form = {},
      options: {
        meta = {}
      } = {}
    } = context
    return {
      label: i18n.t('Authentication Sources'),
      text: i18n.t('The sources to use in the module. If no sources are specified, all the sources of the connection profile will be used.'),
      fields: [
        {
          key: 'multi_source_ids',
          component: pfFormFields,
          attrs: {
            buttonLabel: i18n.t('Add Source'),
            sortable: true,
            field: {
              component: pfField,
              attrs: {
                field: {
                  component: pfFormChosen,
                  attrs: {
                    ...pfConfigurationAttributesFromMeta(meta, 'multi_source_ids'),
                    ...{
                      placeholder: i18n.t('Click to select a source'),
                      multiple: false,
                      closeOnSelect: true
                    }
                  },
                  validators: {
                    ...pfConfigurationValidatorsFromMeta(meta, 'multi_source_ids', i18n.t('Source')),
                    ...{
                      [i18n.t('Duplicate source.')]: conditional((value) => {
                        return !(form.multi_source_ids.filter(v => v === value).length > 1)
                      })
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  },
  multi_source_auth_classes: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Sources by Auth Class'),
      text: i18n.t('The sources of these authentication classes and part of the connection profile will be added to the available sources'),
      fields: [
        {
          key: 'multi_source_auth_classes',
          component: pfFormTextarea,
          attrs: pfConfigurationAttributesFromMeta(meta, 'multi_source_auth_classes'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'multi_source_auth_classes', i18n.t('Classes'))
        }
      ]
    }
  },
  multi_source_object_classes: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Sources by Class'),
      text: i18n.t('The sources inheriting from these classes and part of the connection profile will be added to the available sources'),
      fields: [
        {
          key: 'multi_source_object_classes',
          component: pfFormTextarea,
          attrs: pfConfigurationAttributesFromMeta(meta, 'multi_source_object_classes'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'multi_source_object_classes', i18n.t('Classes'))
        }
      ]
    }
  },
  multi_source_types: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Sources by type'),
      text: i18n.t('The sources of these types and part of the connection profile will be added to the available sources'),
      fields: [
        {
          key: 'multi_source_types',
          component: pfFormTextarea,
          attrs: pfConfigurationAttributesFromMeta(meta, 'multi_source_types'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'multi_source_types', i18n.t('Types'))
        }
      ]
    }
  },
  pid_field: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('PID field'),
      text: i18n.t('Which field should be used as the PID.'),
      fields: [
        {
          key: 'pid_field',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'pid_field'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'pid_field', 'PID')
        }
      ]
    }
  },
  show_first_module_on_default: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Show first module when none is selected'),
      fields: [
        {
          key: 'show_first_module_on_default',
          component: pfFormToggle,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'show_first_module_on_default'),
            ...{
              values: { checked: 'enabled', unchecked: 'disabled' }
            }
          }
        }
      ]
    }
  },
  signup_template: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Signup template'),
      text: i18n.t('The template to use for the signup'),
      fields: [
        {
          key: 'signup_template',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'signup_template'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'signup_template', 'Template')
        }
      ]
    }
  },
  skipable: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Skippable'),
      text: i18n.t('Whether or not, this message can be skipped'),
      fields: [
        {
          key: 'skipable',
          component: pfFormToggle,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'skipable'),
            ...{
              values: { checked: 1, unchecked: 0 }
            }
          }
        }
      ]
    }
  },
  source_id: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Authentication Source'),
      text: i18n.t('The source to use in the module. If no source is specified, all the sources of the connection profile will be used.'),
      fields: [
        {
          key: 'source_id',
          component: pfFormChosen,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'source_id', i18n.t('Source')),
            ...{
              placeholder: i18n.t('Click to select a source')
            }
          }
        }
      ]
    }
  },
  stone_roles: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Roles'),
      text: i18n.t('Nodes with the selected roles will be affected'),
      fields: [
        {
          key: 'stone_roles',
          component: pfFormChosen,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'stone_roles'),
            ...{
              multiple: true
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'stone_roles', i18n.t('Role'))
        }
      ]
    }
  },
  survey_id: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Survey'),
      text: i18n.t('The survey to use in this portal module. Surveys are defined in survey.conf'),
      fields: [
        {
          key: 'survey_id',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'survey_id'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'survey_id', i18n.t('Survey'))
        }
      ]
    }
  },
  template: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Template'),
      fields: [
        {
          key: 'template',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'template'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'template', 'Template')
        }
      ]
    }
  },
  url: ({ options: { meta = {} } } = {}) => {
    return {
      label: 'URL',
      text: i18n.t('The URL on which the user should be redirected.'),
      fields: [
        {
          key: 'url',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'url'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'url', 'URL')
        }
      ]
    }
  },
  username: ({ options: { meta = {} } } = {}) => {
    return {
      label: i18n.t('Username'),
      text: i18n.t('Defines the username used for all authentications'),
      fields: [
        {
          key: 'username',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'username'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'username', 'Username')
        }
      ]
    }
  },
  with_aup: () => {
    return {
      label: i18n.t('Require AUP'),
      text: i18n.t('Require the user to accept the AUP'),
      fields: [
        {
          key: 'with_aup',
          component: pfFormToggle,
          attrs: {
            values: { checked: 1, unchecked: 0 }
          }
        }
      ]
    }
  }
}

export const pfConfigurationPortalModuleViewFields = (context = {}) => {
  const { moduleType = null } = context
  switch (moduleType) {
    case 'Choice':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.show_first_module_on_default(context),
            pfConfigurationPortalModuleFields.template(context),
            pfConfigurationPortalModuleFields.actions(context),
            pfConfigurationPortalModuleFields.modules(context)
          ]
        }
      ]
    case 'Chained':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.actions(context),
            pfConfigurationPortalModuleFields.modules(context)
          ]
        }
      ]
    case 'Authentication::Billing':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            // pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.multi_source_ids(context)
          ]
        }
      ]
    case 'Authentication::Blackhole':
      return [
        {
          tab: null,
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.template(context)
          ]
        }
      ]
    case 'Authentication::Choice':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            // pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.template(context),
            pfConfigurationPortalModuleFields.actions(context),
            pfConfigurationPortalModuleFields.modules(context),
            pfConfigurationPortalModuleFields.multi_source_ids(context),
            pfConfigurationPortalModuleFields.multi_source_object_classes(context),
            pfConfigurationPortalModuleFields.multi_source_types(context),
            pfConfigurationPortalModuleFields.multi_source_auth_classes(context)
          ]
        }
      ]
    case 'Authentication::Email':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Authentication::Login':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            // pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.actions(context),
            pfConfigurationPortalModuleFields.multi_source_ids(context)
          ]
        }
      ]
    case 'Authentication::Null':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    // "Authentication::OAuth"
    case 'Authentication::OAuth::Facebook':
    case 'Authentication::OAuth::Github':
    case 'Authentication::OAuth::Google':
    case 'Authentication::OAuth::Instagram':
    case 'Authentication::OAuth::LinkedIn':
    case 'Authentication::OAuth::OpenID':
    case 'Authentication::OAuth::Pinterest':
    case 'Authentication::OAuth::Twitter':
    case 'Authentication::OAuth::WindowsLive':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.landing_template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Authentication::Password':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            // pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.username(context),
            pfConfigurationPortalModuleFields.actions(context),
            pfConfigurationPortalModuleFields.multi_source_ids(context)
          ]
        }
      ]
    case 'Authentication::SAML':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Authentication::SMS':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Authentication::Sponsor':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.pid_field(context),
            pfConfigurationPortalModuleFields.source_id(context),
            pfConfigurationPortalModuleFields.custom_fields(context),
            pfConfigurationPortalModuleFields.fields_to_save(context),
            pfConfigurationPortalModuleFields.with_aup(context),
            pfConfigurationPortalModuleFields.aup_template(context),
            pfConfigurationPortalModuleFields.signup_template(context),
            pfConfigurationPortalModuleFields.forced_sponsor(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'FixedRole':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.stone_roles(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Message':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.message(context),
            pfConfigurationPortalModuleFields.template(context),
            pfConfigurationPortalModuleFields.skipable(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Provisioning':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.skipable(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Root':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.modules(context)
          ]
        }
      ]
    case 'SelectRole':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.admin_role(context),
            pfConfigurationPortalModuleFields.list_role(context),
            pfConfigurationPortalModuleFields.template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'ShowLocalAccount':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.template(context),
            pfConfigurationPortalModuleFields.skipable(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'Survey':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.survey_id(context),
            pfConfigurationPortalModuleFields.template(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    case 'URL':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationPortalModuleFields.id(context),
            pfConfigurationPortalModuleFields.description(context),
            pfConfigurationPortalModuleFields.skipable(context),
            pfConfigurationPortalModuleFields.url(context),
            pfConfigurationPortalModuleFields.actions(context)
          ]
        }
      ]
    default:
      return [{}]
  }
}
