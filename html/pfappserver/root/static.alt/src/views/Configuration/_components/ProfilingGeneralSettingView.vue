<template>
  <pf-config-view
    :isLoading="isLoading"
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
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import {
  pfConfigurationProfilingGeneralSettingsViewFields as fields,
  pfConfigurationProfilingGeneralSettingsViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationProfiling'
const { validationMixin } = require('vuelidate')

export default {
  name: 'ProfilingGeneralSettingView',
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
      form: defaults(this), // will be overloaded with the data from the store
      formValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      form: this.formValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_profiling/isGeneralSettingsLoading']
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters['$_profiling/isGeneralSettingsWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    }
  },
  methods: {
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_profiling/setGeneralSettings', this.form).then(response => {
        // TODO - notification
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_profiling/getGeneralSettings', this.id).then(data => {
        this.form = Object.assign({}, data)
        // TODO - notification
      })
    }
  }
}
</script>
