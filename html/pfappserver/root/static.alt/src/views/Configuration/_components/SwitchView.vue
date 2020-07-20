<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :isNew="isNew"
    :isClone="isClone"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:tabs-end>
      <div class="flex-fill text-right">
        <pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle>
      </div>
    </template>
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Switch {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Switch {id}', { id: $strong(id) })"></span>
        <span v-else v-html="$t('New {switchGroup} Switch', { switchGroup: $strong(switchGroup) })"></span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Switch?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormToggle from '@/components/pfFormToggle'
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/switch'

export default {
  name: 'switch-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete,
    pfFormToggle
  },
  props: {
    formStoreName: { // from router
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
    },
    switchGroup: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      switchTemplates: [],
      roles: []
    }
  },
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/switch
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_switches/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    },
    isDeletable () {
      const { isNew, isClone, form: { not_deletable: notDeletable = false } = {} } = this
      if (isNew || isClone || notDeletable) {
        return false
      }
      return true
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    advancedMode: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { advancedMode = false } = {} } = this
        return advancedMode
      },
      set (newValue) {
        this.$set(this.meta, 'advancedMode', newValue)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_roles/all').then(roles => { // roles first to avoid race-condition
        this.roles = roles
        if (this.id) { // existing
          this.$store.dispatch('$_switches/optionsById', this.id).then(options => {
            this.$store.dispatch('$_switches/getSwitch', this.id).then(form => {
              if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
              const switchGroup = form.group
              const { meta = {} } = options
              const { isNew, isClone, roles, switchTemplates } = this
              this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, switchGroup, roles, switchTemplates } })
              this.$store.dispatch(`${this.formStoreName}/setForm`, form)
            })
          })
        } else { // new
          this.$store.dispatch('$_switches/optionsBySwitchGroup', this.switchGroup).then(options => {
            const { meta = {} } = options
            const { isNew, isClone, switchGroup, roles } = this
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, switchGroup, roles } })
            this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), ...{ group: this.switchGroup } }) // set defaults
          })
        }
        this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
        this.$store.dispatch('$_switches/optionsBySwitchGroup').then(switchGroupOptions => {
          const { meta: { type: { allowed: switchGroups = [] } = {} } = {} } = switchGroupOptions
          switchGroups.map(switchGroup => {
            const { options: switchGroupMembers } = switchGroup
            switchGroupMembers.map(switchGroupMember => {
                const { is_template, value } = switchGroupMember
                if (is_template) {
                  this.switchTemplates.push(value)
                }
            })
          })
        })
      })
    },
    close () {
      this.$router.push({ name: 'switches' })
    },
    clone () {
      this.$router.push({ name: 'cloneSwitch' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_switches/createSwitch', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'switch', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_switches/updateSwitch', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_switches/deleteSwitch', this.id).then(() => {
        this.close()
      })
    }
  },
  created () {
    this.init()
  },
  watch: {
    id: {
      handler: function () {
        this.init()
      }
    },
    isClone: {
      handler: function () {
        this.init()
      }
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
