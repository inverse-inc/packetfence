
<template>
  <b-form @submit.prevent="isNew? create() : save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('Floating Device') }} <strong v-text="id"></strong></h4>
      </b-card-header>
      <div class="card-body">
        <pf-form-input v-if="isNew" v-model="floatingDevice.id"
          :column-label="$t('MAC Address')"
          :validation="$v.floatingDevice.id"
          :invalid-feedback="[{ [$t('Enter a valid MAC address')]: $v.floatingDevice.id.$invalid }]"/>
        <pf-form-input v-model="floatingDevice.ip"
          :column-label="$t('IP Address')"
          :validation="$v.floatingDevice.ip"
          :invalid-feedback="[{ [$t('Enter a valid IP address')]: $v.floatingDevice.ip.$invalid }]"/>
        <pf-form-input v-model="floatingDevice.pvid" type="number"
          :filter="globals.regExp.integerPositive"
          :validation="$v.floatingDevice.pvid"
          :column-label="$t('Native VLAN')"
          :text="$t('VLAN in which PacketFence should put the port')"/>
        <pf-form-toggle v-model="floatingDevice.trunkPort"
          :column-label="$t('Trunk Port')" :values="{checked: 'yes', unchecked: 'no'}"
          :text="$t('The port must be configured as a muti-vlan port')"/>
        <pf-form-input v-model="floatingDevice.taggedVlan"
          :column-label="$t('Tagged VLANs')"
          :text="$t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.')"/>
      </div>
      <b-card-footer @mouseenter="$v.floatingDevice.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
        <pf-button-delete class="ml-1" v-if="!isNew" :disabled="isLoading" :confirm="$t('Delete Floating Device?')" @on-delete="deleteFloatingDevice()"/>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import pfFormToggle from '@/components/pfFormToggle'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
const { validationMixin } = require('vuelidate')
const { required, integer, macAddress, ipAddress } = require('vuelidate/lib/validators')

export default {
  name: 'FloatingDeviceView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfFormInput,
    pfFormRow,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
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
      floatingDevice: {} // will be overloaded with the data from the store
    }
  },
  validations: {
    floatingDevice: {
      id: { required, macAddress: macAddress() },
      ip: { required, ipAddress },
      pvid: { required, integer }
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
    deleteFloatingDevice () {
      this.$store.dispatch('$_floatingdevices/deleteFloatingDevice', this.id).then(response => {
        this.close()
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_floatingdevices/getFloatingDevice', this.id).then(data => {
        this.floatingDevice = Object.assign({}, data)
      })
    }
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>

<style>
</style>
