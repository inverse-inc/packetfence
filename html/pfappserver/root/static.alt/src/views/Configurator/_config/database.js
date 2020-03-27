import Vue from 'vue'
import store from '@/store'
import i18n from '@/utils/locale'
import pfButton from '@/components/pfButton'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  or,
  conditional
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const view = (form = {}, meta = {}) => {
  let {
    database: {
      db,
      root_pass = ''
    } = {}
  } = form
  const {
    database: {
      // advancedMode = false,
      setRootPassword = false,
      rootPasswordIsRequired = true,
      rootPasswordIsValid = false,
      rootPasswordIsInvalid = false,
      databaseExists = false,
      databaseCreationError = false,
      userIsValid = false,
      userCreationError = false,
      secureDatabase = null,
      createDatabase = null,
      assignDatabase = null
    } = {}
  } = meta
  db = db || 'pf'
  return [
    {
      tab: null,
      rows: [
        /**
         * Advanced settings
         */
        /*{
          if: advancedMode,
          label: i18n.t('Hostname'),
          text: i18n.t('Server the MySQL server is running on.'),
          cols: [
            {
              namespace: 'database.host',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'database.host')
            }
          ]
        },
        {
          if: advancedMode,
          label: i18n.t('Port'),
          text: i18n.t('Port the MySQL server is running on.'),
          cols: [
            {
              namespace: 'database.port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'database.port')
            }
          ]
        },*/
        /**
         * Root password
         */
        {
          if: rootPasswordIsRequired && setRootPassword,
          label: i18n.t('Root Password'),
          text: i18n.t('Define a root password for the MySQL server.'),
          cols: [
            {
              namespace: 'database.root_pass',
              component: pfFormPassword,
              attrs: {
                generate: true,
                readonly: rootPasswordIsValid,
                testLabel: i18n.t('Set Password'),
                test: () => {
                  return secureDatabase()
                }
              }
            }
          ]
        },
        {
          if: rootPasswordIsRequired && !setRootPassword,
          label: i18n.t('Root Password'),
          text: i18n.t('Current root password of the MySQL server.'),
          cols: [
            {
              namespace: 'database.root_pass',
              component: pfFormPassword,
              attrs: {
                readonly: rootPasswordIsValid,
                stateMap: { false: false, true: rootPasswordIsValid ? true : null }
              }
            }
          ]
        },
        {
          if: rootPasswordIsRequired && !(setRootPassword || rootPasswordIsValid),
          label: true, // trick to keep bottom margin in pfConfigView
          cols: [
            {
              component: pfButton,
              attrs: {
                label: i18n.t('Verify'),
                class: 'col-2',
                variant: rootPasswordIsInvalid ? 'outline-danger' : 'outline-primary',
                disabled: root_pass.length === 0
              },
              listeners: {
                click: () => {
                  return store.dispatch('$_bases/testDatabase', { username: 'root', password: root_pass }).then(() => {
                    Vue.set(meta.database, 'rootPasswordIsValid', true)
                    store.dispatch('$_bases/testDatabase', { username: 'root', database: db || 'pf' }).then(() => {
                      Vue.set(this.meta.database, 'databaseExists', true) // database exists
                    })
                  }).catch(() => {
                    Vue.set(meta.database, 'rootPasswordIsInvalid', true)
                  })
                }
              }
            },
            {
              component: pfFormHtml,
              attrs: {
                html: rootPasswordIsInvalid ? '<div class="small text-danger p-2">' + i18n.t('Wrong password') + '</div>' : ''
              }
            }
          ]
        },
        /**
         * Database name
         */
        {
          label: i18n.t('Database name'),
          text: i18n.t('Name of the MySQL database used by PacketFence.'),
          cols: [
            {
              namespace: 'database.db',
              component: pfFormInput,
              attrs: {
                stateMap: { false: false, true: databaseExists ? true : null },
                disabled: databaseExists
              }
            }
          ]
        },
        {
          if: !databaseExists,
          label: true, // trick to keep bottom margin in pfConfigView
          cols: [
            {
              component: pfButton,
              attrs: {
                label: i18n.t('Create'),
                class: 'col-2',
                variant: 'outline-primary',
                disabled: !rootPasswordIsValid
              },
              listeners: {
                click: () => {
                  return createDatabase()
                }
              }
            },
            {
              component: pfFormHtml,
              attrs: {
                html: databaseCreationError ? '<div class="small text-danger p-2">' + databaseCreationError + '</div>' : ''
              }
            }
          ]
        },
        /**
         * Username and password
         */
        {
          label: i18n.t('User'),
          text: i18n.t('Username of the account with access to the MySQL database used by PacketFence.'),
          cols: [
            {
              namespace: 'database.user',
              component: pfFormInput,
              attrs: {
                disabled: userIsValid,
                class: 'col-6 pr-1',
                stateMap: { false: false, true: userIsValid ? true : null }
              }
            },
            {
              namespace: 'database.pass',
              component: pfFormPassword,
              attrs: {
                disabled: userIsValid,
                class: 'col-6 pl-1',
                stateMap: { false: false, true: userIsValid ? true : null },
                // test: () => {
                //   return store.dispatch('$_bases/testDatabase', { username: user, password: pass, database: db })
                // }
              }
            }
          ]
        },
        {
          if: !userIsValid,
          label: true, // trick to keep bottom margin in pfConfigView
          cols: [
            {
              component: pfButton,
              attrs: {
                label: i18n.t('Create'),
                class: 'col-2',
                variant: 'outline-primary',
                disabled: !rootPasswordIsValid
              },
              listeners: {
                click: () => {
                  return assignDatabase()
                }
              }
            },
            {
              component: pfFormHtml,
              attrs: {
                html: userCreationError ? '<div class="small text-danger p-2">' + userCreationError + '</div>' : ''
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  const {
    database: {
      setUserPassword = false,
      rootPasswordIsRequired = false,
      databaseExists = false,
      userIsValid = false
    } = {}
  } = meta
  return {
    database: {
      // host: validatorsFromMeta(meta, 'database.host', i18n.t('Host')),
      // port: validatorsFromMeta(meta, 'database.port', i18n.t('Port')),
      db: {
        [i18n.t('Database name required.')]: required
      },
      user: {
        [i18n.t('Database username required.')]: or(conditional(setUserPassword === false), required)
      },
      pass: {
        [i18n.t('Database password required.')]: or(conditional(setUserPassword === false), required)
      },
      root_pass: {
        [i18n.t('Root password required.')]: or(conditional(!rootPasswordIsRequired), required)
      },
      database_exists: {
        [i18n.t('Create the database.')]: conditional(databaseExists)
      },
      user_is_valid: {
        [i18n.t('Create the database user.')]: conditional(userIsValid)
      }
    }
  }
}
