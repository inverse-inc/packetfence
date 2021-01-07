<template>
  <b-form-row class="pf-field-rule pf-field-rule-syslog-parser-regex" :state="inputStateIfInvalidFeedback">
    <template v-slot:invalid-feedback>
      {{ invalidFeedback }}
    </template>
    <b-container fluid class="pf-field-rule-input-group px-0">
      <b-form-row class="pf-field-rule mx-0 mb-1 px-0" align-v="center">
        <b-col v-if="$slots.prepend" sm="1" align-self="start" class="py-1 text-center col-form-label">
          <slot name="prepend"></slot>
        </b-col>
        <b-col sm="10"
          class="collapse-handle d-flex align-items-center"
          :class="(inputAnyState !== false) ? 'text-primary' : 'text-danger'"
          @click.prevent="click($event)"
        >
          <icon v-if="visible" name="chevron-circle-down" class="mr-2" :class="{ 'text-primary': actionKey, 'text-secondary': !actionKey }"></icon>
          <icon v-else name="chevron-circle-right" class="mr-2" :class="{ 'text-primary': actionKey, 'text-secondary': !actionKey }"></icon>
          <div>{{ inputValue.name || $t('New rule') }}</div>
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
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.name`"
              ref="name"
              :disabled="disabled"
              class="mb-1 mr-2"
            ></pf-form-input>
            <pf-form-input :column-label="$t('Regex')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.regex`"
              ref="regex"
              :disabled="disabled"
              class="mb-1 mr-2"
            ></pf-form-input>
            <pf-form-fields :column-label="$t('Actions')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.actions`"
              ref="actions"
              :field="actions"
              :button-label="$t('Add Action')"
              :disabled="disabled"
              class="mb-1 mr-2"
              sortable
            ></pf-form-fields>
            <pf-form-range-toggle :column-label="$t('Last If Match')" label-cols="2" :text="$t('Stop processing rules if this rule matches.')"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.last_if_match`"
              ref="last_if_match"
              :values="{ checked: 'enabled', unchecked: 'disabled' }"
              :disabled="disabled"
              class="mb-1 mr-2"
            ></pf-form-range-toggle>
            <pf-form-range-toggle :column-label="$t('IP ⇄ MAC')" label-cols="2" :text="$t('Perform automatic translation of IPs to MACs and the other way around.')"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.ip_mac_translation`"
              ref="ip_mac_translation"
              :values="{ checked: 'enabled', unchecked: 'disabled' }"
              :disabled="disabled"
              class="mb-1 mr-2"
            ></pf-form-range-toggle>
          </b-col>
        </b-form-row>
      </b-collapse>
    </b-container>
  </b-form-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import uuidv4 from 'uuid/v4'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-field-rule-syslog-parser-regex',
  components: {
    pfFormFields,
    pfFormInput,
    pfFormRangeToggle
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    value: {
      type: Object,
      default: () => { return { name: null, regex: null, actions: [], last_if_match: 'disabled', ip_mac_translation: 'enabled' } }
    },
    actions: {
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
        return { name: null, regex: null, actions: [], last_if_match: 'disabled', ip_mac_translation: 'enabled' }
      }
    }

  },
  data () {
    return {
      uuid: uuidv4() // unique id for multiple instances of this component
    }
  },
  computed: {
    inputValue: {
      get () {
        return { ...this.default, ...this.formStoreValue } // use FormStore
      },
      set (newValue = null) {
        this.formStoreValue = newValue // use FormStore
      }
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
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
    click () {
      this.toggle()
      if (this.actionKey) { // [CTRL] + CLICK = toggle all siblings
        this.$nextTick(() => {
          this.$emit('siblings', [(this.visible) ? 'expand' : 'collapse'])
        })
      }
    },
    focus () {
      this.expand()
      this.$nextTick(() => {
        this.focusId()
      })
    },
    focusId () {
      const { $refs: { name: { $refs: { input: { $el } } } } } = this
      $el.focus()
    }
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
