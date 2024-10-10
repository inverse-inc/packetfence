<template>
  <b-card no-body data-form="database">
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Database'"/>
    </b-card-header>
    <b-form>
      <b-container v-if="isStarting || isLoading"
        class="d-flex align-items-center justify-content-md-center">
        <b-row class="py-5 justify-content-md-center text-secondary">
          <b-col cols="12" md="auto">
            <b-media>
              <template v-slot:aside><icon name="circle-notch" scale="2" spin class="is-invalid"/></template>
              <h4 v-if="isStarting">{{ $i18n.t('Starting MySQL service') }}</h4>
              <h4 v-else>{{ $i18n.t('Probing MySQL configuration') }}</h4>
              <p class="font-weight-light" v-t="'Please wait...'"/>
            </b-media>
          </b-col>
        </b-row>
      </b-container>
      <base-form v-else
        :form="form"
        :schema="schema"
        :isLoading="isLoading"
        :readonly="disabled"
      >
        <form-group-automatic-configuration
          v-model="remoteDatabase"
          :column-label="$i18n.t('Remote Database')"
          :text="$i18n.t('Use a remote MySQL compatible database.')"
        />


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
                :valid-feedback="$i18n.t('MySQL root password set.')"
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
                <base-button-save class="col-sm-7 col-lg-5 col-xl-4"
                  :disabled="!canVerifyRootPassword"
                  :isLoading="isVerifyingRootPassword"
                  :variant="(rootPasswordIsUnverified) ? 'outline-danger' : 'outline-primary'"
                  @click="onVerifyRootPassword">{{ $t('Verify') }}</base-button-save>

                <div v-if="rootPasswordIsUnverified"
                  class="d-block invalid-feedback py-2">{{ $i18n.t('Incorrect MySQL root password.') }}</div>
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
            :valid-feedback="
              ((databaseExists) ? $i18n.t('MySQL database exists. ') : '') +
              ((databaseVersion) ? $i18n.t('Current database schema is version {databaseVersion}. ', {databaseVersion}) : '')
            "
          />

          <template v-if="!databaseExists">
            <base-form-group class="mb-3"
                :class="{
                  'is-invalid': databaseCreationError
                }"
              >
              <base-button-save class="col-sm-7 col-lg-5 col-xl-4"
                :isLoading="isCreatingDatabase"
                :disabled="!rootPasswordIsValid"
                :variant="(databaseCreationError) ? 'outline-danger' : 'outline-primary'"
                @click="onCreateDatabase"
                type="button">{{ $t('Create') }}</base-button-save>

              <div v-if="databaseCreationError"
                class="d-block invalid-feedback py-2">{{ databaseCreationError }}</div>
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
            <base-input-group-password-generator namespace="pass"
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
              <base-button-save class="col-sm-7 col-lg-5 col-xl-4"
                :disabled="!canCreateUser"
                :isLoading="isCreatingUser"
                :variant="(userCreationError) ? 'outline-danger' : 'outline-primary'"
                @click="onCreateUser"
                type="button">{{ $t('Create') }}</base-button-save>

              <div v-if="userCreationError"
                class="d-block invalid-feedback py-2">{{ userCreationError }}</div>
            </base-form-group>
          </template>

        </template>

      </base-form>
    </b-form>

    <!--
      remote database
      -->
    <b-modal v-model="remoteDatabaseModal" size="lg" centered id="remoteDatabaseModal" hide-header-close
      :title="$t('Remote MySQL Database')"
      @cancel="remoteDatabaseCancel"
    >
      <b-alert variant="danger" v-model="remoteDatabaseTestError" fade>
        <p>{{ remoteDatabaseTestMessage }}</p>
      </b-alert>

      <base-form ref="remoteDatabaseRef"
        :form="remoteDatabaseForm"
        :schema="remoteDatabaseSchema"
        :isLoading="remoteDatabaseLoading"
        :readonly="remoteDatabaseDisabled"
      >
        <base-form-group-input namespace="username"
          :column-label="$i18n.t('Privileged user name')"
          :text="$i18n.t('This user requires SUPER priviliges.')"
          :disabled="remoteDatabaseDisabled"
        />
        <base-form-group-input-password namespace="password"
          :column-label="$i18n.t('Privileged user password')"
          :disabled="remoteDatabaseDisabled"
        />
        <base-form-group-chosen-one namespace="encryption"
          :column-label="$i18n.t('Encryption type')"
          :text="$i18n.t('Only secure connections are supported.')"
          :disabled="remoteDatabaseDisabled"
          :options="[
            { text: 'TLS', value: 'tls' }
          ]"
        />
        <base-form-group-textarea-upload namespace="ca_cert"
          :column-label="$i18n.t('CA certificate')"
          :text="$i18n.t('Click the upload icon on the right-side to choose the CA certificate from disk.')"
          :disabled="remoteDatabaseDisabled"
        />
        <base-form-group-input namespace="hostname"
          :column-label="$i18n.t('Server hostname')"
          :text="$i18n.t('FQDN or IPv4.')"
          :disabled="remoteDatabaseDisabled"
        />
        <base-form-group-input-number namespace="port"
          :column-label="$i18n.t('Server port')"
          :disabled="remoteDatabaseDisabled"
        />
      </base-form>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" @click="remoteDatabaseCancel">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="!remoteDatabaseValid" @click="remoteDatabaseTest">{{ $t('Test') }}</b-button>
      </template>
    </b-modal>
  </b-card>
