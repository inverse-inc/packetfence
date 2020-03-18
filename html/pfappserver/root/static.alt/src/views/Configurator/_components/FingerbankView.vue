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
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_fingerbank/isGeneralSettingsLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_fingerbank/getAccountInfo').then(info => {
        this.accountInfo = info
      })
    //   this.$store.dispatch('$_fingerbank/optionsGeneralSettings').then(options => {
    //     this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
    //   })
      this.$store.dispatch('$_fingerbank/getGeneralSettings').then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    save () {
      return this.$store.dispatch('$_fingerbank/setGeneralSettings', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
