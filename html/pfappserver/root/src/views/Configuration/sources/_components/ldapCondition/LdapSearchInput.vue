<template>
  <MultiselectFacade
    :on-search="onSearch"
    :options="inputOptions"
    :value="inputValue"
    :label="text"
    :track-by="text"
    :single-label="singleLabel"
    :on-select="onSelect"
    :on-open="onOpen"
    :on-remove="onRemove"
    :on-close="onClose"
    :is-focused="isFocused"
    :is-disabled="isDisabled"
    :loading="isLoading"
    :placeholder="$i18n.t('Search')"
    :search-query-invalid-feedback="searchQueryInvalidFeedback"
    :search-query-valid-feedback="''"
    :state="inputState"
  />
</template>

<script>
import {BaseInputChosenOneSearchableProps} from '@/components/new'
import apiCall, {baseURL, baseURL as apiBaseURL} from '@/utils/api'
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

function performLdapSearch(form, inputValue, attribute) {
  return apiCall.request({
    url: 'ldap/search',
    method: 'post',
    baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
    data: {
      server: form.id,
      search: "(" + attribute + "=" + "*" + inputValue + "*)",
    }
  })
    .then((response) => {
      return Object.values(response.data).map((item) => {
        return valueToSelectValue(item[attribute])
      })
    })
}


function setup(props, _) { // eslint-disable-line
  const form = inject('form')
  const isFocused = ref(false)
  const isLoading = ref(false)
  const isDisabled = inject('isLoading')
  const defaultSelectedValue = {"text": "", "value": null}
  const selectedValue = ref(defaultSelectedValue)
  selectedValue.value = valueToSelectValue(
    getFormNamespace(props.namespace.split('.'), form.value)
  ) || defaultSelectedValue
  const inputOptions = ref([])
  const searchInput = ref("")
  const localValidator = inject('schema')

  const searchQueryInvalidFeedback = ref("")

  const ldapFilterAttribute = computed(() => {
    let ldapEntryNamespace = props.namespace.split('.')
    ldapEntryNamespace.pop()
    ldapEntryNamespace.push('attribute')
    return getFormNamespace(ldapEntryNamespace, form.value)
  })

  function onSearch(query) {
    searchInput.value = query
    isLoading.value = true
    performLdapSearch(form.value, query, ldapFilterAttribute.value).then((searchResults) => {
      inputOptions.value = searchResults
      addAlreadySelectedValueToOptions()
    }).finally(() => {
      isLoading.value = false
    })
  }

  function addAlreadySelectedValueToOptions() {
    if (selectedValue.value.value !== null &&
      !inputOptions.value.find(o => o.text === selectedValue.value.text)) {
      inputOptions.value.unshift(selectedValue.value)
    }
  }

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
    inputOptions.value = []
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

  function onOpen() {
    if (selectedValue.value.value !== null) {
      inputOptions.value = [selectedValue.value]
    }
    isFocused.value = true
  }

  function onClose() {
    isFocused.value = false
  }

  const singleLabel = computed(() => {
    return selectedValue.value !== null ? selectedValue.value.text : ""
  })

  validateChoice()

  return {
    inputOptions,
    isDisabled,
    isLoading,
    isFocused,
    onSearch,
    onSelect,
    onOpen,
    onClose,
    onRemove,
    singleLabel,
    inputValue: selectedValue,
    searchQueryInvalidFeedback,
    inputState,
    form,
  }
}

export default {
  name: 'ldap-search-input',
  methods: {unref},
  components: {MultiselectFacade},
  setup,
  props,
}
</script>
