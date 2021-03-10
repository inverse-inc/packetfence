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
        <span>{{ $t('Alerting') }}</span>
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
} from '../_config/alerting'

export default {
  name: 'alerting-view',
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
      return view(this.form, this.meta) // ../_config/alerting
    },
    isLoading () {
      return this.$store.getters['$_bases/isLoading']
    },
    advancedMode: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { alerting: { advancedMode = false } = {} } = {} } = this
        return advancedMode
      },
      set (newValue) {
        this.$set(this.meta.alerting, 'advancedMode', newValue)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsAlerting').then(({ meta }) => {
        this.$store.dispatch(`${this.formStoreName}/appendMeta`, { alerting: { properties: meta } })
      })
      this.$store.dispatch('$_bases/getAlerting').then(form => {
        form.test_emailaddr = form.emailaddr // copy recipients into SMTP test
        this.$store.dispatch(`${this.formStoreName}/appendForm`, { alerting: form })
      })
      this.$store.dispatch(`${this.formStoreName}/appendFormValidations`, validators)
    },
    save () {
      return this.$store.dispatch('$_bases/updateAlerting', Object.assign({ quiet: true }, this.form.alerting)).catch(error => {
        // Only show a notification in case of a failure
        const { response: { data: { message = '' } = {} } = {} } = error
        this.$store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          url: message,
          message: this.$i18n.t('An error occured while updating the alerting configuration.')
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
