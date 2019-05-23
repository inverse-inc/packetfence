<template>
  <b-container fluid class="px-0">
    <b-form-row class="pf-field-rule pf-field-rule-syslog-parser-regex mx-0 mb-1 px-0" align-v="center"
      v-on="forwardListeners"
    >
      <b-col v-if="$slots.prepend" cols="1" align-self="start" class="py-1 text-center col-form-label">
        <slot name="prepend"></slot>
      </b-col>
      <b-col cols="10"
        class="collapse-handle d-flex align-items-center"
        :class="(valid) ? 'text-primary' : 'text-danger'"
        @click.prevent="click($event)"
      >
        <icon v-if="visible" name="chevron-circle-down" class="mr-2" :class="{ 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }"></icon>
        <icon v-else name="chevron-circle-right" class="mr-2" :class="{ 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }"></icon>
        <div>{{ localName || $t('New rule') }}</div>
      </b-col>
      <b-col v-if="$slots.append" cols="1" align-self="start" class="py-1 text-center col-form-label">
        <slot name="append"></slot>
      </b-col>
    </b-form-row>
    <b-collapse :id="uuidStr('collapse')" :ref="[uuidStr('collapse')]" class="mt-2" :visible="visible">
      <b-form-row
        class="text-secondary align-items-center"
        align-v="center"
        no-gutter
      >
        <b-col class="text-left py-0 px-2" align-self="start">
          <pf-form-input :column-label="$t('Name')" label-cols="2"
            v-model="localName"
            ref="localName"
            :vuelidate="nameVuelidateModel"
            :invalid-feedback="nameInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
          ></pf-form-input>
          <pf-form-input :column-label="$t('Regex')" label-cols="2"
            v-model="localRegex"
            ref="localRegex"
            :vuelidate="regexVuelidateModel"
            :invalid-feedback="regexInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
          ></pf-form-input>
          <pf-form-fields :column-label="$t('Actions')" label-cols="2"
            v-model="localActions"
            ref="localActions"
            :field="actions"
            :vuelidate="actionsVuelidateModel"
            :invalid-feedback="actionsInvalidFeedback"
            :button-label="$t('Add Action')"
            :disabled="disabled"
            @validations="setActionValidations($event)"
            class="mb-1 mr-2"
            sortable
          ></pf-form-fields>
          <pf-form-range-toggle :column-label="$t('Last If Match')" label-cols="2" text="Stop processing rules if this rule matches."
            v-model="localLastIfMatch"
            ref="localLastIfMatch"
            :values="{ checked: 'enabled', unchecked: 'disabled' }"
            :vuelidate="lastIfMatchVuelidateModel"
            :invalid-feedback="lastIfMatchInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
          ></pf-form-range-toggle>
          <pf-form-range-toggle :column-label="$t('IP &#x21C4; MAC')" label-cols="2" text="Perform automatic translation of IPs to MACs and the other way around."
            v-model="localIpMacTranslation"
            ref="localIpMacTranslation"
            :values="{ checked: 'enabled', unchecked: 'disabled' }"
            :vuelidate="ipMacTranslationVuelidateModel"
            :invalid-feedback="pMacTranslationInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
          ></pf-form-range-toggle>
          </b-col>
      </b-form-row>
    </b-collapse>
  </b-container>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import uuidv4 from 'uuid/v4'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

