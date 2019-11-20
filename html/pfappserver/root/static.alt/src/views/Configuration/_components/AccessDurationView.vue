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
    <template v-slot:header>
      <h4 class="mb-0">
        <span>{{ $t('Access Duration') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
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
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import {
  pfConfigurationAccessDurationViewFields as fields
} from '@/globals/configuration/pfConfigurationAccessDuration'
import duration from '@/utils/duration'

const { validationMixin } = require('vuelidate')

export default {
  name: 'access-duration-view',
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
        this.options = options
        this.$store.dispatch('$_bases/getGuestsAdminRegistration').then(form => {
          if ('access_duration_choices' in form && form.access_duration_choices.constructor === String) {
            // split and deserialize access_duration_choices
            form.access_duration_choices = form.access_duration_choices.split(',').map((accessDuration) => duration.deserialize(accessDuration))
          }
          this.form = form
        })
      })
    },
    save () {
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      // serialize and join access_duration_choices
      form.access_duration_choices = form.access_duration_choices.map(accessDuration => duration.serialize(accessDuration)).join(',')
      this.$store.dispatch('$_bases/updateGuestsAdminRegistration', form)
    }
  },
  created () {
    this.init()
  }
}
</script>
