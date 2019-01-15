import i18n from '@/utils/locale'
import {
  pfConfigurationViewFields
} from '@/globals/configuration/pfConfiguration'

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
      name: 'Multiple',
      types: [
        { type: 'Choice', name: i18n.t('Choice') },
        { type: 'Chained', name: i18n.t('Chained') }
      ]
    },
    {
      name: 'Authentication',
      types: [
        { type: 'Authentication::Billing', name: i18n.t('Billing') },
        { type: 'Authentication::Blackhole', name: i18n.t('Blackhole') },
        { type: 'Authentication::Billing', name: i18n.t('Billing') },
        { type: 'Authentication::Choice', name: i18n.t('Choice') },
        { type: 'Authentication::Email', name: i18n.t('Email') },
        { type: 'Authentication::Login', name: i18n.t('Login') },
        { type: 'Authentication::Null', name: i18n.t('Null') },
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
      name: 'Other',
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

export const pfConfigurationPortalModuleViewFields = (context = {}) => {
  const { moduleType = null } = context
  switch (moduleType) {
    case 'Choice':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationViewFields.id(context),
            pfConfigurationViewFields.description,
            pfConfigurationViewFields.show_first_module_on_default,
            pfConfigurationViewFields.template
          ]
        }
      ]
    case 'Chained':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationViewFields.id(context),
            pfConfigurationViewFields.description
          ]
        }
      ]
    case 'Authentication::Choice':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationViewFields.id(context),
            pfConfigurationViewFields.description,
            // TODO: mandatory fields
            pfConfigurationViewFields.template
          ]
        }
      ]
    case 'Authentication::Email':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationViewFields.id(context),
            pfConfigurationViewFields.description,
            // TODO: mandatory fields
            pfConfigurationViewFields.template
          ]
        }
      ]
    case 'Authentication::SMS':
      return [
        {
          tab: null, // ignore tabs
          fields: [
            pfConfigurationViewFields.id(context),
            pfConfigurationViewFields.description,
            // TODO: mandatory fields
            pfConfigurationViewFields.pid_field,
            pfConfigurationViewFields.template
          ]
        }
      ]
    default:
      return [
        {
          tab: null, // ignore tabs
          fields: []
        }
      ]
  }
}

// ag default /usr/local/pf/html/captive-portal/lib/captiveportal/PacketFence/DynamicRouting/*
export const pfConfigurationPortalModuleViewDefaults = (context = {}) => {
  const { moduleType = null } = context
  switch (moduleType) {
    case 'Choice':
      return {
        template: 'content-with-choice.html'
      }
    case 'Authentication::SMS':
      return {
        pid_field: 'telephone'
      }
    case 'Provisioning':
      return {
        skipable: 'disabled'
      }
    default:
      return {}
  }
}
