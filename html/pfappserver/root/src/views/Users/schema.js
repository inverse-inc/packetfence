import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { MysqlDatabase } from '@/globals/mysql'
import { pfActionsSchema as schemaActions } from '@/globals/pfActions'

// combine person and password tables
const mysqlDatabase = { ...MysqlDatabase.password, ...MysqlDatabase.person }

// build schema from mysql table
const mysqlDatabaseSchema = Object.keys(mysqlDatabase).reduce((schema, key) => {
  return { ...schema,
    [key]: yup.string().nullable()
      .mysql(mysqlDatabase[key])
  }
}, {})

const schemaPid = yup.string().nullable().required(i18n.t('Username required.'))

yup.addMethod(yup.string, 'pidNotExistsExcept', function (except, message) {
  return this.test({
    name: 'pidNotExistsExcept',
    message: message || i18n.t('Username exists.'),
    test: (value) => !value
      || (except && except === value)
      || store.dispatch('$_users/exists', value)
        .then(() => false) // pid exists
        .catch(() => true) // pid not exists
  })
})

yup.addMethod(yup.string, 'pidExists', function (message) {
  return this.test({
    name: 'pidExists',
    message: message || i18n.t('PID exists.'),
    test: (value) => !value
      || store.dispatch('$_users/exists', value)
        .then(() => true) // pid exists
        .catch(() => false) // pid not exists
  })
})

yup.addMethod(yup.string, 'pidNotExists', function (message) {
  return this.test({
    name: 'pidNotExists',
    message: message || i18n.t('PID does not exist.'),
    test: (value) => !value
      || store.dispatch('$_users/exists', value)
        .then(() => false) // pid exists
        .catch(() => true) // pid not exists
  })
})

export const single = (props, form) => {
  const {
    pid
  } = props

  const {
    pid_overwrite
  } = form || {}

  return yup.object().shape(mysqlDatabaseSchema).concat(
    yup.object().shape({
      pid: yup.string()
        .when('pid_overwrite', () => ((pid_overwrite)
          ? schemaPid
          : schemaPid.pidNotExistsExcept(pid, i18n.t('Username exists.'))
        )),
      password: (pid)
        ? yup.string().nullable()
        : yup.string().nullable().required(i18n.t('Password required.'))
          .min(6, i18n.t('Password must be at least 6 characters.')),
      email: yup.string().nullable().required(i18n.t('Email required.')),
      actions: schemaActions,
      anniversary: yup.string().nullable().isDateFormat(),
      birthday: yup.string().nullable().isDateFormat(),
      valid_from: yup.string().nullable(),
      expiration: yup.string().nullable().required(i18n.t('Date required.'))
    })
  )
}

export const multiple = (props, form, domainName) => {
  const {
    quantity
  } = form || {}

  const maxLength = (domainName)
    ? mysqlDatabase.pid.maxLength - Math.floor(Math.log10(quantity || 1) + 1) - `@${domainName}`.length
    : mysqlDatabase.pid.maxLength - Math.floor(Math.log10(quantity || 1) + 1)

  return yup.object().shape(mysqlDatabaseSchema).concat(
    yup.object().shape({
      prefix: yup.string().nullable().required(i18n.t('Username prefix required.'))
        .max(maxLength, i18n.t('Maximum {maxLength} characters.', { maxLength })),
      quantity: yup.string().nullable().required(i18n.t('Quantity required.'))
        .minAsInt(1, i18n.t('Minimum 1.')),
      actions: schemaActions,
      valid_from: yup.string().nullable(),
      expiration: yup.string().nullable().required(i18n.t('Date required.'))
    })
  )
}

export const csv = () => {
  return yup.object().shape({
    actions: schemaActions,
    valid_from: yup.string().nullable(),
    expiration: yup.string().nullable().required(i18n.t('Date required.'))
  })
}

export { yup }
