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
        <div class="float-right">
          <pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle>
        </div>
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfFormToggle from '@/components/pfFormToggle'
import {
  view,
  validators
} from '../_config/database'

export default {
  name: 'database-view',
  components: {
    pfConfigView,
    pfFormToggle
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
    advancedMode: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { database: { advancedMode = false } = {} } = {} } = this
        return advancedMode
      },
      set (newValue) {
        this.$set(this.meta.database, 'advancedMode', newValue)
      }
    // },
    // hostState () {
    //   return this.$store.getters[`${this.formStoreName}/$stateNS`]('database.host')
    // },
    // portState () {
    //   return this.$store.getters[`${this.formStoreName}/$stateNS`]('database.port')
    }

  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsDatabase').then(({ meta }) => {
        this.$store.dispatch(`${this.formStoreName}/appendMeta`, { database: { properties: meta } })
        this.$store.dispatch(`${this.formStoreName}/appendFormValidations`, validators)
        // Fetch configuration
        this.$store.dispatch('$_bases/getDatabase').then(form => {
          this.$store.dispatch(`${this.formStoreName}/appendForm`, { database: form })
          this.initialValidation()
          // TODO: if host or port is changed, call this.save and this.initialValidation
          // this.$watch('hostState')
          // this.$watch('portState')
        })
      })
    },
    initialValidation () {
      const form = this.form.database
      // Check if root has no password
      this.$store.dispatch('$_bases/testDatabase', { username: 'root' }).then(() => {
        this.$set(this.meta.database, 'setRootPassword', true) // need to define a root password
        this.$store.dispatch('$_bases/testDatabase', { username: 'root', database: form.db || 'pf' }).then(() => {
          this.$set(this.meta.database, 'databaseExists', true) // database exists
        })
      }).catch(() => {})
      // Check if database name and credentials are valid
      this.$store.dispatch('$_bases/testDatabase', { username: form.user || 'pf', password: form.pass, database: form.db || 'pf' }).then(() => {
        this.$set(this.meta.database, 'databaseExists', true)
        this.$set(this.meta.database, 'userIsValid', true)
        this.$set(this.meta.database, 'rootPasswordIsRequired', false) // we no longer need the root password
      }).catch(() => {
        this.$set(this.meta.database, 'setUserPassword', true) // credentials don't work, user probably doesn't exist
      })
    },
    save () {
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
  },
  created () {
    this.init()
  }
}
</script>
