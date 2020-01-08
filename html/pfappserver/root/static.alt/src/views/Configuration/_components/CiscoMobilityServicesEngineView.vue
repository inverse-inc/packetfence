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
        <span>{{ $t('Cisco Mobility Services Engine') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import {
  view,
  validators
} from '../_config/ciscoMobilityServicesEngine'

export default {
  name: 'cisco-mobility-services-engine-view',
  components: {
    pfConfigView,
    pfButtonSave
  },
  props: {
    formStoreName: { // from router
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
      return view(this.form, this.meta) // ../_config/ciscoMobilityServicesEngine
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_bases/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsMseTab').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
      })
      this.$store.dispatch('$_bases/getMseTab').then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    save () {
      this.$store.dispatch('$_bases/updateMseTab', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
