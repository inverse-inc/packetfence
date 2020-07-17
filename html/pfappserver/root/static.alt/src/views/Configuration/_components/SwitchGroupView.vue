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
        <span v-if="!isNew && !isClone" v-html="$t('Switch Group {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Switch Group {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Switch Group') }}</span>
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
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Switch Group?')" @on-delete="remove()"/>
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
} from '../_config/switchGroup'

export default {
  name: 'switch-group-view',
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
    }
  },
  data () {
    return {
      roles: [] // all roles
    }
  },
  validations () {
    return {
      form: this.formValidations
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
      return view(this.form, this.meta) // ../_config/switchGroup
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_switch_groups/isLoading']
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
      this.$store.dispatch('$_roles/all').then(data => {
        this.roles = data
        this.$store.dispatch('$_switch_groups/options', this.id).then(options => {
          const { meta = {} } = options
          const { isNew, isClone, roles } = this
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, roles } })
          if (this.id) { // existing
            this.$store.dispatch('$_switch_groups/getSwitchGroup', this.id).then(form => {
              if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
              this.$store.dispatch(`${this.formStoreName}/setForm`, form)
            })
          } else { // new
            this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(meta)) // set defaults
          }
        })
        this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
      })
    },
    close () {
      this.$router.push({ name: 'switch_groups' })
    },
    clone () {
      this.$router.push({ name: 'cloneSwitchGroup' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_switch_groups/createSwitchGroup', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'switch_group', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_switch_groups/updateSwitchGroup', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_switch_groups/deleteSwitchGroup', this.id).then(() => {
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
