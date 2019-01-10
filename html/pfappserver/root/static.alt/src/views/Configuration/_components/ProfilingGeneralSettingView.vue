<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="general"
    :vuelidate="$v.general"
    @validations="generalValidations = $event"
    @save="save"
  >
    <template slot="header" is="b-card-header">
      <h4 class="mb-0">
        <span>{{ $t('Account information on api.fingerbank.org') }}</span>
      </h4>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.general.$touch()">
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
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationProfilingGeneralSettingsViewFields as fields,
  pfConfigurationProfilingGeneralSettingsViewDefaults as defaults
} from '@/globals/pfConfigurationProfiling'
const { validationMixin } = require('vuelidate')

export default {
  name: 'ProfilingGeneralSettingView',
  mixins: [
    validationMixin,
    pfMixinCtrlKey,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
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
      general: defaults(this), // will be overloaded with the data from the store
      generalValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      general: this.generalValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_TODO/isLoading']
    },
    invalidForm () {
      return this.$v.general.$invalid || this.$store.getters['$_TODO/isWaiting']
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
      this.$store.dispatch('$_TODO/updateTODO', this.general).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_TODO/getTODO', this.id).then(data => {
        this.general = Object.assign({}, data)
      })
    }
  }
}
</script>
