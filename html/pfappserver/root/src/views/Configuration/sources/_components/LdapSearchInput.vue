<template>
  <SearchInput :on-search="onSearch"
               :options="inputOptions"
               :value="inputValue"
               :label="text"
               :track-by="text"
               :single-label="singleLabel"
               :on-select="onSelect"
               :loading="isLoading"
               :placeholder="i18n().t('Search')"
               :invalid-feedback="searchQueryInvalidFeedback"
               :valid-feedback="searchQueryValidFeedback"/>
</template>

<script>
import {BaseInputChosenOneSearchable} from '@/components/new';
import apiCall, {baseURL, baseURL as apiBaseURL} from '@/utils/api';
import {getFormNamespace, useInputValue} from '@/composables/useInputValue';
import {computed, inject, ref, toRefs, unref} from '@vue/composition-api';
import {useInputMeta} from '@/composables/useMeta';
import SearchInput from '@/views/Configuration/sources/_components/ldapCondition/SearchInput.vue';
import i18n from '@/utils/locale';
import {useInputValidator} from '@/composables/useInputValidator';


export const props = {
  ...BaseInputChosenOneSearchable.props,

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
        return {"text": item[attribute], "value": item[attribute]}
      })
    })
}


function setup(props, context){
  const tempOptions = ref([]);
  const form = inject('form');
  const selectedValue = ref(null);
  const inputOptions = ref([]);
  const searchInput = ref("");
  const ldapFilterAttribute = computed(() => {
    let ldapEntryNamespace = props.namespace.split('.')
    ldapEntryNamespace.pop()
    ldapEntryNamespace.push('attribute')
    return getFormNamespace(ldapEntryNamespace, form.value);
  })
  const isLoading = ref(false);

  function onSearch(query) {
    searchInput.value = query;
    isLoading.value = true;
    performLdapSearch(form.value, query, ldapFilterAttribute.value).then((searchResults) => {
      inputOptions.value = searchResults
    }).then(() => {
      isLoading.value = false;
    })
  }

  function onSelect(value) {
    selectedValue.value = value;
  }

  const metaProps = useInputMeta(props, context)

  const {
    state,
    searchQueryInvalidFeedback,
    searchQueryValidFeedback,
  } = useInputValidator(metaProps, selectedValue)

  const singleLabel = computed(() => {
    return selectedValue.value !== null ? selectedValue.value.text : ""
  })

  return {
    // useSingleValueLookupOptions
    inputOptions,
    isLoading,
    onSearch,
    onSelect,
    singleLabel,
    // wrappers
    inputValue: selectedValue,
    searchQueryInvalidFeedback,
    searchQueryValidFeedback,

    tempOptions,
  }
}

export default {
  name: 'ldap-search-input',
  methods: {
    i18n() {
      return i18n
    }
  },
  components: {SearchInput},
  setup,
  props,
}
</script>
