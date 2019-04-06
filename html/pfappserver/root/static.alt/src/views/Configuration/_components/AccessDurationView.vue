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
        <span>{{ $t('Access Duration') }}</span>
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
  pfConfigurationAccessDurationViewFields as fields,
  pfConfigurationAccessDurationSerialize as serialize,
  pfConfigurationAccessDurationDeserialize as deserialize
} from '@/globals/configuration/pfConfigurationAccessDuration'

const { validationMixin } = require('vuelidate')

export default {
  name: 'AccessDurationView',
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
      this.$store.dispatch('$_bases/optionsGuestsAdminRegistration').then(options => {
        this.options = JSON.parse(JSON.stringify(options))
        this.$store.dispatch('$_bases/getGuestsAdminRegistration').then(data => {
          if ('access_duration_choices' in data && data.access_duration_choices.constructor === String) {
            // split and map access_duration_choices
            data.access_duration_choices = deserialize(data.access_duration_choices)
          }
          this.form = JSON.parse(JSON.stringify(data))
        })
      })
    },
    save () {
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      // re-join access_duration_choices
      form.access_duration_choices = serialize(form.access_duration_choices)
      this.$store.dispatch('$_bases/updateGuestsAdminRegistration', form)
    }
  },
  created () {
    this.init()
  }
}
</script>
