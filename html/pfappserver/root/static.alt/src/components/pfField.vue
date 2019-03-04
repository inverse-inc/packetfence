<template>
  <b-form-row class="pf-field mx-0 mb-1 px-0" align-v="center"
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="10" align-self="start">
      <component
        v-model="inputValue"
        v-bind="field.attrs"
        v-on="forwardListeners"
        :is="field.component"
        :vuelidate="vuelidate"
        ref="component"
        no-gutter
      ></component>

    </b-col>
    <b-col v-if="$slots.append" cols="1" align-self="start" class="text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
export default {
  name: 'pf-field',
  props: {
    value: {
      type: Object,
      default: () => { return this.default }
    },
    field: {
      type: Object,
      default: () => { return {} }
    },
    vuelidate: {
      type: Object,
      default: () => { return {} }
    }
  },
  data () {
    return {
      default: null // default value
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.emitValidations()
        this.$emit('input', newValue)
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    buildLocalValidations () {
      const { field } = this
      if (field) {
        const { validators } = field
        if (validators) {
          return validators
        }
      }
      return {}
    },
    emitValidations () {
      this.$emit('validations', this.buildLocalValidations())
    },
    focus () {
      const { component: { $refs: { input: { $el } } } } = this.$refs
      if ('focus' in $el) $el.focus()
    }
  },
  created () {
    this.emitValidations()
  }
}
</script>

<style lang="scss">
.pf-field {
  .pf-form-chosen {
    .col-sm-12[role="group"] {
      padding-right: 0px;
      padding-left: 0px;
    }
  }
}
</style>
