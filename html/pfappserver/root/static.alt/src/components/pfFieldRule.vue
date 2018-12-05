<template>
  <b-container fluid class="px-0">
    <b-form-row class="pf-field-rule mx-0 mb-1 px-0 col-12" align-v="center"
      v-on="forwardListeners"
    >
      <b-col v-if="$slots.prepend" cols="1" align-self="start" class="pt-1 text-center col-form-label">
        <slot name="prepend"></slot>
      </b-col>
      <b-col cols="10"
        class="collapse-handle py-2"
        :class="(valid) ? 'text-primary' : 'text-danger'"
        @click.prevent="click($event)"
      >
        <icon v-if="visible" name="chevron-circle-down" :class="['mr-3', { 'text-primary': ctrlKey, 'text-dark': !ctrlKey }]"></icon>
        <icon v-else name="chevron-circle-right" :class="['mr-3', { 'text-primary': ctrlKey, 'text-dark': !ctrlKey }]"></icon>
        <span>Rule - {{ localId || 'New' }} ( {{ localDescription }} )</span>
      </b-col>
      <b-col v-if="$slots.append" cols="1" align-self="start" class="pt-1 text-center col-form-label">
        <slot name="append"></slot>
      </b-col>
    </b-form-row>
    <b-collapse  :id="uuidStr('collapse')" :ref="[uuidStr('collapse')]" class="mt-2" :visible="visible">
      <b-form-row
        class="text-secondary align-items-center"
        align-v="center"
        no-gutter
      >
        <b-col cols="12" class="text-left py-0 px-2" align-self="start">

          <pf-form-input :column-label="$t('Name')" label-cols="2"
            v-model="localId"
            ref="localId"
            :vuelidate="idVuelidateModel"
            :invalid-feedback="idInvalidFeedback"
            class="mb-1 mr-2"
          ></pf-form-input>
          <pf-form-input :column-label="$t('Description')" label-cols="2"
            v-model="localDescription"
            ref="localDescription"
            :vuelidate="descriptionVuelidateModel"
            :invalid-feedback="descriptionInvalidFeedback"
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
            collapse-object
          ></pf-form-chosen>
        </b-col>
      </b-form-row>
    </b-collapse>
  </b-container>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import uuidv4 from 'uuid/v4'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'

export default {
  name: 'pf-field-rule',
  mixins: [
    pfMixinCtrlKey
  ],
  components: {
    pfFormChosen,
    pfFormInput
  },
  props: {
    value: {
      type: Object,
      default: () => { return this.valuePlaceHolder }
    },
    matchLabel: {
      type: String
    },
    vuelidate: {
      type: Object,
      default: () => { return {} }
    }
  },
  data () {
    return {
      valuePlaceHolder: { id: null, description: null, match: 'all' }, // default value
      uuid:             uuidv4() // unique id for multiple instances of this component
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
          // set default placeholder
          this.$emit('input', this.valuePlaceHolder)
          return this.valuePlaceHolder
        }
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    localId: {
      get () {
        return (this.inputValue && 'id' in this.inputValue) ? this.inputValue.id : null
      },
      set (newId) {
        this.$set(this.inputValue, 'id', newId || null) // set type or null
        this.emitLocalValidationsToParent()
      }
    },
    localDescription: {
      get () {
        return (this.inputValue && 'description' in this.inputValue) ? this.inputValue.description : null
      },
      set (newDescription) {
        this.$set(this.inputValue, 'description', newDescription || null) // set type or null
        this.emitLocalValidationsToParent()
      }
    },
    localMatch: {
      get () {
        return (this.inputValue && 'match' in this.inputValue) ? this.inputValue.match : null
      },
      set (newMatch) {
        this.$set(this.inputValue, 'match', newMatch || null) // set type or null
        this.emitLocalValidationsToParent()
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
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    uuidStr (section) {
      return (section || 'default') + '-' + this.uuid
    },
    collapse () {
      const ref = this.$refs[this.uuidStr('collapse')]
      if (ref && ref.$el.id === this.uuidStr('collapse')) {
        ref.show = false
      }
      this.visible = false
    },
    expand () {
      const ref = this.$refs[this.uuidStr('collapse')]
      if (ref && ref.$el.id === this.uuidStr('collapse')) {
        ref.show = true
      }
      this.visible = true
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
      if (this.vuelidate && Object.keys(this.vuelidate).length > 0) {
        if (key in this.vuelidate) model = { ...model, ...this.vuelidate[key] } // deep merge
      }
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
    buildLocalValidations () {
      return {}
    },
    emitLocalValidationsToParent () {
      this.$emit('validations', this.buildLocalValidations())
    },
    focus () {
      this.expand()
      this.$nextTick(() => {
        this.focusId()
      })
    },
    focusId () {
      const ref = this.$refs['localId'].$refs
      ref.input.$el.focus()
    }
  },
  mounted () {
    this.emitLocalValidationsToParent()
  }
}
</script>

<style lang="scss">
.pf-field-rule {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-left: 0px;
      padding-right: 0px;
    }
  }
}
</style>
