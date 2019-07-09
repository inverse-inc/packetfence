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
        {{ $t('Parking') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_parked_devices" />
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfButtonHelp from '@/components/pfButtonHelp'
import pfButtonSave from '@/components/pfButtonSave'
import pfConfigView from '@/components/pfConfigView'
import {
  pfConfigurationParkingViewFields as fields
} from '@/globals/configuration/pfConfigurationParking'

const { validationMixin } = require('vuelidate')

export default {
  name: 'parking-view',
  mixins: [
    validationMixin
  ],
  components: {
    pfButtonHelp,
    pfButtonSave,
    pfConfigView
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
      this.$store.dispatch('$_bases/optionsParking').then(options => {
        this.options = options
        this.$store.dispatch('$_bases/getParking').then(form => {
          this.form = form
        })
      })
    },
    save () {
      this.$store.dispatch('$_bases/updateParking', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
