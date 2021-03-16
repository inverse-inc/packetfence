import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { MysqlDatabase } from '@/globals/mysql'
import { pfActionsSchema as schemaActions } from '@/globals/pfActions'

export const createSchema = (props, form) => {
  return yup.object().shape({})
}

export const updateSchema = (props, form) => {
  return yup.object().shape({
    unregdate: yup.string().nullable().required()    

  })
}
/*





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

export const schema = (props, form) => {

export const createValidators = buildValidatorsFromTableSchemas(
  MysqlDatabase.node, // use `node` table schema
  {
    mac: {
      [i18n.t('MAC address required.')]: required,
      [i18n.t('Invalid MAC address.')]: isMacAddress,
      [i18n.t('MAC address exists.')]: nodeExists
    },
    pid: {
      [i18n.t('Owner does not exist.')]: userNotExists
    }
  }
)
export const updateValidators = buildValidatorsFromTableSchemas(
  MysqlDatabase.node, // use `node` table schema
  {
    pid: {
      [i18n.t('Username required.')]: required,
      [i18n.t('Owner does not exist.')]: userNotExists
    }
  }
)
    
  const {
    pid
  } = props
  
  const {
    pid_overwrite,
    valid_from,
    expiration
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
      valid_from: yup.string().nullable()
        .isDateCompare('>=', new Date(), 'YYYY-MM-DD', i18n.t('Date must be today or later.'))
        .isDateCompare('<', expiration, 'YYYY-MM-DD', i18n.t('Date must be less than end date.')),
      expiration: yup.string().nullable().required(i18n.t('Date required.'))
        .isDateCompare('>', valid_from, 'YYYY-MM-DD', i18n.t('Date must be greater than start date.'))
    })
  )
}


export const csv = (props, form) => {
  const {
    expiration,
    valid_from
  } = form

  return yup.object().shape({
    actions: schemaActions,
    valid_from: yup.string().nullable()
      .isDateCompare('>=', new Date(), 'YYYY-MM-DD', i18n.t('Date must be today or later.'))
      .isDateCompare('<', expiration, 'YYYY-MM-DD', i18n.t('Date must be less than end date.')),
    expiration: yup.string().nullable().required(i18n.t('Date required.'))
      .isDateCompare('>', valid_from, 'YYYY-MM-DD', i18n.t('Date must be greater than start date.'))
  })
}
*/