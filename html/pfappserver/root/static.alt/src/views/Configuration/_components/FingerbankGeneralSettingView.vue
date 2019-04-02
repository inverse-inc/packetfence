<template>
  <pf-config-view
    :isLoading="isLoading"
    :disabled="isLoading"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    @validations="formValidations = $event"
    @save="save"
  >
    <template slot="header" is="b-card-header">
      <h4 class="mb-0">
        <span>{{ $t('Account information on api.fingerbank.org') }}</span>
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-primary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import {
  pfConfigurationFingerbankGeneralSettingsViewFields as fields
} from '@/globals/configuration/pfConfigurationFingerbank'

const { validationMixin } = require('vuelidate')

export default {
  name: 'FingerbankGeneralSettingView',
  mixins: [
    validationMixin
  ],
  components: {
    pfConfigView,
    pfButtonSave
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      form: {}, // will be overloaded with the data from the store
      formValidations: {}, // will be overloaded with data from the pfConfigView
      options: {}
    }
  },
  validations () {
    return {
      form: this.formValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isGeneralSettingsLoading`]
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters[`${this.storeName}/isGeneralSettingsWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/optionsGeneralSettings`).then(options => {
        // store options
        this.options = JSON.parse(JSON.stringify(options))
        this.$store.dispatch(`${this.storeName}/getGeneralSettings`).then(data => {
          this.form = JSON.parse(JSON.stringify(data))
        })
      })
    },
    save () {
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      this.$store.dispatch(`${this.storeName}/setGeneralSettings`, form).then(response => {
        // TODO - notification
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
