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
        <span v-if="!isNew && !isClone" v-html="$t('Filter {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Filter {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Filter') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary">{{ collectionName }}</b-badge>
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
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Filter?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/filterEngine'

export default {
  name: 'filter-engine-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  data () {
    return {
      collectionMeta: {}
    }
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
    collection: { // from router
      type: String,
      default: null
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
      return view(this.form, this.collectionMeta) // ../_config/filterEngine
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_filter_engines/isLoading']
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
    collectionName () {
      return this.$store.getters['$_filter_engines/collectionToName'](this.collection)
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.formStoreName}/setInputDebounceTimeMs`, 1000)
      const { collection, id } = this
      // use collection meta to determine viewFields
      this.$store.dispatch('$_filter_engines/options', { collection }).then(options => {
        const { meta: collectionMeta = {} } = options
        this.collectionMeta = collectionMeta
      })
      // use item meta to determine the view
      this.$store.dispatch('$_filter_engines/options', { collection, id }).then(options => {
        const { meta = {} } = options
        const { isNew, isClone } = this
        this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, collection } })
        if (id) { // existing
          this.$store.dispatch('$_filter_engines/getFilterEngine', { collection, id }).then(form => {
            form = JSON.parse(JSON.stringify(form)) // dereference
            if (this.isClone) {
              form.id = `${form.id}-${this.$i18n.t('copy')}`
            }
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        } else { // new
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(meta)) // set defaults
        }
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'filter_engines' })
    },
    clone () {
      const { collection } = this
      this.$router.push({ name: 'cloneFilterEngine', params: { collection } })
    },
    create () {
      const { collection, actionKey, form: data, form: { id } = {} } = this
      this.$store.dispatch('$_filter_engines/createFilterEngine', { collection, data }).then(() => {
        if (!actionKey) {
          this.$router.push({ name: 'filter_engines' })
        } else {
          this.$router.push({ name: 'filter_engine', params: { collection, id } })
        }
      })
    },
    save () {
      const { collection, actionKey, isNew, isClone, form: data, form: { id } = {} } = this
      this.$store.dispatch('$_filter_engines/updateFilterEngine', { collection, id, data }).then(() => {
        if ((isNew && !actionKey) || (isClone && !actionKey) || (!isNew && !isClone && actionKey)) {
          this.$router.push({ name: 'filter_engines' })
        }
      })
    },
    remove () {
      const { collection, id } = this
      this.$store.dispatch('$_filter_engines/deleteFilterEngine', { collection, id }).then(() => {
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
