<template>
  <b-form @submit.prevent="(isNew || isClone) ? create($event) : save($event)">
    <b-card no-body>
      <slot name="header">
        <b-card-header>
          <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
          <h4 class="mb-0">
            <span>{{ $t('Configuration Template') }}</span>
          </h4>
        </b-card-header>
      </slot>
      <div class="card-body" v-if="form.fields">
        <b-form-group v-for="row in form.fields" :key="[row.key].join('')" v-if="!('if' in row) || row.if"
          :label-cols="(row.label) ? form.labelCols : 0" :label="row.label" :label-size="row.labelSize"
          :state="isValid()" :invalid-feedback="getInvalidFeedback()"
          class="input-element" :class="{ 'mb-0': !row.label, 'pt-3': !row.fields }"
          horizontal
        >
          <b-input-group>
            <template v-for="field in row.fields">
              <span v-if="field.text" :key="field.index" :class="field.class">{{ field.text }}</span>
              <component v-else-if="!('if' in field) || field.if"
                :key="field.key"
                :is="field.component || defaultComponent"
                v-bind="field.attrs"
                :validation="getValidation(field.key)"
                :class="getClass(row, field)"
                :value="getValue(field.key)"
                @input="setValue(field.key, $event)"
              ></component>
            </template>
          </b-input-group>
          <b-form-text v-if="row.text" v-t="row.text"></b-form-text>
        </b-form-group>
      </div>
      <slot name="footer">
        <b-card-footer @mouseenter="validation.$touch()">
          <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
          <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Config?')" @on-delete="remove($event)"/>
        </b-card-footer>
      </slot>
    </b-card>
  </b-form>
</template>

<script>
import Vue from 'vue'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pfConfigView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfFormInput
  },
  mixins: [
    pfMixinValidation
  ],
  props: {
    form: {
      type: Object,
      required: true
    },
    model: {
      type: Object,
      required: true
    },
    validation: {
      type: Object,
      required: true
    },
    isLoading: {
      type: Boolean
    },
    isNew: {
      type: Boolean
    },
    isClone: {
      type: Boolean
    }
  },
  computed: {
    defaultComponent () {
      return pfFormInput
    }
  },
  methods: {
    close (event) {
      this.$emit('close', event)
    },
    create (event) {
      this.$emit('create', event)
    },
    save (event) {
      this.$emit('save', event)
    },
    remove (event) {
      this.$emit('remove', event)
    },
    getValue (key, model = this.model) {
      if (key.includes('.')) { // handle dot-notation keys ('.')
        const split = key.split('.')
        const [ first, remainder ] = [ split[0], split.slice(1).join('.') ]
        return this.getValue(remainder, model[first])
      }
      return model[key]
    },
    setValue (key, value, model = this.model) {
      if (key.includes('.')) { // handle dot-notation keys ('.')
        const split = key.split('.')
        const [ first, remainder ] = [ split[0], split.slice(1).join('.') ]
        if (!(first in model)) this.$set(model, first, {})
        return this.setValue(remainder, value, model[first])
      }
      Vue.set(model, key, value)
    },
    getValidation (key, model = this.validation) {
      if (key.includes('.')) { // handle dot-notation keys ('.')
        const split = key.split('.')
        const [ first, remainder ] = [ split[0], split.slice(1).join('.') ]
        return this.getValidation(remainder, model[first])
      }
      return model[key]
    },
    getExternalValidations () {
      const eachFieldValue = {}
      const setEachFieldValue = (key, value, model = eachFieldValue) => {
        if (key.includes('.')) { // handle dot-notation keys ('.')
          const split = key.split('.')
          const [ first, remainder ] = [ split[0], split.slice(1).join('.') ]
          if (!(first in model)) {
            model[first] = {}
          }
          setEachFieldValue(remainder, value, model[first])
          return
        }
        Vue.set(model, key, value)
      }
      if (this.form.fields.length > 0) {
        this.form.fields.forEach((row, index) => {
          if ('fields' in row) {
            row.fields.forEach((field, index) => {
              if (field.key) {
                setEachFieldValue(field.key, {})
                if (
                  'validators' in field && // has vuelidate validations
                  (!('if' in field) || field.if) // is visible
                ) {
                  setEachFieldValue(field.key, field.validators)
                }
              }
            })
          }
        })
      }
      Object.freeze(eachFieldValue)
      return eachFieldValue
    },
    emitExternalValidations () {
      // debounce to avoid emit storm,
      // delay to allow internal form field to update before building external validations
      if (this.emitExternalValidationsTimeout) clearTimeout(this.emitExternalValidationsTimeout)
      this.emitExternalValidationsTimeout = setTimeout(() => {
        this.$emit('validations', this.getExternalValidations())
      }, 300)
    },
    getClass (row, field) {
      let c = ['px-0'] // always remove padding
      if ('attrs' in field && `class` in field.attrs) { // if class is defined
        c.push(field.attrs.class) // use manual definition
      } else if (row.fields.length === 1) { // else if row is singular
        c.push('col-sm-12') // use entire width
      }
      if (field !== row.fields[row.fields.length - 1]) { // if row is not last
        c.push('mr-1') // add right-margin
      }
      return c.join(' ')
    }
  },
  mounted () {
    this.emitExternalValidations()
  }
}
</script>

<style lang="scss" scoped>
.input-group > span {
  display: flex;
  justify-contents: center;
  align-items: center;
}
</style>
