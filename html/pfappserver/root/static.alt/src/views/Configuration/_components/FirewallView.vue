<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="firewall"
    :vuelidate="$v.firewall"
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
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Firewall SSO {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Firewall SSO {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Firewall SSO') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="firewallType"></b-badge>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.firewall.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Firewall?')" @on-delete="remove()"/>
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
  pfConfigurationFirewallViewFields as fields,
  pfConfigurationFirewallViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationFirewalls'
const { validationMixin } = require('vuelidate')

export default {
  name: 'FirewallView',
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
    firewallType: { // from router (or firewall)
      type: String,
      default: null
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
      firewall: defaults(this), // will be overloaded with the data from the store
      firewallValidations: {}, // will be overloaded with data from the pfConfigView,
      roles: [] // all roles
    }
  },
  validations () {
    return {
      firewall: this.firewallValidations
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
      if (this.isNew || this.isClone || ('not_deletable' in this.firewall && this.firewall.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close (event) {
      this.$router.push({ name: 'firewalls' })
    },
    create (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/createFirewall`, this.firewall).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'firewall', params: { id: this.firewall.id } })
        }
      })
    },
    save (event) {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateFirewall`, this.firewall).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (event) {
      this.$store.dispatch(`${this.storeName}/deleteFirewall`, this.id).then(response => {
        this.close()
      })
    },
    setValidations (validations) {
      this.$set(this, 'firewallValidations', validations)
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getFirewall`, this.id).then(data => {
        this.firewallType = data.type
        this.firewall = Object.assign({}, data)
        if (this.isClone) {
          this.firewall.id = null
        }
      })
    }
    this.firewall.type = this.firewallType
    this.$store.dispatch('$_roles/all').then(data => {
      this.roles = data
    })
  }
}
</script>
