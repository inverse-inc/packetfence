<template>
  <pf-config-view
    :isLoading="isLoading"
    :isClonable="isClonable"
    :isDeletable="isDeletable"
    :disabled="isLoading"
    :form="getForm"
    :model="form"
    :vuelidate="$v.form"
    :isNew="isNew"
    :isClone="isClone"
    @validations="formValidations = $event"
    @close="close"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <template>
        <h4 class="d-inline mb-0">
          <span v-if="!isNew && !isClone">{{ $t('Interface {id}', { id: (isVlan) ? form.master : id }) }}</span>
          <span v-else-if="isClone">{{ $t('Clone Interface {id}', { id: (isVlan) ? form.master : id }) }}</span>
          <span v-else>{{ $t('New VLAN for Interface {id}', { id: (isVlan) ? form.master : id }) }}</span>
        </h4>
        <b-badge v-if="isVlan" class="ml-2" variant="secondary">VLAN {{ form.vlan }}</b-badge>
      </template>
    </template>
    <template slot="footer">
      <b-card-footer @mouseenter="$v.form.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-primary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="isClonable" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Interface?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonSave from '@/components/pfButtonSave'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationInterfaceViewFields as fields
} from '@/globals/configuration/pfConfigurationInterfaces'
const { validationMixin } = require('vuelidate')

export default {
  name: 'InterfaceView',
  mixins: [
    validationMixin,
    pfMixinCtrlKey,
    pfMixinEscapeKey
  ],
  components: {
    pfButtonDelete,
    pfButtonSave,
    pfConfigView
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
      form: {}, // will be overloaded with the data from the store
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
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.form.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isClonable () {
      return !this.isNew && !this.isClone && this.isVlan
    },
    isDeletable () {
      return !this.isNew && !this.isClone && this.isVlan
    },
    isVlan () {
      return (this.form && this.form.master)
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/getInterface`, this.id).then(form => {
        if (this.isNew) {
          this.form = {
            id: form.id,
            netmask: form.netmask,
            type: 'none'
          }
        } else {
          this.form = JSON.parse(JSON.stringify(form))
        }
      })
    },
    close () {
      this.$router.push({ name: 'interfaces' })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch(`${this.storeName}/updateInterface`, this.form).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove (id) {
      this.$store.dispatch(`${this.storeName}/deleteInterface`, this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    this.init()
  }
}
</script>
