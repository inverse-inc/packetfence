<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="syslogForwarder"
    :vuelidate="$v.syslogForwarder"
    :isNew="isNew"
    :isClone="isClone"
    @validations="setValidations($event)"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Syslog Entry {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Syslog Entry {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Syslog Entry') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.syslogForwarder.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Syslog Entry?')" @on-delete="remove()"/>
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
  pfConfigurationSyslogForwarderViewFields as fields,
  pfConfigurationSyslogForwarderViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationSyslogForwarders'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SyslogForwarderView',
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
    }
  },
  data () {
    return {
      syslogForwarder: defaults(this), // will be overloaded with the data from the store
      syslogForwarderValidations: {} // will be overloaded with data from the pfConfigView,
    }
  },
  validations () {
    return {
      syslogForwarder: this.syslogForwarderValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.syslogForwarder && this.syslogForwarder.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close (event) {
      this.$router.push({ name: 'syslogForwarders' })
    },
    create (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createSyslogForwarder`, this.syslogForwarder).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'syslogForwarder', params: { id: this.syslogForwarder.id } })
        }
      })
    },
    save (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateSyslogForwarder`, this.syslogForwarder).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch(`${this.storeName}/deleteSyslogForwarder`, this.id).then(response => {
        this.close()
      })
    },
    setValidations (validations) {
      this.$set(this, 'syslogForwarderValidations', validations)
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getSyslogForwarder`, this.id).then(data => {
        this.syslogForwarder = Object.assign({}, data)
        if (this.isClone) {
          this.syslogForwarder.id = null
        }
      })
    }
  }
}
</script>