</template>
<script>
const DEFAULT_DATABASE = 'pf' // default database is "pf"
const DEFAULT_USERNAME = 'pf' // default username is "pf"

import {
  BaseButtonSave,

  BaseForm,
  BaseFormGroup,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseFormGroupInputPasswordTest,
  BaseFormGroupTextareaUpload,
  BaseFormGroupToggleFalseTrue,
  BaseInput,
  BaseInputGroupPassword,
  BaseInputGroupPasswordGenerator
} from '@/components/new/'

const components = {
  BaseButtonSave,
  BaseForm,
  BaseFormGroup,
  FormGroupAutomaticConfiguration:  BaseFormGroupToggleFalseTrue,
  FormGroupRemoteDatabase:          BaseFormGroupToggleFalseTrue,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupInputPasswordGenerator,
  BaseFormGroupInputPasswordTest,
  BaseFormGroupTextareaUpload,
  BaseInput,
  BaseInputGroupPassword,
  BaseInputGroupPasswordGenerator
}

const props = {
  disabled: {
    type: Boolean
  }
}

import { computed, inject, ref, watch } from '@vue/composition-api'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import password from '@/utils/password'
import yup from '@/utils/yup'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'

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
  // form defaults from state.database
  const { database = {} } = state.value
  const form = ref({ db: '', user: '', pass: '', root_pass: '', ...database }) // form defaults
  const schema = computed(() => {
    return yup.object({
      db: yup.string().nullable()
        .required(i18n.t('MySQL database name required.'))
        .not(databaseExists.value, i18n.t('MySQL database not created.')),
      root_pass: yup.string().nullable()
        .required(i18n.t('MySQL root password required.'))
        .not((rootPasswordIsUnverified.value || rootPasswordIsValid.value), i18n.t('MySQL root password not verified.')),
      user: yup.string().nullable()
        .required(i18n.t('MySQL username required.'))
        .not(userIsValid.value, i18n.t('MySQL user not created.')),
      pass: yup.string().nullable().required(i18n.t('MySQL password required.'))
    })
  })

  const isLoading = computed(() => $store.getters['$_bases/isLoading'])

  // Make sure the database server is running
  const isStarting = ref(true)
  $store.dispatch('cluster/startSystemService', { id: 'packetfence-mariadb', quiet: true }).then(() => {
    form.value.db = DEFAULT_DATABASE
    form.value.user = DEFAULT_USERNAME
    initialValidation()
  }).finally(() => {
    isStarting.value = false
  })

  const automaticConfiguration = ref(false)
  const databaseExists = ref(false)
  const rootPasswordIsRequired = ref(true)
  const setUserPassword = ref(false)
  const setRootPassword = ref(false)
  const userIsValid = ref(false)

  const initialValidation = () => {
    const { db, user } = form.value || {}
    // Check if root has no password
    if (!db)
      form.value.db = DEFAULT_DATABASE
    if (!user)
      form.value.user = DEFAULT_USERNAME
    $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value }).then(() => {
      setRootPassword.value = true // root has no password -- installation is insecure
      automaticConfiguration.value = true // enable automatic configuration
      $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, database: form.value.db }).then(() => {
        databaseExists.value = true // database exists
      })
    }).catch(() => {
      // noop
    }).finally(() => {
      // Check if user credentials are valid
      $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, username: form.value.user, password: form.value.pass, database: form.value.db }).then(() => {
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
        $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, username: "root", password: form.value.root_pass, database: form.value.db }).then(() => {
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
            $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, username: form.value.user, password: form.value.pass, database: form.value.db }).then(() => {
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
    // secure install only localdb (remotedb disabled)
    if(!remoteDatabase.value) {
      return $store.dispatch('$_bases/secureDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, username: 'root', password: form.value.root_pass }).then(() => {
        rootPasswordIsValid.value = true
      })
    }
    // remotedb enabled
    return new Promise(r => r)
  }

  const canCreateDatabase = computed(() => {
    const { name = '' } = form.value || {}
    return rootPasswordIsValid.value && name.length > 0
  })

  const isCreatingDatabase = ref(false)
  const databaseCreationError = ref(null)
  const createDatabase = () => {
    isCreatingDatabase.value = true
    databaseCreationError.value = null
    return $store.dispatch('$_bases/createDatabase', {
      is_remote: remoteDatabase.value,
      remote: remoteDatabaseForm.value,
      username: 'root',
      password: form.value.root_pass,
      database: form.value.db
    }).then(() => {
      databaseExists.value = true
      _getSystemSummary()
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
    }).finally(() => {
      isCreatingDatabase.value = false
    })
  }

  const canCreateUser = computed(() => {
    const { user = '', pass = '' } = form.value || {}
    return rootPasswordIsValid.value
      && databaseExists.value
      && user && user.length > 0
      && pass && pass.length > 0
  })

  const isCreatingUser = ref(false)
  const userCreationError = ref(null)
  const assignDatabase = () => {
    isCreatingUser.value = true
    userCreationError.value = null
    return $store.dispatch('$_bases/assignDatabase', {
      is_remote: remoteDatabase.value,
      remote: remoteDatabaseForm.value,
      username: 'root',
      password: form.value.root_pass,
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
    }).finally(() => {
      isCreatingUser.value = false
      _getSystemSummary()
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

  const canVerifyRootPassword = computed(() => {
    const { root_pass = '' } = form.value || {}
    return root_pass.length > 0
  })

  const rootPasswordIsValid = ref(false)
  const rootPasswordIsUnverified = ref(false)
  const isVerifyingRootPassword = ref(false)
  const onVerifyRootPassword = () => {
    isVerifyingRootPassword.value = true
    return $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, password: form.value.root_pass })
      .then(() => {
        rootPasswordIsValid.value = true
        rootPasswordIsUnverified.value = false
        $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value, password: form.value.root_pass, database: form.value.db || DEFAULT_DATABASE })
          .then(() => {
            databaseExists.value = true // database exists
          })
      }).catch(() => {
        rootPasswordIsUnverified.value = true
      }).finally(() => {
        isVerifyingRootPassword.value = false
      })
  }

  const databaseVersion = ref(null)
  const _getSystemSummary = () => apiCall.getQuiet('system_summary').then(response => {
    const { data: { db_version } = {} } = response
    databaseVersion.value = db_version
  })
  _getSystemSummary()

  const remoteDatabase = ref(false)
  const remoteDatabaseModal = ref(false)
  const _remoteDatabaseForm = {
    username: 'root',
    port: 3306
  }
  const remoteDatabaseForm = ref({ ..._remoteDatabaseForm })
  const remoteDatabaseSchema = computed(() => {
    return yup.object({
      username: yup.string().nullable()
        .required(i18n.t('Privileged user name required.')),
      password: yup.string().nullable()
        .required(i18n.t('Privileged user password required.')),
      encryption: yup.string().nullable()
        .required(i18n.t('Database client encryption type required.')),
      ca_cert: yup.string().nullable(),
      hostname: yup.string().nullable()
        .required(i18n.t('Server hostname required.'))
        .isHostname(),
      port: yup.string().nullable()
        .required(i18n.t('Server port required.'))
        .isPort(),
    })
  })
  const remoteDatabaseLoading = ref(false)
  const remoteDatabaseDisabled = ref(false)
  watch(remoteDatabase, toggle => {
    remoteDatabaseForm.value.is_remote = toggle
    if (toggle) {
      remoteDatabaseModal.value = true
    }
    else {
      remoteDatabaseModal.value = false
      remoteDatabaseForm.value = { ..._remoteDatabaseForm } // reset (dereferenced)
    }
  }, { immediate: true })
  const remoteDatabaseCancel = () => {
    remoteDatabase.value = false
  }
  const remoteDatabaseTestError = ref(false)
  const remoteDatabaseTestMessage = ref('')
  const remoteDatabaseTest = () => {
    remoteDatabaseLoading.value = true
    remoteDatabaseTestError.value = false
    remoteDatabaseTestMessage.value = undefined
    $store.dispatch('$_bases/testDatabase', { is_remote: remoteDatabase.value, remote: remoteDatabaseForm.value })
      .then(() => {
        remoteDatabaseModal.value = false
      })
      .catch(error => {
        const { response: { data: { message = '' } = {} } = {} } = error
        remoteDatabaseTestError.value = true
        remoteDatabaseTestMessage.value = message
      })
      .finally(() => {
        remoteDatabaseLoading.value = false
      })
  }
  const remoteDatabaseRef = ref(null)
  const remoteDatabaseValid = useDebouncedWatchHandler([remoteDatabaseForm, remoteDatabaseModal], () => (!remoteDatabaseRef.value || remoteDatabaseRef.value.$el.querySelectorAll('.is-invalid').length === 0))

  return {
    form,
    schema,
    isLoading,
    isStarting,
    onSave,

    automaticConfiguration,
    databaseExists,
    rootPasswordIsRequired,
    rootPasswordIsValid,
    rootPasswordIsUnverified,
    setUserPassword,
    setRootPassword,
    userIsValid,

    onCopyRootPassword,
    onSetRootPassword: secureDatabase,

    canVerifyRootPassword,
    onVerifyRootPassword,
    isVerifyingRootPassword,

    canCreateDatabase,
    onCreateDatabase: createDatabase,
    isCreatingDatabase,
    databaseCreationError,
    databaseVersion,

    canCreateUser,
    onCreateUser: assignDatabase,
    isCreatingUser,
    userCreationError,

    remoteDatabase,
    remoteDatabaseModal,
    remoteDatabaseForm,
    remoteDatabaseSchema,
    remoteDatabaseLoading,
    remoteDatabaseDisabled,
    remoteDatabaseCancel,
    remoteDatabaseTest,
    remoteDatabaseTestError,
    remoteDatabaseTestMessage,
    remoteDatabaseRef,
    remoteDatabaseValid,

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