export default {
  name: 'pfFieldRuleSyslogParserRegex',
  components: {
    pfFormFields,
    pfFormInput,
    pfFormRangeToggle
  },
  props: {
    value: {
      type: Object,
      default: () => { return this.default }
    },
    actions: {
      type: Object,
      default: () => { return {} }
    },
    vuelidate: {
      type: Object,
      default: () => { return {} }
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      default:           { name: null, regex: null, actions: [], last_if_match: 'disabled', ip_mac_translation: 'enabled' }, // default value
      uuid:              uuidv4(), // unique id for multiple instances of this component
      actionValidations: {} // overloaded from actions (pf-form-fields) child component
    }
  },
  computed: {
    valid () {
      if (this.vuelidate) {
        if (!this.vuelidate.$anyError && !this.vuelidate.$dirty) return true
        if (!this.vuelidate.$invalid) return true
      }
      return false
    },
    inputValue: {
      get () {
        if (!this.value || Object.keys(this.value).length === 0) {
          // set default
          this.$emit('input', JSON.parse(JSON.stringify(this.default))) // keep dereferenced
          return this.default
        }
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    localName: {
      get () {
        return (this.inputValue && 'name' in this.inputValue) ? this.inputValue.name : this.default.name
      },
      set (newName) {
        this.$set(this.inputValue, 'name', newName || this.default.name)
        this.emitValidations()
      }
    },
    localRegex: {
      get () {
        return (this.inputValue && 'regex' in this.inputValue) ? this.inputValue.regex : this.default.regex
      },
      set (newDescription) {
        this.$set(this.inputValue, 'regex', newDescription || this.default.regex)
        this.emitValidations()
      }
    },
    localActions: {
      get () {
        return (this.inputValue && 'actions' in this.inputValue) ? this.inputValue.actions : this.default.actions
      },
      set (newActions) {
        this.$set(this.inputValue, 'actions', newActions || this.default.actions)
        this.emitValidations()
      }
    },
    localLastIfMatch: {
      get () {
        return (this.inputValue && 'last_if_match' in this.inputValue) ? this.inputValue.last_if_match : this.default.last_if_match
      },
      set (newLastIfMatch) {
        this.$set(this.inputValue, 'last_if_match', newLastIfMatch || this.default.last_if_match)
        this.emitValidations()
      }
    },
    localIpMacTranslation: {
      get () {
        return (this.inputValue && 'ip_mac_translation' in this.inputValue) ? this.inputValue.ip_mac_translation : this.default.ip_mac_translation
      },
      set (newIpMacTranslation) {
        this.$set(this.inputValue, 'ip_mac_translation', newIpMacTranslation || this.default.ip_mac_translation)
        this.emitValidations()
      }
    },
    nameVuelidateModel () {
      return this.getVuelidateModel('name')
    },
    nameInvalidFeedback () {
      return this.getInvalidFeedback('name')
    },
    regexVuelidateModel () {
      return this.getVuelidateModel('regex')
    },
    regexInvalidFeedback () {
      return this.getInvalidFeedback('regex')
    },
    actionsVuelidateModel () {
      return this.getVuelidateModel('actions')
    },
    actionsInvalidFeedback () {
      return this.actions.invalidFeedback
    },
    lastIfMatchVuelidateModel () {
      return this.getVuelidateModel('last_if_match')
    },
    lastIfMatchInvalidFeedback () {
      return this.getInvalidFeedback('last_if_match')
    },
    ipMacTranslationVuelidateModel () {
      return this.getVuelidateModel('ip_mac_translation')
    },
    ipMacTranslationInvalidFeedback () {
      return this.getInvalidFeedback('ip_mac_translation')
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    ctrlKey () {
      return this.$store.getters['events/ctrlKey']
    }
  },
  methods: {
    uuidStr (section) {
      return (section || 'default') + '-' + this.uuid
    },
    collapse () {
      const { $refs: { [this.uuidStr('collapse')]: ref } } = this
      if (ref && ref.$el.id === this.uuidStr('collapse')) {
        this.visible = false
        ref.show = false
      }
    },
    expand () {
      const { $refs: { [this.uuidStr('collapse')]: ref } } = this
      if (ref && ref.$el.id === this.uuidStr('collapse')) {
        this.visible = true
        ref.show = true
      }
    },
    toggle () {
      if (this.visible) this.collapse()
      else this.expand()
    },
    click (event) {
      this.toggle()
      if (this.ctrlKey) { // [CTRL] + CLICK = toggle all siblings
        this.$nextTick(() => {
          this.$emit('siblings', [(this.visible) ? 'expand' : 'collapse'])
        })
      }
    },
    getVuelidateModel (key = null) {
      let model = {}
      const { vuelidate: { [key]: vuelidate } } = this
      if (vuelidate) model = { ...model, ...this.vuelidate[key] } // deep merge
      return model
    },
    getInvalidFeedback (key = null) {
      let feedback = []
      const vuelidate = this.getVuelidateModel(key)
      if (vuelidate !== {} && key in vuelidate) {
        Object.entries(vuelidate[key].$params).forEach(([k, v]) => {
          if (vuelidate[key][k] === false) feedback.push(k.trim())
        })
      }
      return feedback.join('<br/>')
    },
    setActionValidations (event) {
      this.actionValidations = event
      this.emitValidations()
    },
    buildLocalValidations () {
      return { actions: this.actionValidations }
    },
    emitValidations () {
      this.$emit('validations', this.buildLocalValidations())
    },
    focus () {
      this.expand()
      this.$nextTick(() => {
        this.focusId()
      })
    },
    focusId () {
      const { $refs: { localName: { $refs: { input: { $el } } } } } = this
      $el.focus()
    }
  },
  created () {
    this.emitValidations()
  }
}
</script>

<style lang="scss">
.pf-field-rule-syslog-parser-regex {
  .collapse-handle {
    cursor: pointer;
  }
}
</style>
