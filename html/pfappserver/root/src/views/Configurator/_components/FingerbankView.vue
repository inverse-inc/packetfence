<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :is-loading="isLoading"
    :disabled="isLoading"
    :view="view"
  >
    <template v-slot:header>
      <h4 class="mb-0">
        <span>{{ $t('Fingerbank') }}</span>
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/fingerbank'

export default {
  name: 'fingerbank-view',
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
      return this.$store.getters['$_fingerbank/isGeneralSettingsLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_fingerbank/optionsGeneralSettings').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
        this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
        this.$store.dispatch('$_fingerbank/getGeneralSettings').then(form => {
          const {
            upstream: {
              api_key = null
            }
          } = form
          this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          if (api_key) {
            this.$store.dispatch('$_fingerbank/getAccountInfo').then(account => {
              this.$store.dispatch(`${this.formStoreName}/appendMeta`, { account })
            })
          }
        })
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
