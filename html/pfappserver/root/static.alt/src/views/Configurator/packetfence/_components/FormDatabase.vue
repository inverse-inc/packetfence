<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Database'"/>
    </b-card-header>
    <b-form>
      <base-form
        :form="form"
        :schema="schema"
        :isLoading="isLoading"
        :readonly="disabled"
      >
        <form-group-automatic-configuration v-if="rootPasswordIsRequired && setRootPassword && !rootPasswordIsValid && (!databaseExists || !userIsValid)"
          v-model="automaticConfiguration"
          :column-label="$i18n.t('Automatic Configuration')"
          :text="$i18n.t('A password will be assigned to the root account of MySQL, the database and a &quot;pf&quot; user will be created.')"
        />

        <!--
          Automatic Configuration
          -->
        <template v-if="automaticConfiguration"></template>

        <!--
          Manual Configuration
          -->
        <template v-if="!automaticConfiguration">

<!--
          <base-form-group-input-password-test namespace="root_pass"
            :column-label="$i18n.t('Automatic Configuration')"
            :text="$i18n.t('A password will be assigned to the root account of MySQL, the database and a &quot;pf&quot; user will be created.')"
          />
-->
          <!--
            root password is empty
            -->
          <template v-if="rootPasswordIsRequired">

            <!--
              root password is needed
              -->
            <template v-if="setRootPassword">

              <base-form-group-input-password-test namespace="root_pass"
                :column-label="$i18n.t('Root Password')"
                :text="$i18n.t('Define a root password for the MySQL server.')"
                :readonly="rootPasswordIsValid"
                :test="onSetRootPassword"
                :button-label="$i18n.t('Set Password')"
              />

              <!--
                root password is valid
                -->
              <template v-if="rootPasswordIsValid">
                <base-form-group class="mb-3">
                  <b-button variant="outline-primary" class="col-sm-7 col-lg-5 col-xl-4"
                    @click="onCopyRootPassword">{{ $t('Copy to Clipboard') }}</b-button>
                </base-form-group>
              </template>

            </template>

            <!--
              root password is defined
              -->
            <template v-else-if="!setRootPassword">
              <base-form-group-input-password namespace="root_pass"
                :column-label="$i18n.t('Root Password')"
                :text="$i18n.t('Current root password of the MySQL server.')"
                :readonly="rootPasswordIsValid"
                :valid-feedback="(rootPasswordIsValid) ? $i18n.t('MySQL root password is valid.') : undefined"
              />
            </template>

            <template v-if="!(setRootPassword || rootPasswordIsValid)">
              <base-form-group class="mb-3"
                :class="{
                  'is-invalid': rootPasswordIsUnverified
                }"
              >
                <b-button class="col-sm-7 col-lg-5 col-xl-4"
                  :disabled="form.root_pass.length === 0"
                  :variant="(rootPasswordIsUnverified) ? 'outline-danger' : 'outline-primary'"
                  @click="onVerifyRootPassword">{{ $t('Verify') }}</b-button>

                <div v-if="rootPasswordIsUnverified"
                  class="d-block invalid-feedback p-2">{{ $i18n.t('Incorrect MySQL root password.') }}</div>
              </base-form-group>
            </template>

          </template>

          <!--
            database name
            -->
          <base-form-group-input namespace="db"
            :column-label="$i18n.t('Database name')"
            :text="$i18n.t('Name of the MySQL database used by PacketFence.')"
            :disabled="databaseExists"
            :valid-feedback="(databaseExists) ? $i18n.t('MySQL database exists.') : undefined"
          />

          <template v-if="!databaseExists">
            <base-form-group class="mb-3"
                :class="{
                  'is-invalid': databaseCreationError
                }"
              >
              <b-button class="col-sm-7 col-lg-5 col-xl-4"
                :disabled="!rootPasswordIsValid"
                :variant="(databaseCreationError) ? 'outline-danger' : 'outline-primary'"
                @click="onCreateDatabase">{{ $t('Create') }}</b-button>

              <div v-if="databaseCreationError"
                class="d-block invalid-feedback p-2">{{ databaseCreationError }}</div>
            </base-form-group>
          </template>

          <!--
            username and password
            -->
          <base-form-group
            :column-label="$i18n.t('User')"
            :text="$i18n.t('Username of the account with access to the MySQL database used by PacketFence.')"
          >
            <base-input namespace="user"
              class="px-0 pr-lg-1 col-lg-6"
              :disabled="userIsValid"
              :valid-feedback="(userIsValid) ? $i18n.t('MySQL user exists.') : undefined"
            />
            <base-input-group-password namespace="pass"
              class="px-0 pl-lg-1 col-lg-6"
              :disabled="userIsValid"
              :valid-feedback="(userIsValid) ? $i18n.t('MySQL password is valid.') : undefined"
            />
          </base-form-group>

          <template v-if="!userIsValid">
            <base-form-group class="mb-3"
                :class="{
                  'is-invalid': userCreationError
                }"
              >
              <b-button class="col-sm-7 col-lg-5 col-xl-4"
                :disabled="!rootPasswordIsValid"
                :variant="(userCreationError) ? 'outline-danger' : 'outline-primary'"
                @click="onCreateUser">{{ $t('Create') }}</b-button>

              <div v-if="userCreationError"
                class="d-block invalid-feedback p-2">{{ userCreationError }}</div>
            </base-form-group>
          </template>

        </template>

      </base-form>
    </b-form>
  </b-card>
