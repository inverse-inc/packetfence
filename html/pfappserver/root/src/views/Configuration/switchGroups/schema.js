import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'switchGroupIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'switchGroupIdNotExistsExcept',
    message: message || i18n.t('Switch Group exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSwitchGroups').then(response => {
        return response.filter(switche => switche.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

import { schemaInlineTriggers } from '../switches/schema'

export const schema = (props, roles) => {
  const {
    isNew,
    isClone,
    id,
  } = props

  const rolesSchema = roles.value.reduce((schema, role) => {
    return { ...schema, [`${role}Network`]: yup.string().nullable().isCIDR() }
  }, {});

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .switchGroupIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    description: yup.string()
      .nullable()
      .required(i18n.t('Description required.'))
      .label(i18n.t('Description')),
    inlineTrigger: schemaInlineTriggers.meta({ invalidFeedback: i18n.t('Inline conditions contains one or more errors.') }),
    type: yup.string().nullable().label(i18n.t('Type')),
    mode: yup.string().nullable().label(i18n.t('Mode')),
    group: yup.string().nullable().label(i18n.t('Group')),
    deauthMethod: yup.string().nullable().label(i18n.t('Method')),
    SNMPVersion: yup.string().nullable().label(i18n.t('Version')),
    SNMPCommunityRead: yup.string().nullable(),
    SNMPCommunityWrite: yup.string().nullable(),
    SNMPEngineID: yup.string().nullable(),
    SNMPUserNameRead: yup.string().nullable(),
    SNMPAuthProtocolRead: yup.string().nullable(),
    SNMPAuthPasswordRead: yup.string().nullable(),
    SNMPPrivProtocolRead: yup.string().nullable(),
    SNMPPrivPasswordRead: yup.string().nullable(),
    SNMPUserNameWrite: yup.string().nullable(),
    SNMPAuthProtocolWrite: yup.string().nullable(),
    SNMPAuthPasswordWrite: yup.string().nullable(),
    SNMPPrivProtocolWrite: yup.string().nullable(),
    SNMPPrivPasswordWrite: yup.string().nullable(),
    SNMPVersionTrap: yup.string().nullable(),
    SNMPCommunityTrap: yup.string().nullable(),
    SNMPUserNameTrap: yup.string().nullable(),
    SNMPAuthProtocolTrap: yup.string().nullable(),
    SNMPAuthPasswordTrap: yup.string().nullable(),
    SNMPPrivProtocolTrap: yup.string().nullable(),
    SNMPPrivPasswordTrap: yup.string().nullable(),
    macSearchesMaxNb: yup.string().nullable().label(i18n.t('Max')),
    macSearchesSleepInterval: yup.string().nullable().label(i18n.t('Interval')),
    cliTransport: yup.string().nullable().label(i18n.t('Transport')),
    cliUser: yup.string().nullable().label(i18n.t('Username')),
    cliPwd: yup.string().nullable().label(i18n.t('Password')),
    cliEnablePwd: yup.string().nullable().label(i18n.t('Password')),
    wsTransport: yup.string().nullable().label(i18n.t('Transport')),
    wsUser: yup.string().nullable().label(i18n.t('Username')),
    wsPwd: yup.string().nullable().label(i18n.t('Password')),
    uplink: yup.string().nullable(),
    controllerIp: yup.string().nullable(),
    disconnectPort: yup.string().nullable().minAsInt(1, i18n.t('Invalid port.')),
    coaPort: yup.string().nullable().minAsInt(1, i18n.t('Invalid port.')),
    radiusSecret: yup.string().nullable(),

    ...rolesSchema
  })
}

export default schema
