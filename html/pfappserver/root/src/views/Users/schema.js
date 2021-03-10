import store from '@/store'
import i18n from '@/utils/locale'
import yup, { MysqlEnum, MysqlNumber, MysqlString, MysqlEmail } from '@/utils/yup'
import { mysqlLimits as MysqlLimits } from '@/globals/mysqlLimits'
import { pfActionsSchema as schemaActions } from '@/globals/pfActions'

const mysqlTable = {
  tenant_id:        Object.assign(MysqlLimits.int, { type: MysqlNumber, default: 1 }),
  pid:              { type: MysqlString, maxLength: 255 },
  firstname:        { type: MysqlString, maxLength: 255, default: null },
  lastname:         { type: MysqlString, maxLength: 255, default: null },
  email:            { type: MysqlEmail, maxLength: 255, default: null },
  telephone:        { type: MysqlString, maxLength: 255, default: null },
  company:          { type: MysqlString, maxLength: 255, default: null },
  address:          { type: MysqlString, maxLength: 255, default: null },
  notes:            { type: MysqlString, maxLength: 255, default: null },
  sponsor:          { type: MysqlString, maxLength: 255, default: null },
  anniversary:      { type: MysqlString, maxLength: 255, default: null },
  birthday:         { type: MysqlString, maxLength: 255, default: null },
  gender:           { type: MysqlString, maxLength: 1, default: null },
  lang:             { type: MysqlString, maxLength: 255, default: null },
  nickname:         { type: MysqlString, maxLength: 255, default: null },
  cell_phone:       { type: MysqlString, maxLength: 255, default: null },
  work_phone:       { type: MysqlString, maxLength: 255, default: null },
  title:            { type: MysqlString, maxLength: 255, default: null },
  building_number:  { type: MysqlString, maxLength: 255, default: null },
  apartment_number: { type: MysqlString, maxLength: 255, default: null },
  room_number:      { type: MysqlString, maxLength: 255, default: null },
  custom_field_1:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_2:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_3:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_4:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_5:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_6:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_7:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_8:   { type: MysqlString, maxLength: 255, default: null },
  custom_field_9:   { type: MysqlString, maxLength: 255, default: null },
  portal:           { type: MysqlString, maxLength: 255, default: null },
  source:           { type: MysqlString, maxLength: 255, default: null },
  psk:              { type: MysqlString, maxLength: 255, default: null },
  potd:             { type: MysqlEnum, enum: ['no', 'yes'], default: 'no' }
}

// build schema from mysql table
const schemaMysqlTable = Object.keys(mysqlTable).reduce((schema, key) => {
  return { ...schema,
    [key]: yup.string().nullable()
      .mysql(mysqlTable[key])
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

export const single = (props, form) => {
  const {
    pid
  } = props
  
  const {
    pid_overwrite,
    valid_from,
    expiration
  } = form || {}

  return yup.object().shape(schemaMysqlTable).concat(
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

export const multiple = (props, form, domainName) => {
  const {
    quantity,
    valid_from,
    expiration
  } = form || {}
  
  const maxLength = (domainName)
    ? mysqlTable.pid.maxLength - Math.floor(Math.log10(quantity || 1) + 1) - `@${domainName}`.length
    : mysqlTable.pid.maxLength - Math.floor(Math.log10(quantity || 1) + 1)
  
  return yup.object().shape(schemaMysqlTable).concat(
    yup.object().shape({
      prefix: yup.string().nullable().required(i18n.t('Username prefix required.'))
        .max(maxLength, i18n.t('Maximum {maxLength} characters.', { maxLength })),
      quantity: yup.string().nullable().required(i18n.t('Quantity required.'))
        .minAsInt(1, i18n.t('Minimum 1.')),
      actions: schemaActions,
      valid_from: yup.string().nullable()
        .isDateCompare('>=', new Date(), 'YYYY-MM-DD', i18n.t('Date must be today or later.'))
        .isDateCompare('<', expiration, 'YYYY-MM-DD', i18n.t('Date must be less than end date.')),
      expiration: yup.string().nullable().required(i18n.t('Date required.'))
        .isDateCompare('>', valid_from, 'YYYY-MM-DD', i18n.t('Date must be greater than start date.'))
    })
  )
}   