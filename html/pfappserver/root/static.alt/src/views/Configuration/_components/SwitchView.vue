<!--
  "Switch" is a reserved word, therfore "switch" is renamed as "switche".
-->
<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="switche"
    :vuelidate="$v.switche"
    @validations="switcheValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Switch') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Switch') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.switche.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }} {{ isTest }}</pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Switch?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationSwitchViewFields as fields,
  pfConfigurationSwitchViewDefaults as defaults
} from '@/globals/pfConfigurationSwitches'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SwitchView',
  mixins: [
    validationMixin,
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
      switche: defaults(this), // will be overloaded with the data from the store
      switcheValidations: {}, // will be overloaded with data from the pfConfigView
      switchGroups: [] // all switch groups
    }
  },
  validations () {
    return {
      switche: this.switcheValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_switches/isLoading']
    },
    invalidForm () {
      return this.$v.switche.$invalid || this.$store.getters['$_switches/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.switche && this.switche.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'switches' })
    },
    create () {
      this.$store.dispatch('$_switches/createSwitch', this.switche).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_switches/updateSwitch', this.switche).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch('$_switches/deleteSwitch', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_switches/getSwitch', this.id).then(data => {
        this.switche = Object.assign({}, data)
      })
    }
    this.$store.dispatch('$_switchgroups/all').then(data => {
      console.log('switchGroups', data)
      this.switchGroups = data
    })
  }
}
</script>
