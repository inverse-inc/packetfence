<template>
  <pf-config-view
    :isLoading="isLoading"
    :disabled="isLoading"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    @validations="formValidations = $event"
    @save="save"
    :services="['radiusd-acct', 'radiusd-auth']"
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
        <b-button :disabled="isLoading" class="mr-1" variant="outline-primary" @click="init()">{{ $t('Reset') }}</b-button>
        <pf-button-service service="radiusd" class="mr-1" restart start stop></pf-button-service>
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
  name: 'RadiusView',
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
        // store options
        this.options = JSON.parse(JSON.stringify(options))
        this.$store.dispatch('$_bases/getRadiusConfiguration').then(data => {
          this.form = JSON.parse(JSON.stringify(data))
        })
      })
    },
    save () {
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      this.$store.dispatch('$_bases/updateRadiusConfiguration', form).then(response => {
        // TODO - notification
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