</template>
<script>
const DEFAULT_DATABASE = 'pf' // default database is "pf"
const DEFAULT_USERNAME = 'pf' // default username is "pf"

import {
  BaseForm,
  BaseFormGroup,
  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseFormGroupInputPasswordTest,
  BaseFormGroupToggleFalseTrue,
  BaseInput,
  BaseInputGroupPassword
} from '@/components/new/'

const components = {
  BaseForm,
  BaseFormGroup,
  FormGroupAutomaticConfiguration:  BaseFormGroupToggleFalseTrue,

  BaseFormGroupInput,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseFormGroupInputPasswordTest,
  BaseInput,
  BaseInputGroupPassword
}

const props = {
  disabled: {
    type: Boolean
  }
}

import { computed, inject, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import password from '@/utils/password'
import yup from '@/utils/yup'

const schema = yup.object({
  db: yup.string().nullable().required(i18n.t('MySQL database name required.')),
  root_pass: yup.string().nullable().required(i18n.t('MySQL root password required.')),
  user: yup.string().nullable().required(i18n.t('MySQL username required.')),
  pass: yup.string().nullable().required(i18n.t('MySQL password required.'))
})

const passwordOptions = {
  pwlength: 16,
  upper: true,
  lower: true,
  digits: true,
  special: false,
  brackets: true,
  high: false,
  ambiguous: true
}

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const state = inject('state') // Configurator
  const form = ref({ db: '', user: '', pass: '', root_pass: '' })

  const isLoading = computed(() => $store.getters['$_bases/isLoading'])

  // Make sure the database server is running
  $store.dispatch('services/startSystemService', { id: 'packetfence-mariadb', quiet: true }).then(() => {
    // Fetch configuration
    $store.dispatch('$_bases/getDatabase').then(_form => {
      form.value = _form
      initialValidation()
    })
  })

  const automaticConfiguration = ref(false)
  const databaseCreationError = ref(null)
  const databaseExists = ref(false)
  const rootPasswordIsRequired = ref(false)
  const rootPasswordIsValid = ref(false)
  const rootPasswordIsUnverified = ref(false)
  const setUserPassword = ref(false)
  const setRootPassword = ref(false)
  const userCreationError = ref(null)
  const userIsValid = ref(false)

  const initialValidation = () => {
    const { db, user } = form.value || {}
    // Check if root has no password
    if (!db)
      form.value.db = DEFAULT_DATABASE
    if (!user)
      form.value.user = DEFAULT_USERNAME
    $store.dispatch('$_bases/testDatabase', { username: 'root' }).then(() => {
      setRootPassword.value = true // root has no password -- installation is insecure
      automaticConfiguration.value = true // enable automatic configuration
      $store.dispatch('$_bases/testDatabase', { username: 'root', database: form.value.db }).then(() => {
        databaseExists.value = true // database exists
      })
    }).catch(() => {
      // noop
    }).finally(() => {
      // Check if user credentials are valid
      $store.dispatch('$_bases/testDatabase', { username: form.value.user, password: form.value.pass, database: form.value.db }).then(() => {
        databaseExists.value = true
        userIsValid.value = true
        rootPasswordIsRequired.value = false // we no longer need the root password
        automaticConfiguration.value = false // disable automatic configuration
      }).catch(() => {
        setUserPassword.value = true // credentials don't work, user probably doesn't exist
      })
    })
  }

  const configureAutomatically = () => {
    // Force default database and username
    form.value.db = DEFAULT_DATABASE
    form.value.user = DEFAULT_USERNAME
    // Assign a generated password for root
    form.value.root_pass = password.generate(passwordOptions)
    return secureDatabase().then(() => {
      const databaseReady = new Promise((resolve, reject) => {
        $store.dispatch('$_bases/testDatabase', { username: 'root', password: form.value.root_pass, database: form.value.db }).then(() => {
          databaseExists.value = true // database exists
          resolve()
        }).catch(() => {
          // Create database
          createDatabase().then(resolve, reject)
        })
      })
      return databaseReady.then(() => {
        // Check if database name and credentials are valid
        const userReady = new Promise((resolve, reject) => {
          if (form.value.pass) {
            reject()
          } else {
            $store.dispatch('$_bases/testDatabase', { username: form.value.user, password: form.value.pass, database: form.value.db }).then(() => {
              databaseExists.value = true
              userIsValid.value = true
              resolve()
            }).catch(reject)
          }
        })
        return userReady.catch(() => {
          // Assign a generated password for database user
          form.value.pass = password.generate(passwordOptions)
          return assignDatabase()
        })
      })
    })
  }

  const secureDatabase = () => {
    return $store.dispatch('$_bases/secureDatabase', { username: 'root', password: form.value.root_pass }).then(() => {
      rootPasswordIsValid.value = true
    })
  }

  const createDatabase = () => {
    return $store.dispatch('$_bases/createDatabase', {
      username: 'root',
      password: form.value.root_pass,
      database: form.value.db
    }).then(() => {
      databaseExists.value = true
    }).catch(err => {
      const {
        response: {
          data: {
            message = false
          } = {}
        } = {}
      } = err
      databaseCreationError.value = message
      throw err
    })
  }

  const assignDatabase = () => {
    return $store.dispatch('$_bases/assignDatabase', {
      root_username: 'root',
      root_password: form.value.root_pass,
      pf_username: form.value.user,
      pf_password: form.value.pass,
      database: form.value.db
    }).then(() => {
      userIsValid.value = true
    }).catch(err => {
      const {
        response: {
          data: {
            message = false
          } = {}
        } = {}
      } = err
      userCreationError.value = message
      throw err
    })
  }

  const onSave = () => {
    if (automaticConfiguration.value) {
      return configureAutomatically()
        .then(() => state.value.database = form.value)
        .catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          $store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: i18n.t('An error occured while configuring the database. Please proceed manually.')
          })
          automaticConfiguration.value = false
          throw error
        })
    }
    else {
      return $store.dispatch('$_bases/updateDatabase', Object.assign({ quiet: true }, form.value))
        .then(() => state.value.database = form.value)
        .catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          $store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: i18n.t('An error occured while updating the database configuration.')
          })
          throw error
        })
    }
  }

  const onCopyRootPassword = () => {
    try {
      navigator.clipboard.writeText(form.value.root_pass).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Password copied to clipboard') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy password to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }

  const onVerifyRootPassword = () => {
    return $store.dispatch('$_bases/testDatabase', { username: 'root', password: form.value.root_pass }).then(() => {
      rootPasswordIsValid.value = true
      $store.dispatch('$_bases/testDatabase', { username: 'root', database: form.value.db || DEFAULT_DATABASE }).then(() => {
        databaseExists.value = true // database exists
      })
    }).catch(() => {
      rootPasswordIsUnverified.value = true
    })
  }

  return {
    form,
    schema,
    isLoading,
    onSave,

    automaticConfiguration,
    databaseCreationError,
    databaseExists,
    rootPasswordIsRequired,
    rootPasswordIsValid,
    rootPasswordIsUnverified,
    setUserPassword,
    setRootPassword,
    userCreationError,
    userIsValid,

    onCopyRootPassword,
    onSetRootPassword: secureDatabase,
    onVerifyRootPassword,
    onCreateDatabase: createDatabase,
    onCreateUser: assignDatabase
  }
}

// @vue/component
export default {
  name: 'form-database',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
