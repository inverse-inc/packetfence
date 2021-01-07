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
        <span>{{ $t('Administrator') }}</span>
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/administrator'

export default {
  name: 'administrator-view',
  components: {
    pfConfigView
  },
  props: {
    formStoreName: {
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      userExists: false
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
      return view(this.form, this.meta) // ../_config/administrator
    },
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_users/getUser', { pid: 'admin', quiet: true }).then(form => {
        this.userExists = true
        this.$store.dispatch(`${this.formStoreName}/appendForm`, { administrator: form })
      }).catch(() => {
        // User doesn't exist or database is not accessible
        this.$store.dispatch(`${this.formStoreName}/appendForm`, { administrator: { pid: 'admin' } })
      }).finally(() => {
        this.$store.dispatch(`${this.formStoreName}/appendFormValidations`, validators)
      })
    },
    save () {
      let savePromise = new Promise((resolve, reject) => {
        this.form.administrator.valid_from = "1970-01-01 00:00:00"
        if (this.userExists) {
          this.$store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, this.form.administrator)).then(resolve, reject)
        } else {
          this.$store.dispatch('$_users/getUser', { pid: 'admin', quiet: true }).then(() => {
            // User exists
            this.userExists = true
            this.$store.dispatch('$_users/updatePassword', Object.assign({ quiet: true }, this.form.administrator)).then(resolve, reject)
          }).catch(() => {
            // User doesn't exist
            this.$store.dispatch('$_users/createUser', this.form.administrator).then(() => {
              this.$store.dispatch('$_users/createPassword', Object.assign({ quiet: true }, this.form.administrator)).then(resolve, reject)
            }).catch(reject)
          })
        }
      })
      return savePromise.catch(error => {
        // Only show a notification in case of a failure
        const { response: { data: { message = '' } = {} } = {} } = error
        this.$store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          url: message,
          message: this.$i18n.t('An error occured while setting the administrator password.')
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
