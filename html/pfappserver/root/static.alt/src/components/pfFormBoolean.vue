<template>
  <b-form-row>
    <b-col v-for="(value, index) in values" :key="value">
      <template v-if="'values' in value">
        <pf-form-boolean v-bind="attrs(index)" v-slot:default="{ value, formStoreName, formNamespace }">
         <slot v-bind="{ value, formStoreName, formNamespace }"></slot>
        </pf-form-boolean>
      </template>
      <template v-else>
        <slot v-bind="{ value, formStoreName, formNamespace: `${formNamespace}.values.${index}` }"></slot>
      </template>
      <template v-if="index < values.length - 1">
        <span><strong>{{ op }}</strong></span>
      </template>
    </b-col>
  </b-form-row>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-boolean',
  mixins: [
    pfMixinForm
  ],
  components: {

  },
  data () {
    return {

    }
  },
  props: {
    value: {
      type: Object,
      default: null
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    op () {
      const { inputValue: { op } = {} } = this
      return op
    },
    values () {
      const { inputValue: { values } = {} } = this
      return values || []
    },
  },
  methods: {
    attrs (index) {
      const { inputValue: { values: { [index]: value } = {} } = {}, formStoreName, formNamespace } = this
      const attrs = { value, formStoreName, formNamespace: `${formNamespace}.values.${index}` }

console.log('attrs', JSON.stringify(attrs, null, 2), this.$slots)

      return attrs
    }
  }

}
</script>
