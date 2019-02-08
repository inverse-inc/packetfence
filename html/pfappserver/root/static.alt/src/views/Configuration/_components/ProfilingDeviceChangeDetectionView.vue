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
        <span>{{ $t('Fingerbank device change detection') }}</span>
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
  pfConfigurationProfilingDeviceChangeDetectionViewFields as fields,
  pfConfigurationProfilingDeviceChangeDetectionViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationProfiling'
const { validationMixin } = require('vuelidate')

export default {
  name: 'ProfilingDeviceChangeDetectionView',
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
      return this.$store.getters['$_profiling/isDeviceChangeDetectionLoading']
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters['$_profiling/isDeviceChangeDetectionWaiting']
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
      this.$store.dispatch('$_profiling/setDeviceChangeDetection', this.form).then(response => {
        // TODO - notification
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_profiling/getDeviceChangeDetection', this.id).then(data => {
        this.form = Object.assign({}, data)
        // TODO - notification
      })
    }
  }
}
</script>
