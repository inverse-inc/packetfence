<template>
  <b-form-group class="pf-field-rule" :state="inputStateIfInvalidFeedback">
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
          :class="{
            'text-primary': inputValue && inputValue.status === 'enabled' && inputState !== false,
            'text-secondary': inputValue && inputValue.status === 'disabled' && inputState !== false,
            'text-danger': inputState === false
          }"
          @click.prevent="click($event)"
        >
          <icon v-if="visible" name="chevron-circle-down" class="mr-2" :class="{ 'text-primary': actionKey, 'text-secondary': !actionKey }"></icon>
          <icon v-else name="chevron-circle-right" class="mr-2" :class="{ 'text-primary': actionKey, 'text-secondary': !actionKey }"></icon>
          <div>{{ ruleName }}<span v-if="ruleDescription">( {{ ruleDescription }} )</span></div>
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
            <pf-form-range-toggle :column-label="$t('Status')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.status`"
              :values="{ checked: 'enabled', unchecked: 'disabled' }"
              :right-labels="{ checked: $t('Enabled'), unchecked: $t('Disabled') }"
              class="mb-1 mr-2 small"
            />
            <pf-form-input :column-label="$t('Name')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.id`"
              ref="id"
              :disabled="disabled"
              class="mb-1 mr-2"
            />
            <pf-form-input :column-label="$t('Description')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.description`"
              ref="description"
              :disabled="disabled"
              class="mb-1 mr-2"
            />
            <pf-form-chosen :column-label="$t('Matches')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.match`"
              ref="match"
              label="text"
              track-by="value"
              :placeholder="matchLabel"
              :options="[
                { value: 'all', text: $i18n.t('All') },
                { value: 'any', text: $i18n.t('Any') }
              ]"
              :disabled="disabled"
              class="mb-1 mr-2"
              collapse-object
            />
            <pf-form-fields :column-label="$t('Conditions')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.conditions`"
              ref="conditions"
              :field="conditions"
              :button-label="$t('Add Condition')"
              :disabled="disabled"
              class="mb-1 mr-2"
              sortable
            />
            <pf-form-fields :column-label="$t('Actions')" label-cols="2"
              :form-store-name="formStoreName"
              :form-namespace="`${formNamespace}.actions`"
              ref="actions"
              :field="actions"
              :button-label="$t('Add Action')"
              :disabled="disabled"
              class="mb-1 mr-2"
              sortable
            />
          </b-col>
        </b-form-row>
      </b-collapse>
    </b-container>
  </b-form-group>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import uuidv4 from 'uuid/v4'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-field-rule',
  components: {
    pfFormChosen,
    pfFormFields,
    pfFormInput,
    pfFormRangeToggle
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    default: {
      type: Object,
      default: () => {
        return { id: null, status: 'enabled', description: null, match: 'all', actions: [], conditions: [] }
      }
    },
    value: {
      type: Object,
      default: () => { return { id: null, status: 'enabled', description: null, match: 'all', actions: [], conditions: [] } }
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
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      uuid: uuidv4(), // unique id for multiple instances of this component
      visible: true
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreValue === null) {
          // eslint-disable-next-line
          this.formStoreValue = JSON.parse(JSON.stringify({
            id: null,
            status: 'enabled',
            description: null,
            match: 'all',
            actions: [],
            conditions: [],
            ...this.default
          })) // set default
        }
        return this.formStoreValue // use FormStore
      },
      set (newValue = null) {
        this.formStoreValue = newValue // use FormStore
      }
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    ruleName () {
      const { id } = this.inputValue || {}
      return id || this.$i18n.t('New rule')
    },
    ruleDescription () {
      const { description } = this.inputValue || {}
      return description
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
      }
    },
    expand () {
      const { $refs: { [this.uuidStr('collapse')]: ref } } = this
      if (ref && ref.$el.id === this.uuidStr('collapse')) {
        this.visible = true
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
      const { $refs: { id: { $refs: { input: { $el } } } } } = this
      $el.focus()
    }
  }
}
</script>

<style lang="scss">
.pf-field-rule {
  .pf-field-rule-input-group {
    border: 1px solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  &.is-invalid {
    > [role="group"] > .pf-field-rule-input-group {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
    > [role="group"] > .invalid-feedback {
      display: block!important;
    }
  }
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
