<template>
  <div>
    <pf-form-range-toggle
      :value="advancedMode" @input="advancedMode = $event"
      :values="{checked: true, unchecked: false}"
      :rightLabels="{checked: $t('Advanced Mode'), unchecked: $t('Basic Mode')}"
      :disabled="disabled"
      class="text-nowrap mb-3"
    />

    <!-- Advanced Mode -->
    <pf-form-textarea v-if="advancedMode" ref="advancedCondition"
      v-model="advancedCondition"
      :disabled="disabled"
      rows="3" max-rows="10"
    />

    <!-- Basic Mode -->
    <pf-form-boolean v-else
      :form-store-name="formStoreName" :form-namespace="formNamespace" :disabled="disabled"
    >
      <template v-slot:op="{ formStoreName, formNamespace, disabled }">
        <pf-form-chosen
          :form-store-name="formStoreName"
          :form-namespace="formNamespace + '.op'"
          :options="valuesOperators"
          :allow-empty="false"
          :disabled="disabled"
          class="m-1"
        />
      </template>
      <template v-slot:value="{ formStoreName, formNamespace, disabled }">
        <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.field'" class="m-1" :disabled="disabled"/>
        <pf-form-chosen
          :form-store-name="formStoreName"
          :form-namespace="formNamespace + '.op'"
          :options="valueOperators"
          :allow-empty="false"
          :disabled="disabled"
          class="m-1"
        />
        <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.value'" class="m-1" :disabled="disabled"/>
      </template>
    </pf-form-boolean>

  </div>
</template>

<script>
import pfFormBoolean from '@/components/pfFormBoolean'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfMixinForm from '@/components/pfMixinForm'
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pf-form-filter-engine-condition',
  components: {
    pfFormBoolean,
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle,
    pfFormTextarea
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
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      advancedMode: false,
      advancedCondition: null
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    basicCondition:{
      get () {
        return this.form.condition
      },
      set (newValue) {
        this.form.condition = newValue
      }
    }
  },
  watch: {
    advancedMode: {
      handler: function (advancedMode) {
        if (advancedMode) {
          this.$nextTick(() => {
            const { $refs: { advancedCondition: { focus = () => {} } = {} } = {} } = this
            focus()
          })
        }
      }
    },
    advancedCondition: {
      handler: function (string) {
        if (string && this.advancedMode) {
          if (!this.$debouncer) {
            this.$debouncer = createDebouncer()
          }
          this.$debouncer({
            handler: () => {
              this.$store.dispatch('$_filter_engines/parseCondition', string).then(condition => {
                this.basicCondition = condition
              })
            },
            time: 1000 // 1 second
          })
        }
      }
    },
    basicCondition: {
      handler: function (json) {
        if (json && !this.advancedMode) {
          if (!this.$debouncer) {
            this.$debouncer = createDebouncer()
          }
          this.$debouncer({
            handler: () => {
              this.$store.dispatch('$_filter_engines/stringifyCondition', json).then(condition => {
                this.advancedCondition = condition
              })
            },
            time: 1000 // 1 second
          })
        }
      },
      deep: true
    }
  }
}
</script>
