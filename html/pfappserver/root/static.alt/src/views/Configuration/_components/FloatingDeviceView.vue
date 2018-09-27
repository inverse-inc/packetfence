
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('Floating Device') }} <strong v-text="id"></strong></h4>
      </b-card-header>
      <div class="card-body">
        <pf-form-input v-model="floatingDevice.ip"
          :column-label="$t('IP Address')"
          :validation="$v.floatingDevice.ip"
          :invalid-feedback="[{ [$t('Enter a valid IP address')]: $v.floatingDevice.$invalid }]"/>
        <pf-form-input v-model="floatingDevice.pvid" type="number"
          :filter="globals.regExp.integerPositive"
          :validation="$v.floatingDevice.pvid"
          :column-label="$t('Native VLAN')"
          :text="$t('VLAN in which PacketFence should put the port')"/>
        <pf-form-toggle v-model="floatingDevice.trunkPort"
          :column-label="$t('Trunk Port')" :values="{checked: 'yes', unchecked: 'no'}"
          :text="$t('The port must be configured as a muti-vlan port')">
            {{ (floatingDevice.trunkPort === 'yes') ? $t('Yes') : $t('No') }}
        </pf-form-toggle>
        <pf-form-input v-model="floatingDevice.taggedVlan"
          :column-label="$t('Tagged VLANs')"
          :text="$t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.')"/>
      </div>
      <b-card-footer @mouseenter="$v.floatingDevice.$touch()">
        <b-button variant="primary" type="submit" :disabled="invalidForm"><icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Save') }}</b-button>
        <delete-button variant="danger" class="mr-3" :disabled="isLoading" :confirm="$t('Delete Floating Device?')" @on-delete="deleteFloatingDevice()">{{ $t('Delete') }}</delete-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import DeleteButton from '@/components/DeleteButton'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import pfFormToggle from '@/components/pfFormToggle'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
const { validationMixin } = require('vuelidate')
const { required, integer, ipAddress } = require('vuelidate/lib/validators')

export default {
  name: 'FloatingDeviceView',
  components: {
    DeleteButton,
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
    id: String
  },
  data () {
    return {
      globals: {
        regExp: regExp
      },
      floatingDevice: { // will be overloaded with the data from the store
        id: ''
      }
    }
  },
  validations: {
    floatingDevice: {
      id: { required },
      ip: { required, ipAddress },
      pvid: { integer }
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_floatingdevices/isLoading']
    },
    invalidForm () {
      return this.$v.floatingDevice.$invalid || this.$store.getters['$_floatingdevices/isLoading']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'floating_devices' })
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
    this.$store.dispatch('$_floatingdevices/getFloatingDevice', this.id).then(data => {
      this.floatingDevice = Object.assign({}, data)
    })
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
