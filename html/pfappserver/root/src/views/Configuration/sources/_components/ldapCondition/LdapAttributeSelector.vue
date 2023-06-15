<template>
  <MultiselectFacade
    :options="inputOptions"
    :value="inputValue"
    :label="text"
    :track-by="text"
    :single-label="singleLabel"
    :on-select="onSelect"
    :on-remove="onRemove"
    :on-close="onClose"
    :is-focused="isFocused"
    :is-disabled="isDisabled"
    :placeholder="$i18n.t('Search')"
    :search-query-invalid-feedback="searchQueryInvalidFeedback"
    :search-query-valid-feedback="''"
    :state="inputState"
  />
</template>

<script>
import {BaseInputChosenOneSearchableProps} from '@/components/new'
import {getFormNamespace, setFormNamespace} from '@/composables/useInputValue'
import {computed, inject, ref, unref} from '@vue/composition-api'
import MultiselectFacade
  from '@/views/Configuration/sources/_components/ldapCondition/multiselectFacade.vue'
import {namespaceToYupPath} from '@/composables/useInputValidator'
import {valueToSelectValue} from '@/utils/convert';


export const props = {
  ...BaseInputChosenOneSearchableProps,

  lookup: {
    type: Function,
    default: () => {
    },
  }

}

function setup(props, _) { // eslint-disable-line
  const form = inject('form')
  const isFocused = ref(false)
  const allOptions = computed(() => {
    return inject('ldapAttributes').value.map(valueToSelectValue)
  })
  const isDisabled = inject('isLoading')
  const defaultSelectedValue = null
  const selectedValue = ref(defaultSelectedValue)
  selectedValue.value = valueToSelectValue(
    getFormNamespace(props.namespace.split('.'), form.value)
  ) || defaultSelectedValue
  const localValidator = inject('schema')

  const searchQueryInvalidFeedback = ref("")

  function validateChoice() {
    const path = namespaceToYupPath(props.namespace)
    localValidator.value.validateAt(path, form.value).then(() => {
      searchQueryInvalidFeedback.value = ""
    }).catch(ValidationError => { // invalid
      const {_, message} = ValidationError // eslint-disable-line
      searchQueryInvalidFeedback.value = message
    })
  }

  function onRemove() {
    onSelect(defaultSelectedValue)
  }

  const inputState = computed(() => {
    return searchQueryInvalidFeedback.value === ""
  })

  function onSelect(value) {
    selectedValue.value = value
    let ldapEntryNamespace = props.namespace.split('.')
    setFormNamespace(ldapEntryNamespace, form.value, value.value)
    validateChoice()
  }

  function onClose() {
    isFocused.value = false
  }

  const singleLabel = computed(() => {
    return selectedValue.value !== null ? selectedValue.value.text : ""
  })

  validateChoice()

  return {
    inputOptions: allOptions,
    isDisabled,
    isFocused,
    onSelect,
    onClose,
    onRemove,
    singleLabel,
    inputValue: selectedValue,
    searchQueryInvalidFeedback,
    inputState,
  }
}


export default {
  name: 'ldap-attribute-selector',
  methods: {unref},
  components: {MultiselectFacade},
  setup,
  props,
}
</script>
