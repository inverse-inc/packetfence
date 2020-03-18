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
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/database'

export default {
  name: 'database-view',
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
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsDatabase').then(({ meta }) => {
        this.$store.dispatch(`${this.formStoreName}/appendMeta`, { database: { properties: meta } })
        this.$store.dispatch(`${this.formStoreName}/appendFormValidations`, validators)
      })
      this.$store.dispatch('$_bases/getDatabase').then(form => {
        this.$store.dispatch(`${this.formStoreName}/appendForm`, { database: form })
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
