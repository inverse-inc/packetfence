<template>
  <b-container fluid class="px-0">
    <b-form-row class="pf-field-rule mx-0 mb-1 px-0" align-v="center"
      v-on="forwardListeners"
    >
      <b-col v-if="$slots.prepend" sm="1" align-self="start" class="py-1 text-center col-form-label">
        <slot name="prepend"></slot>
      </b-col>
      <b-col sm="10"
        class="collapse-handle d-flex align-items-center"
        :class="(valid) ? 'text-primary' : 'text-danger'"
        @click.prevent="click($event)"
      >
        <icon v-if="visible" name="chevron-circle-down" class="mr-2" :class="{ 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }"></icon>
        <icon v-else name="chevron-circle-right" class="mr-2" :class="{ 'text-primary': ctrlKey, 'text-secondary': !ctrlKey }"></icon>
        <div>{{ localId || $t('New rule') }} <span v-if="localDescription">( {{ localDescription }} )</span></div>
      </b-col>
      <b-col v-if="$slots.append" sm="1" align-self="start" class="py-1 text-center col-form-label">
        <slot name="append"></slot>
      </b-col>
    </b-form-row>
    <b-collapse :id="uuidStr('collapse')" :ref="[uuidStr('collapse')]" class="mt-2" :visible="visible">
      <b-form-row
        class="text-secondary align-items-center"
        align-v="center"
        no-gutter
      >
        <b-col class="text-left py-0" align-self="start">
          <pf-form-input :column-label="$t('Name')" label-cols="2"
            v-model="localId"
            ref="localId"
            :vuelidate="idVuelidateModel"
            :invalid-feedback="idInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
          ></pf-form-input>
          <pf-form-input :column-label="$t('Description')" label-cols="2"
            v-model="localDescription"
            ref="localDescription"
            :vuelidate="descriptionVuelidateModel"
            :invalid-feedback="descriptionInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
          ></pf-form-input>
          <pf-form-chosen :column-label="$t('Matches')" label-cols="2"
            v-model="localMatch"
            ref="localMatch"
            label="text"
            track-by="value"
            :placeholder="matchLabel"
            :options="[
              { value: 'all', text: $i18n.t('All') },
              { value: 'any', text: $i18n.t('Any') }
            ]"
            :vuelidate="matchVuelidateModel"
            :invalid-feedback="matchInvalidFeedback"
            :disabled="disabled"
            class="mb-1 mr-2"
            collapse-object
          ></pf-form-chosen>
          <pf-form-fields :column-label="$t('Conditions')" label-cols="2"
            v-model="localConditions"
            ref="localConditions"
            :field="conditions"
            :vuelidate="conditionsVuelidateModel"
            :invalid-feedback="conditionsInvalidFeedback"
            :button-label="$t('Add Condition')"
            :disabled="disabled"
            @validations="setConditionValidations($event)"
            class="mb-1 mr-2"
            sortable
          ></pf-form-fields>
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
        </b-col>
      </b-form-row>
    </b-collapse>
  </b-container>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import uuidv4 from 'uuid/v4'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'

export default {
  name: 'pfFieldRule',
  components: {
    pfFormChosen,
    pfFormFields,
    pfFormInput
  },
  props: {
    value: {
      type: Object,
      default: () => { return this.default }
    },
    matchLabel: {
      type: String
    },
    actions: {
      type: Object,
      default: () => { return {} }
    },
    conditions: {
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
    },
    default: {
      type: Object,
      default: () => {
        return { id: null, description: null, match: 'all', actions: [], conditions: [] }
      }
    }
  },
  data () {
    return {
      uuid:                 uuidv4(), // unique id for multiple instances of this component
      actionValidations:    {}, // overloaded from actions (pf-form-fields) child component
      conditionValidations: {} // overloaded from conditions (pf-form-fields) child component
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
    localId: {
      get () {
        return (this.inputValue && 'id' in this.inputValue) ? this.inputValue.id : this.default.id
      },
      set (newId) {
        this.$set(this.inputValue, 'id', newId || this.default.id)
        this.emitValidations()
      }
    },
    localDescription: {
      get () {
        return (this.inputValue && 'description' in this.inputValue) ? this.inputValue.description : this.default.description
      },
      set (newDescription) {
        this.$set(this.inputValue, 'description', newDescription || this.default.description)
        this.emitValidations()
      }
    },
    localMatch: {
      get () {
        return (this.inputValue && 'match' in this.inputValue) ? this.inputValue.match : this.default.match
      },
      set (newMatch) {
        this.$set(this.inputValue, 'match', newMatch || this.default.match)
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
    localConditions: {
      get () {
        return (this.inputValue && 'conditions' in this.inputValue) ? this.inputValue.conditions : this.default.conditions
      },
      set (newConditions) {
        this.$set(this.inputValue, 'conditions', newConditions || this.default.conditions)
        this.emitValidations()
      }
    },
    idVuelidateModel () {
      return this.getVuelidateModel('id')
    },
    idInvalidFeedback () {
      return this.getInvalidFeedback('id')
    },
    descriptionVuelidateModel () {
      return this.getVuelidateModel('description')
    },
    descriptionInvalidFeedback () {
      return this.getInvalidFeedback('description')
    },
    matchVuelidateModel () {
      return this.getVuelidateModel('match')
    },
    matchInvalidFeedback () {
      return this.getInvalidFeedback('match')
    },
    actionsVuelidateModel () {
      return this.getVuelidateModel('actions')
    },
    actionsInvalidFeedback () {
      return this.actions.invalidFeedback
    },
    conditionsVuelidateModel () {
      return this.getVuelidateModel('conditions')
    },
    conditionsInvalidFeedback () {
      return this.conditions.invalidFeedback
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
    setConditionValidations (event) {
      this.conditionValidations = event
      this.emitValidations()
    },
    buildLocalValidations () {
      return { actions: this.actionValidations, conditions: this.conditionValidations }
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
      const { $refs: { localId: { $refs: { input: { $el } } } } } = this
      $el.focus()
    }
  },
  created () {
    this.emitValidations()
  }
}
</script>

<style lang="scss">
.pf-field-rule {
  .collapse-handle {
    cursor: pointer;
  }
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
