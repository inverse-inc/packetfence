<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="floatingDevice"
    :vuelidate="$v.floatingDevice"
    :isNew="isNew"
    :isClone="isClone"
    @validations="floatingDeviceValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Floating Device {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Floating Device {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Floating Device') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.floatingDevice.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Floating Device?')" @on-delete="remove()"/>
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
  pfConfigurationFloatingDeviceViewFields as fields,
  pfConfigurationFloatingDeviceViewDefaults as defaults
} from '@/globals/configuration/pfConfigurationFloatingDevices'
const { validationMixin } = require('vuelidate')

export default {
  name: 'FloatingDeviceView',
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
      floatingDevice: defaults(this), // will be overloaded with the data from the store
      floatingDeviceValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      floatingDevice: this.floatingDeviceValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_floatingdevices/isLoading']
    },
    invalidForm () {
      return this.$v.floatingDevice.$invalid || this.$store.getters['$_floatingdevices/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.floatingDevice && this.floatingDevice.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'floating_devices' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_floatingdevices/createFloatingDevice', this.floatingDevice).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'floating_device', params: { id: this.floatingDevice.id } })
        }
      })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_floatingdevices/updateFloatingDevice', this.floatingDevice).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_floatingdevices/deleteFloatingDevice', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_floatingdevices/getFloatingDevice', this.id).then(data => {
        this.floatingDevice = Object.assign({}, data)
      })
    }
  }
}
</script>
