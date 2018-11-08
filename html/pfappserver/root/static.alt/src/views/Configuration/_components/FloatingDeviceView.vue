<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="floatingDevice"
    :validation="$v.floatingDevice"
    @validations="floatingDeviceValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Floating Device') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Floating Device') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.floatingDevice.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Floating Device?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfFormToggle from '@/components/pfFormToggle'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
const { validationMixin } = require('vuelidate')
const { required, integer, macAddress, ipAddress } = require('vuelidate/lib/validators')

export default {
  name: 'FloatingDeviceView',
  mixins: [
    validationMixin,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete,
    pfFormInput,
    pfFormToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      globals: {
        regExp: regExp
      },
      floatingDevice: {}, // will be overloaded with the data from the store
      floatingDeviceValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      floatingDevice: this.floatingDeviceValidations
    }
  },
  computed: {
    isNew () {
      return this.id === null
    },
    isLoading () {
      return this.$store.getters['$_floatingdevices/isLoading']
    },
    invalidForm () {
      return this.$v.floatingDevice.$invalid || this.$store.getters['$_floatingdevices/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: [
          {
            if: this.isNew, // new floating devices only
            key: 'id',
            component: pfFormInput,
            label: this.$i18n.t('MAC Address'),
            validators: {
              [this.$i18n.t('MAC address is required.')]: required,
              [this.$i18n.t('Enter a valid MAC address.')]: macAddress()
            }
          },
          {
            key: 'ip',
            component: pfFormInput,
            label: this.$i18n.t('IP Address'),
            validators: {
              [this.$i18n.t('IP address is required.')]: required,
              [this.$i18n.t('Enter a valid IP address.')]: ipAddress
            }
          },
          {
            key: 'pvid',
            component: pfFormInput,
            label: this.$i18n.t('Native VLAN'),
            text: this.$i18n.t('VLAN in which PacketFence should put the port.'),
            attrs: {
              filter: this.globals.regExp.integerPositive
            },
            validators: {
              [this.$i18n.t('Native VLAN is required.')]: required,
              [this.$i18n.t('Enter a valid Native VLAN.')]: integer
            }
          },
          {
            key: 'trunkPort',
            component: pfFormToggle,
            label: this.$i18n.t('Trunk Port'),
            text: this.$i18n.t('The port must be configured as a muti-vlan port.'),
            attrs: {
              values: { checked: 'yes', unchecked: 'no' }
            }
          },
          {
            key: 'taggedVlan',
            component: pfFormInput,
            label: this.$i18n.t('Tagged VLANs'),
            text: this.$i18n.t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.')
          }
        ]
      }
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'floating_devices' })
    },
    create () {
      this.$store.dispatch('$_floatingdevices/createFloatingDevice', this.floatingDevice).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_floatingdevices/updateFloatingDevice', this.floatingDevice).then(response => {
        this.close()
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
