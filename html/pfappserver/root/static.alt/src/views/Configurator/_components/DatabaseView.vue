<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :view="view"
    @save="save"
  >
    <template v-slot:header>
      <h4 class="mb-0">
        <span>{{ $t('Database') }}</span>
        <!-- <div class="float-right">
          <pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle>
        </div> -->
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
// import { createDebouncer } from 'promised-debounce'
import password from '@/utils/password'
import pfConfigView from '@/components/pfConfigView'
// import pfFormToggle from '@/components/pfFormToggle'
import {
  view,
  validators
} from '../_config/database'

export default {
  name: 'database-view',
  components: {
    pfConfigView
    // pfFormToggle
  },
  data () {
    return {
      $debouncer: null,
      passwordOptions: {
        pwlength: 16,
        upper: true,
        lower: true,
        digits: true,
        special: false,
        brackets: true,
        high: false,
        ambiguous: true
      }
    }
  },
  props: {
    formStoreName: {
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/database
    },
    isLoading () {
      return this.$store.getters['$_bases/isLoading']
    },
    automaticConfiguration () {
      return this.$store.getters[`${this.formStoreName}/$formNS`]('automaticDatabaseConfiguration')
    }
    // advancedMode: { // mutating this property will re-evaluate view() and validators()
    //   get () {
    //     const { meta: { database: { advancedMode = false } = {} } = {} } = this
    //     return advancedMode
    //   },
    //   set (newValue) {
    //     this.$set(this.meta.database, 'advancedMode', newValue)
    //   }
    // }
  },
  methods: {
    init () {
      const metaMethods = {
        secureDatabase: this.secureDatabase,
        createDatabase: this.createDatabase,
        assignDatabase: this.assignDatabase
      }
      this.$set(this.form, 'automaticDatabaseConfiguration', '0')
      this.$store.dispatch(`${this.formStoreName}/appendMeta`, { database: metaMethods }) // initialize meta for database
      this.$store.dispatch(`${this.formStoreName}/appendFormValidations`, validators)
      // Make sure the database server is running
      this.$store.dispatch('services/startSystemService', { id: 'packetfence-mariadb', quiet: true }).then(() => {
        // Fetch configuration
        this.$store.dispatch('$_bases/getDatabase').then(form => {
          this.$store.dispatch(`${this.formStoreName}/appendForm`, { database: form })
          this.initialValidation()
        })
      })
    },
    initialValidation () {
      const form = this.form.database
      // Check if root has no password
      if (!form.db) {
        this.$set(this.form.database, 'db', 'pf') // default database is "pf"
      }
      if (!form.user) {
        this.$set(this.form.database, 'user', 'pf') // default username is "pf"
      }
      this.$store.dispatch('$_bases/testDatabase', { username: 'root' }).then(() => {
        this.$set(this.meta.database, 'setRootPassword', true) // root has no password -- installation is insecure
        this.$set(this.form, 'automaticDatabaseConfiguration', '1') // enable automatic configuration
        this.$store.dispatch('$_bases/testDatabase', { username: 'root', database: form.db || 'pf' }).then(() => {
          this.$set(this.meta.database, 'databaseExists', true) // database exists
        })
      }).catch(() => {
        // noop
      }).finally(() => {
        // Check if user credentials are valid
        this.$store.dispatch('$_bases/testDatabase', { username: form.user, password: form.pass, database: form.db }).then(() => {
          this.$set(this.meta.database, 'databaseExists', true)
          this.$set(this.meta.database, 'userIsValid', true)
          this.$set(this.meta.database, 'rootPasswordIsRequired', false) // we no longer need the root password
          this.$set(this.form, 'automaticDatabaseConfiguration', '0') // disable automatic configuration
        }).catch(() => {
          this.$set(this.meta.database, 'setUserPassword', true) // credentials don't work, user probably doesn't exist
        })
      })
    },
    configureAutomatically () {
      const form = this.form.database
      // Force default database and username
      this.$set(this.form.database, 'db', 'pf')
      this.$set(this.form.database, 'user', 'pf')
      // Assign a generated password for root
      this.$set(this.form.database, 'root_pass', password.generate(this.passwordOptions))
      return this.secureDatabase().then(() => {
        const databaseReady = new Promise((resolve, reject) => {
          this.$store.dispatch('$_bases/testDatabase', { username: 'root', password: form.root_pass, database: form.db }).then(() => {
            this.$set(this.meta.database, 'databaseExists', true) // database exists
            resolve()
          }).catch(() => {
            // Create database
            this.createDatabase().then(resolve, reject)
          })
        })
        return databaseReady.then(() => {
          // Check if database name and credentials are valid
          const userReady = new Promise((resolve, reject) => {
            if (form.pass) {
              reject()
            } else {
              this.$store.dispatch('$_bases/testDatabase', { username: form.user, password: form.pass, database: form.db }).then(() => {
                this.$set(this.meta.database, 'databaseExists', true)
                this.$set(this.meta.database, 'userIsValid', true)
                resolve()
              }).catch(reject)
            }
          })
          return userReady.catch(() => {
            // Assign a generated password for database user
            this.$set(this.form.database, 'pass', password.generate(this.passwordOptions))
            return this.assignDatabase()
          })
        })
      })
    },
    secureDatabase () {
      const form = this.form.database
      return this.$store.dispatch('$_bases/secureDatabase', { username: 'root', password: form.root_pass }).then(() => {
        this.$set(this.meta.database, 'rootPasswordIsValid', true)
      })
    },
    createDatabase () {
      return this.$store.dispatch('$_bases/createDatabase', {
        username: 'root',
        password: this.form.database.root_pass,
        database: this.form.database.db
      }).then(() => {
        this.$set(this.meta.database, 'databaseExists', true)
      }).catch(err => {
        const {
          response: {
            data: {
              message = false
            } = {}
          } = {}
        } = err
        this.$set(this.meta.database, 'databaseCreationError', message)
        throw err
      })
    },
    assignDatabase () {
      return this.$store.dispatch('$_bases/assignDatabase', {
        root_username: 'root',
        root_password: this.form.database.root_pass,
        pf_username: this.form.database.user,
        pf_password: this.form.database.pass,
        database: this.form.database.db
      }).then(() => {
        this.$set(this.meta.database, 'userIsValid', true)
      }).catch(err => {
        const {
          response: {
            data: {
              message = false
            } = {}
          } = {}
        } = err
        this.$set(this.meta.database, 'userCreationError', message)
        throw err
      })
    },
    save () {
      if (parseInt(this.automaticConfiguration)) {
        return this.configureAutomatically().catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while configuring the database. Please proceed manually.')
          })
          this.$set(this.form, 'automaticDatabaseConfiguration', false)
          throw error
        })
      } else {
        return this.$store.dispatch('$_bases/updateDatabase', Object.assign({ quiet: true }, this.form.database)).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the database configuration.')
          })
          throw error
        })
      }
    }
  },
  created () {
    this.init()
  }
  /*watch: {
    'form.database.host': {
      handler: function (a, b) {
        if (a || b) {
          if (!this.$debouncer) {
            this.$debouncer = createDebouncer()
          }
          this.$debouncer({
            handler: () => {
              this.save().then(() => {
                this.initialValidation()
              })
            },
            time: 2000 // 2 seconds
          })
        }
      }
    },
    'form.database.port': {
      handler: function (a, b) {
        if (a || b) {
          if (!this.$debouncer) {
            this.$debouncer = createDebouncer()
          }
          this.$debouncer({
            handler: () => {
              this.save().then(() => {
                this.initialValidation()
              })
            },
            time: 2000 // 2 seconds
          })
        }
      }
    }
  }*/
}
</script>
