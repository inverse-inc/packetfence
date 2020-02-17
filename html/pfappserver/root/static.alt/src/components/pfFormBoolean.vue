<template>
  <div class="pf-form-boolean">

    <div v-if="values.length > 0 && op" class="pf-form-boolean-op">
      <slot name="op" v-bind="{ op, formStoreName, formNamespace }"></slot>
    </div>

    <div v-if="values.length > 0" class="pf-form-boolean-values">
      <template v-for="(value, index) in values">
        <pf-form-boolean :key="value" v-bind="attrs(index)">
          <template v-slot:op="{ op, formStoreName, formNamespace }">
            <slot name="op" v-bind="{ op, formStoreName, formNamespace }"></slot>
          </template>
          <template v-slot:value="{ value, formStoreName, formNamespace }">
            <slot name="value" v-bind="{ value, formStoreName, formNamespace }"></slot>
          </template>
        </pf-form-boolean>
      </template>
    </div>

    <div v-else class="pf-form-boolean-value">
      <slot name="value" v-bind="{ value, formStoreName, formNamespace }"></slot>
    </div>

  </div>
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
      const { inputValue: { op = null } = {} } = this
      return op || null
    },
    values () {
      const { inputValue: { values = [] } = {} } = this
      return values || []
    },
  },
  methods: {
    attrs (index) {
      const { inputValue: { values: { [index]: value } = {} } = {}, formStoreName, formNamespace } = this
      return { value, formStoreName, formNamespace: `${formNamespace}.values.${index}` }
    }
  }

}
</script>

<style lang="scss">
  .pf-form-boolean {
    display: flex;
    align-items: stretch;
    flex-wrap: nowrap;
    justify-content: flex-start;

    .pf-form-boolean-op,
    .pf-form-boolean-values,
    .pf-form-boolean-value {
      display: flex;
    }

    .pf-form-boolean-op {
      align-self: center;
      margin: 0 1rem !important;
    }

    .pf-form-boolean-values {
      align-items: stretch;
      flex-wrap: wrap;
      justify-content: space-between;

      border-color: var(--secondary);
      border-radius: 0.5rem;
      border-style: solid;
      border-width: 0 .25rem;
      padding: 0 .25rem;

      &:hover {
        border-color: var(--primary);
      }
    }

    .pf-form-boolean-value {

    }


  }
</style>
