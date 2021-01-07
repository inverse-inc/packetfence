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
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Fingerbank Combination {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Fingerbank Combination {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Fingerbank Combination') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="'local'"></b-badge>
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
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Fingerbank Combination?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  view,
  validators
} from '../_config/fingerbank/combination'

export default {
  name: 'fingerbank-combination-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
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
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/fingerbank/combination
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_fingerbank/isCombinationsLoading']
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
    }
  },
  methods: {
    init () {
      const { isNew, isClone } = this
      this.$store.dispatch(`${this.formStoreName}/setMeta`, { isNew, isClone })
      if (this.id) {
        // existing
        this.$store.dispatch('$_fingerbank/getCombination', this.id).then(form => {
          if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
          this.$store.dispatch(`${this.formStoreName}/setForm`, form)
        })
      } else {
        this.$store.dispatch(`${this.formStoreName}/setForm`, {})
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'fingerbankCombinations' })
    },
    clone () {
      this.$router.push({ name: 'cloneFingerbankCombination' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_fingerbank/createCombination', this.form).then(response => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'fingerbankCombination', params: { id: response.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_fingerbank/updateCombination', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_fingerbank/deleteCombination', this.id).then(() => {
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
