<template>
  <pf-form-boolean :form-store-name="formStoreName" :form-namespace="formNamespace">
    <template v-slot:op="{ formStoreName, formNamespace }">
      <pf-form-chosen
        :form-store-name="formStoreName"
        :form-namespace="formNamespace + '.op'"
        :options="valuesOperators"
        :allow-empty="false"
        class="m-1"
      />
    </template>
    <template v-slot:value="{ formStoreName, formNamespace }">
      <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.field'" class="m-1"/>
      <pf-form-chosen
        :form-store-name="formStoreName"
        :form-namespace="formNamespace + '.op'"
        :options="valueOperators"
        :allow-empty="false"
        class="m-1"
      />
      <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.value'" class="m-1"/>
    </template>
  </pf-form-boolean>
</template>

<script>
import pfFormBoolean from '@/components/pfFormBoolean'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-boolean-field-op-value',
  components: {
    pfFormBoolean,
    pfFormChosen,
    pfFormInput
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    valueOperators: {
      type: Array,
      default: () => { return [] }
    },
    valuesOperators: {
      type: Array,
      default: () => { return [] }
    }
  }
}
</script>
