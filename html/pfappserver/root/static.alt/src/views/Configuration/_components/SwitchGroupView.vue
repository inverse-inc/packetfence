<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="switchGroup"
    :vuelidate="$v.switchGroup"
    :isNew="isNew"
    :isClone="isClone"
    @validations="switchGroupValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone">{{ $t('Switch Group {id}', { id: id }) }}</span>
        <span v-else-if="isClone">{{ $t('Clone Switch Group {id}', { id: id }) }}</span>
        <span v-else>{{ $t('New Switch Group') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.switchGroup.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Switch Group?')" @on-delete="remove()"/>
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
  pfConfigurationSwitchGroupViewFields as fields,
  pfConfigurationSwitchGroupViewDefaults as defaults,
  pfConfigurationSwitchGroupViewPlaceholders as placeholders
} from '@/globals/configuration/pfConfigurationSwitchGroups'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SwitchGroupView',
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
      this.$router.push({ name: 'switch_groups' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_switch_groups/createSwitchGroup', this.switchGroup).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'switch_group', params: { id: this.switchGroup.id } })
        }
      })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_switch_groups/updateSwitchGroup', this.switchGroup).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
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
