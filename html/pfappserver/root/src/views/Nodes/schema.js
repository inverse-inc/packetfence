import { MysqlDatabase } from '@/globals/mysql'
import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { yup as yupUsers } from '@/views/Users/schema'

const mysqlDatabase = MysqlDatabase.node

// build schema from mysql table
const mysqlDatabaseSchema = Object.keys(mysqlDatabase).reduce((schema, key) => {
  return { ...schema,
    [key]: yup.string().nullable()
      .mysql(mysqlDatabase[key])
  }
}, {})

yup.addMethod(yup.string, 'nodeExists', function (message) {
  return this.test({
    name: 'nodeExists',
    message: message || i18n.t('MAC address exists.'),
    test: (value) => { 
      if (!value)
        return true
      // standardize MAC address
      value = value.toLowerCase().replace(/[^0-9a-f]/g, '').split('').reduce((a, c, i) => {
        a += ((i % 2) === 0 || i >= 11) ? c : c + ':'
        return a
      })
      if (value.length !== 17)
        return true
      return store.dispatch('$_nodes/exists', value)
        .then(() => false) // node exists
        .catch(() => true) // node not exists
    }
  })
})

export { yup }

export const createSchema = () => {
  return yup.object().shape(mysqlDatabaseSchema).concat(
    yup.object().shape({
      pid: yupUsers.string().nullable()
        .pidExists(i18n.t('PID does not exist.')),
      mac: yup.string().nullable()
        .required(i18n.t('MAC address required.'))
        .isMAC(i18n.t('Invalid MAC address.'))
        .nodeExists(i18n.t('MAC address exists.'))
    })
  )
}

export const updateSchema = () => {
  return yup.object().shape(mysqlDatabaseSchema).concat(
    yup.object().shape({
      pid: yupUsers.string().nullable()
        .required(i18n.t('Owner required.'))  
        .pidExists(i18n.t('PID does not exist.'))
    })
  )
}

export const importSchema = () => {
  return yup.object().shape({})
}