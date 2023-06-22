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
    :no-connection="noConnection"
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
import {getFormNamespace, setFormNamespace} from '@/composables/useInputValue'
import {computed, inject, ref, unref} from '@vue/composition-api'
import MultiselectFacade
  from '@/views/Configuration/sources/_components/ldapCondition/multiselectFacade.vue'
import {namespaceToYupPath} from '@/composables/useInputValidator'
import {valueToSelectValue} from '@/utils/convert'
import _ from 'lodash'
import ProvidedKeys from '@/views/Configuration/sources/_components/ldapCondition/ProvidedKeys';
import {
  parseLdapStringToArray
} from '@/views/Configuration/sources/_components/ldapCondition/common';


export const props = {
  ...BaseInputChosenOneSearchableProps,

  lookup: {
    type: Function,
    default: () => {
    },
  }

}

function parseLdapResponse(response, ldapAttribute) {
  const ldapEntries = Object.values(response.data)
  let parsedEntries = new Set()
  for (let i = 0; i < ldapEntries.length; i++) {
    let value = ldapEntries[i][ldapAttribute]
    if (_.isArray(value)){
      parsedEntries = new Set([...parsedEntries, ...value])
    } else {
      parsedEntries.add(value)
    }
  }
  return Array.from(parsedEntries).filter((item) => {
    return Boolean(item)
  }).map((item) => {
    return valueToSelectValue(item)
  })
}

function createFilter(searchInput, attribute) {
  return "(" + attribute + "=" + "*" + searchInput + "*" + ")"
}


const minimumSearchLength = 1 // minimum number of characters to perform search
const searchAfter = 700 // milliseconds to wait after last keypress before performing search

function setup(props, context) { // eslint-disable-line
  const form = inject('form')
  const isFocused = ref(false)
  const isLoading = ref(false)
  const isDisabled = inject('isLoading')
  const sendLdapSearchRequest = inject(ProvidedKeys.performSearch)
  const noConnection = computed(() => !inject(ProvidedKeys.connectedToLdap).value)
  const defaultSelectedValue = null
  const selectedValue = ref(defaultSelectedValue)
  const initialValue = getFormNamespace(props.namespace.split('.'), form.value)
  if (initialValue) {
    selectedValue.value = valueToSelectValue(initialValue)
  }
  const inputOptions = ref([])
  const searchInput = ref("")
  const localValidator = inject('schema')

  const searchQueryInvalidFeedback = ref("")
  const debouncedSearch = _.debounce(performSearch, searchAfter)

  const ldapFilterAttribute = computed(() => {
    let ldapEntryNamespace = props.namespace.split('.')
    ldapEntryNamespace.pop()
    ldapEntryNamespace.push('attribute')
    return getFormNamespace(ldapEntryNamespace, form.value)
  })

  function onSearch(query) {
    searchInput.value = query
    isLoading.value = true
    if (query.length < minimumSearchLength) {
      inputOptions.value = []
      debouncedSearch.cancel()
      isLoading.value = false
      return
    }

    debouncedSearch(query)
  }

  function performSearch(query) {
    const filter = createFilter(query, ldapFilterAttribute.value)
    sendLdapSearchRequest(filter).then((searchResponse) => {
      inputOptions.value = parseLdapResponse(searchResponse, ldapFilterAttribute.value)
      addAlreadySelectedValueToOptions()
    }).finally(() => {
      isLoading.value = false
    })
  }

  function addAlreadySelectedValueToOptions() {
    if (selectedValue.value !== null &&
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
    if (value) {
      setFormNamespace(ldapEntryNamespace, form.value, value.value)
    } else {
      setFormNamespace(ldapEntryNamespace, form.value, defaultSelectedValue)
    }
    validateChoice()
  }

  function onOpen() {
    if (selectedValue.value !== null) {
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
    noConnection,
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
