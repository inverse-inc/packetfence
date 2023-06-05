<template>
  <SearchInput
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
              :is-disabled="props.disabled"
              :loading="isLoading"
              :placeholder="$i18n.t('Search')"
              :search-query-invalid-feedback="searchQueryInvalidFeedback"
              :search-query-valid-feedback="''"
              :state="inputState"
  />
</template>

<script>
import {BaseInputChosenOneSearchable, BaseInputChosenOneSearchableProps} from '@/components/new';
import apiCall, {baseURL, baseURL as apiBaseURL} from '@/utils/api';
import {getFormNamespace, setFormNamespace, useInputValue} from '@/composables/useInputValue';
import {computed, inject, ref, toRefs, unref} from '@vue/composition-api';
import {useInputMeta} from '@/composables/useMeta';
import SearchInput from '@/views/Configuration/sources/_components/ldapCondition/SearchInput.vue';
import i18n from '@/utils/locale';
import {namespaceToYupPath, useInputValidator} from '@/composables/useInputValidator';


export const props = {
  ...BaseInputChosenOneSearchableProps,

  lookup: {
    type: Function,
    default: () => {},
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
    }})
    .then((response) => {
      return Object.values(response.data).map((item) => {
        return valueToSelectValue(item[attribute])
      })
    })
}

function valueToSelectValue(value) {
  return {"text": value, "value": value}
}


function setup(props, context){
  const tempOptions = ref([]);
  const form = inject('form');
  const isFocused = ref(false);
  //const isLoading = inject('isLoading');
  const isLoading = ref(false);
  const isReadonly = inject('isReadonly')
  const defaultSelectedValue = {"text": "", "value": null}
  const selectedValue = ref(defaultSelectedValue);
  selectedValue.value = valueToSelectValue(getFormNamespace(props.namespace.split('.'), form.value)) || defaultSelectedValue
  const inputOptions = ref([]);
  const searchInput = ref("");
  const localValidator = inject('schema');

  const searchQueryInvalidFeedback = ref("");

  const ldapFilterAttribute = computed(() => {
    let ldapEntryNamespace = props.namespace.split('.')
    ldapEntryNamespace.pop()
    ldapEntryNamespace.push('attribute')
    return getFormNamespace(ldapEntryNamespace, form.value);
  })

  function onSearch(query) {
    searchInput.value = query;
    isLoading.value = true;
    performLdapSearch(form.value, query, ldapFilterAttribute.value).then((searchResults) => {
      inputOptions.value = searchResults
      addAlreadySelectedValueToOptions()
    }).finally(() => {
      isLoading.value = false;
    })
  }

  function addAlreadySelectedValueToOptions() {
    if (selectedValue.value.value !== null &&
      !inputOptions.value.find(o => o.text === selectedValue.value.text)) {
      inputOptions.value.unshift(selectedValue.value)
    }
  }

  function validateChoice(){
    const path = namespaceToYupPath(props.namespace)
    localValidator.value.validateAt(path, form.value).then(() => {
      searchQueryInvalidFeedback.value = ""
    }).catch(ValidationError => { // invalid
      const {inner = [], message} = ValidationError
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
    selectedValue.value = value;
    let ldapEntryNamespace = props.namespace.split('.')
    setFormNamespace(ldapEntryNamespace, form.value, value.value)
    validateChoice();
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

  validateChoice()

  const singleLabel = computed(() => {
    return selectedValue.value !== null ? selectedValue.value.text : ""
  })

  return {
    // useSingleValueLookupOptions
    inputOptions,
    isLoading,
    isFocused,
    isReadonly,
    onSearch,
    onSelect,
    onOpen,
    onClose,
    onRemove,
    singleLabel,
    // wrappers
    inputValue: selectedValue,
    searchQueryInvalidFeedback,
    inputState,
    form,

    tempOptions,
  }
}

export default {
  name: 'ldap-search-input',
  methods: {unref},
  components: {SearchInput},
  setup,
  props,
}
</script>
