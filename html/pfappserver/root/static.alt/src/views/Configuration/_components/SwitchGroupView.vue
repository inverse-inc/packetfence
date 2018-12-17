<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="switchGroup"
    :vuelidate="$v.switchGroup"
    @validations="switchGroupValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Switch Group') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Switch Group') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.switchGroup.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Switch Group?')" @on-delete="remove()"/>
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
  pfConfigurationSwitchViewDefaults as defaults,
  pfConfigurationSwitchViewPlaceholders as placeholders
} from '@/globals/pfConfigurationSwitches'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SwitchGroupView',
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
      switchGroup: defaults(this), // will be overloaded with the data from the store
      switchGroupValidations: {}, // will be overloaded with data from the pfConfigView
      roles: [], // all roles
      placeholders: placeholders(this) // form placeholders
    }
  },
  validations () {
    return {
      switchGroup: this.switchGroupValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_switch_groups/isLoading']
    },
    invalidForm () {
      return this.$v.switchGroup.$invalid || this.$store.getters['$_switch_groups/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.switchGroup && this.switchGroup.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'switchGroups' })
    },
    create () {
      this.$store.dispatch('$_switch_groups/createSwitchGroup', this.switchGroup).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_switch_groups/updateSwitchGroup', this.switchGroup).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch('$_switch_groups/deleteSwitchGroup', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    this.$store.dispatch('$_roles/all').then(data => {
      this.roles = data
    })
    if (this.id) {
      this.$store.dispatch('$_switch_groups/getSwitchGroup', this.id).then(data => {
        this.switchGroup = Object.assign({}, data)
      })
    }
  }
}
</script>
