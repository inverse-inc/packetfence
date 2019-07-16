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
        <span>{{ $t('RADIUS Configuration') }}</span>
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading" class="mr-1">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="mr-3" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <pf-button-service class="mr-1" service="radiusd-acct" restart start stop></pf-button-service>
        <pf-button-service service="radiusd-auth" restart start stop></pf-button-service>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonService from '@/components/pfButtonService'
import {
  pfConfigurationRadiusViewFields as fields
} from '@/globals/configuration/pfConfigurationRadius'

const { validationMixin } = require('vuelidate')

export default {
  name: 'radius-view',
  mixins: [
    validationMixin
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonService
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
      return this.$store.getters['$_bases/isLoading']
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters['$_bases/isWaiting']
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
      this.$store.dispatch('$_bases/optionsRadiusConfiguration').then(options => {
        this.options = options
        this.$store.dispatch('$_bases/getRadiusConfiguration').then(form => {
          this.form = form
        })
      })
    },
    save () {
      this.$store.dispatch('$_bases/updateRadiusConfiguration', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
