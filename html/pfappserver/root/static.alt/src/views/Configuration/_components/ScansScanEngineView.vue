<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="scanEngine"
    :vuelidate="$v.scanEngine"
    :isNew="isNew"
    :isClone="isClone"
    @validations="scanEngineValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Scan Engine {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Scan Engine {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Scan Engine') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="scanType"></b-badge>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.scanEngine.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Scan Engine?')" @on-delete="remove()"/>
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
  pfConfigurationScanEngineViewFields as fields,
  pfConfigurationScanEngineViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationScans'
const { validationMixin } = require('vuelidate')

export default {
  name: 'ScansScanEngineView',
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
    },
    isNew: { // from router
      type: Boolean,
      default: false
    },
    isClone: { // from router
      type: Boolean,
      default: false
    },
    id: { // from router
      type: String,
      default: null
    },
    scanType: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      scanEngine: defaults(this), // will be overloaded with the data from the store
      scanEngineValidations: {}, // will be overloaded with data from the pfConfigView
      roles: [], // all roles
      switchGroups: [] // all switch groups
    }
  },
  validations () {
    return {
      scanEngine: this.scanEngineValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_scanEngines/isLoading']
    },
    invalidForm () {
      return this.$v.scanEngine.$invalid || this.$store.getters['$_scanEngines/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.scanEngine && this.scanEngine.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'scanEngines' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_scanEngines/createSwitch', this.scanEngine).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'switch', params: { id: this.scanEngine.id } })
        }
      })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_scanEngines/updateSwitch', this.scanEngine).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_scanEngines/deleteSwitch', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    this.$store.dispatch('$_roles/all').then(data => {
      this.roles = data
    })
    this.$store.dispatch('$_switch_groups/all').then(data => {
      this.switchGroups = data
    })
    if (this.id) {
      this.$store.dispatch('$_scans/getScanEngine', this.id).then(data => {
        this.scanEngine = Object.assign({}, data)
      })
    } else {
      this.scanEngine.type = this.scanType
    }
  }
}
</script>
