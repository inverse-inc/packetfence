<template>
  <div class="ldap-search-input" v-if="manualInputChosen">
    <base-form-group>
      <b-form-input ref="input"
                    class="base-form-group-input"
                    :data-namespace="namespace"
                    :disabled="isDisabled"
                    type="text"
                    :value="inputValue ? inputValue.value : ''"
                    @input="(value) => onSelect({text: value, value: value})"
                    v-on="$listeners"
      />
      <template v-slot:append>
        <b-button-group
          @click="toggleManualInput"
        >
          <b-button class="input-group-text no-border-radius" tabindex="-1" :variant="'light'">
            <icon name="times"></icon>
          </b-button>
        </b-button-group>
      </template>
    </base-form-group>
  </div>
  <div v-else class="ldap-search-input">
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
      :is-connected="isConnected"
      :is-focused="isFocused"
      :is-disabled="isDisabled"
      :isLoading="isLoading"
      :placeholder="$i18n.t('Search')"
      :search-query-valid-feedback="''"
    >
      <template v-slot:before-list v-if="searchSuccess">
        <li class="multiselect__element">
          <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">
            {{ $t('Type to search') }}
          </div>
        </li>
      </template>
      <template v-slot:before-list v-else>
        <li class="multiselect__element">
          <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">
            {{ $t('Results might be missing.') }}
          </div>
        </li>
        <li class="multiselect__element">
          <b-button-group
            class="manual-input-button"
            @click="toggleManualInput"
          >
            <b-button class="input-group-text no-border-radius" tabindex="-1"
                      :variant="'light'">
              <icon name="plus" class="fa-xs"></icon>
              {{ $t('Input manually') }}
            </b-button>
          </b-button-group>
        </li>
      </template>
    </MultiselectFacade>
  </div>
</template>

<script>
import {BaseInputChosenOneSearchableProps} from '@/components/new'
import {getFormNamespace, setFormNamespace} from '@/composables/useInputValue'
import {computed, inject, ref, unref} from '@vue/composition-api'
import MultiselectFacade
  from '@/views/Configuration/sources/_components/ldapCondition/MultiselectFacade.vue'
import {valueToSelectValue} from '@/utils/convert'
import _ from 'lodash'
import ProvidedKeys from '@/views/Configuration/sources/_components/ldapCondition/ProvidedKeys';
import BaseFormGroup from '@/components/new/BaseFormGroup.vue';


export const props = {
  ...BaseInputChosenOneSearchableProps,

  lookup: {
    type: Function,
    default: () => {},
  }

}

function attributesToSelectValues(attributes) {
  return attributes.map((item) => {
    return valueToSelectValue(item)
  })
}

function createFilter(searchInput, attribute) {
  return '(' + attribute + '=' + '*' + searchInput + '*' + ')'
}


const minimumSearchLength = 1 // minimum number of characters to perform search
const searchAfter = 700 // milliseconds to wait after last keypress before performing search

function setup(props, context) { // eslint-disable-line
  const form = inject('form')
  const isFocused = ref(false)
  const isLoading = ref(false)
  const isDisabled = inject('isLoading')
  const sendLdapSearchRequest = inject(ProvidedKeys.performSearch)
  const isConnected = computed(() => inject(ProvidedKeys.connectedToLdap).value)
  const defaultSelectedValue = null
  const selectedValue = ref(defaultSelectedValue)
  const initialValue = getFormNamespace(props.namespace.split('.'), form.value)
  if (initialValue) {
    selectedValue.value = valueToSelectValue(initialValue)
  }
  const inputOptions = ref([])
  const searchInput = ref('')
  const searchSuccess = ref(true)
  const manualInputChosen = ref(false)

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
    sendLdapSearchRequest(filter).then((response) => {
      inputOptions.value = attributesToSelectValues(response.results)
      searchSuccess.value = response.success
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

  function onRemove() {
    inputOptions.value = []
    onSelect(defaultSelectedValue)
  }

  function onSelect(value) {
    selectedValue.value = value
    let ldapEntryNamespace = props.namespace.split('.')
    if (value) {
      setFormNamespace(ldapEntryNamespace, form.value, value.value)
    } else {
      setFormNamespace(ldapEntryNamespace, form.value, defaultSelectedValue)
    }
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
    return selectedValue.value !== null ? selectedValue.value.text : ''
  })

  function toggleManualInput() {
    manualInputChosen.value = !manualInputChosen.value
  }

  return {
    inputOptions,
    isDisabled,
    isLoading,
    isFocused,
    isConnected,
    onSearch,
    onSelect,
    onOpen,
    onClose,
    onRemove,
    searchSuccess,
    singleLabel,
    inputValue: selectedValue,
    manualInputChosen,
    form,
    toggleManualInput,
  }
}

export default {
  name: 'ldap-search-input',
  methods: {unref},
  components: {BaseFormGroup, MultiselectFacade},
  setup,
  props,
}
</script>
<style>
.ldap-search-input legend {
  display: none;
}
.manual-input-button {
  width: 100%;
}
.manual-input-button svg {
  margin-right: 0.5rem;
}
</style>
