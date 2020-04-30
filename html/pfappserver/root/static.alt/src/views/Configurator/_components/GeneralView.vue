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
        <span>{{ $t('General') }}</span>
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/general'

export default {
  name: 'general-view',
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
      return view(this.form, this.meta) // ../_config/general
    },
    isLoading () {
      return this.$store.getters['$_bases/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsGeneral').then(({ meta }) => {
        this.$store.dispatch(`${this.formStoreName}/appendMeta`, { general: { properties: meta } })
      })
      this.$store.dispatch('$_bases/getGeneral').then(form => {
        this.$store.dispatch(`${this.formStoreName}/appendForm`, { general: form })
      })
      this.$store.dispatch('services/getService', 'tracking-config')
      this.$store.dispatch(`${this.formStoreName}/appendFormValidations`, validators)
    },
    save () {
      const { general: { timezone } } = this.form
      return this.$store.dispatch('$_bases/getGeneral').then(({ timezone: initialTimezone }) => {
        let restartMariaDB = (initialTimezone !== timezone)
        return this.$store.dispatch('$_bases/updateGeneral', Object.assign({ quiet: true }, this.form.general)).then(() => {
          if (restartMariaDB) {
            return this.$store.dispatch('services/restartSystemService', { id: 'packetfence-mariadb', quiet: true })
          }
        }).catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          this.$store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: this.$i18n.t('An error occured while updating the general configuration.')
          })
          throw error
        })
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
