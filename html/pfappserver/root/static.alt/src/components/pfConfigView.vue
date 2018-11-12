<template>
  <b-form @submit.prevent="isNew? create() : save()">
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
          :label-cols="(row.label) ? form.labelCols : 0" :label="row.label"
          :state="isValid()" :invalid-feedback="getInvalidFeedback()"
          class="input-element" :class="{ 'mb-0': !row.label }"
          horizontal
        >
          <b-input-group>
            <template v-for="field in row.fields">
              <span v-if="field.text" :key="field.index" :class="field.class">{{ field.text }}</span>
              <component v-else-if="!('if' in field) || field.if"
                :key="field.key"
                :is="field.component || defaultComponent"
                v-bind="field.attrs"
                v-model="model[field.key]"
                :validation="validation[field.key]"
                :class="getClass(row, field)"
              ></component>
            </template>
          </b-input-group>
          <b-form-text v-if="row.text" v-t="row.text"></b-form-text>
        </b-form-group>
      </div>
      <slot name="footer">
        <b-card-footer @mouseenter="validation.$touch()">
          <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
          <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Config?')" @on-delete="remove()"/>
        </b-card-footer>
      </slot>
    </b-card>
  </b-form>
</template>

<script>
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
    }
  },
  computed: {
    isNew () {
      return this.form.fields.filter(field => field.key === 'id').length === 0
    },
    defaultComponent () {
      return pfFormInput
    }
  },
  methods: {
    close () {
      this.$emit('close')
    },
    create () {
      this.$emit('create')
    },
    save () {
      this.$emit('save')
    },
    remove () {
      this.$emit('remove')
    },
    getValidations () {
      const eachFieldValue = {}
      if (this.form.fields.length > 0) {
        this.form.fields.forEach((row, index) => {
          row.fields.forEach((field, index) => {
            eachFieldValue[field.key] = {}
            if (
              'validators' in field && // has vuelidate validations
              (!('if' in field) || field.if) // is visible
            ) {
              eachFieldValue[field.key] = field.validators
            }
          })
        })
        Object.freeze(eachFieldValue)
      }
      return eachFieldValue
    },
    emitExternalValidations () {
      // debounce to avoid emit storm,
      // delay to allow internal form field to update before building external validations
      if (this.emitExternalValidationsTimeout) clearTimeout(this.emitExternalValidationsTimeout)
      this.emitExternalValidationsTimeout = setTimeout(() => {
        this.$emit('validations', this.getValidations())
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
  display:flex;
  justify-contents:center;
  align-items:center;
}
</style>
