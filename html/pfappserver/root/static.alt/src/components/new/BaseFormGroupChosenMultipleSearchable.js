import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInput } from '@/composables/useInput'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import BaseFormGroupChosenMultiple, { props as BaseFormGroupChosenMultipleProps } from './BaseFormGroupChosenMultiple'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'

export const props = {
  ...BaseFormGroupChosenMultipleProps,

  // preserve search string when option is chosen
  clearOnSelect: {
    type: Boolean,
    default: false
  },
  // use async search, not internal
  internalSearch: {
    type: Boolean,
    default: false
  },
  // meta allowed_lookup { field_name, search_path, value_name }
  lookup: {
    type: Object,
    default: () => ({})
  }
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)
  const {
    label,
    trackBy,
    options,
    optionsLimit,
    lookup
  } = toRefs(metaProps)

  const {
    placeholder,
    isFocus,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const currentValueOptions = ref([])
  const currentValueLoading = ref(false)
  let lastCurrentPromise = 0 // only use latest of 1+ promises
  watch([value, lookup], (...args) => {
    if (!value.value || value.value.length === 0 || !lookup.value)
      currentValueOptions.value = []
    else {
      // avoid (re)lookup when watch is triggered without value change
      //  false-positives occur when parent array pushes/pops siblings
      const { 0: { 0: newValue, 1: newLookup } = {}, 1: { 0: oldValue, 1: oldLookup } = {} } = args
      if (newValue === oldValue && JSON.stringify(newLookup) === JSON.stringify(oldLookup))
        return // These are not the droids you're looking for...

      const { field_name: fieldName, search_path: url, value_name: valueName } = lookup.value
      currentValueLoading.value = true
      const thisCurrentPromise = ++lastCurrentPromise
      apiCall.request({
        url,
        method: 'post',
        baseURL: '', // reset
        data: {
          query: { op: 'and', values: [{
            op: 'or',
            values: value.value.map(value => ({ field: valueName, op: 'equals', value }))
          }] },
          fields: [fieldName, valueName],
          sort: [fieldName],
          cursor: 0,
          limit: value.value.length
        }
      }).then(response => {
        if (thisCurrentPromise === lastCurrentPromise) { // ignore slow responses
          const { data: { items = [] } = {} } = response
          currentValueOptions.value = items.map(item => {
            const { [fieldName]: _field, [valueName]: _value } = item // unmap lookup field_name/value_name
            return { [label.value]: _field, [trackBy.value]: _value } // remap option label/trackBy
          })
        }
      }).finally(() => {
        currentValueLoading.value = false
      })
    }
  }, { immediate: true, deep: true })

  const searchResultLoading = ref(false)
  const searchResultOptions = ref(options.value) // use default options
  const showEmpty = ref(false)
  let lastSearchPromise = 0 // only use latest of 1+ promises
  let searchDebouncer
  let lastSearchQuery

  const _doSearch = (query) => {
    if (!query) { // query is empty
      searchResultOptions.value = options.value // restore default options
      return
    }
    const { field_name: fieldName, search_path: url, value_name: valueName } = lookup.value
    searchResultLoading.value = true
    if (!searchDebouncer)
      searchDebouncer = createDebouncer()
    searchDebouncer({
      handler: () => {
        const thisSearchPromise = ++lastSearchPromise
        // split query by space(s)
        const values = query
          .trim() // trim outside whitespace
          .split(' ') // separate terms by space
          .filter(q => q) // ignore multiple spaces
          .map(query => ({ op: 'or', values: [{ field: fieldName, op: 'contains', value: query }] }))

        apiCall.request({
          url,
          method: 'post',
          baseURL: '', // reset
          data: {
            query: { op: 'and', values },
            fields: [fieldName, valueName],
            sort: [fieldName],
            cursor: 0,
            limit: optionsLimit.value - value.value.length
          }
        }).then(response => {
          if (thisSearchPromise === lastSearchPromise) { // ignore late responses from earlier reqs
            const { data: { items = [] } = {} } = response
            searchResultOptions.value = items.map(item => {
              const { [fieldName]: _field, [valueName]: _value } = item // unmap lookup field_name/value_name
              return { [label.value]: _field, [trackBy.value]: _value } // remap label/trackBy
            })
          }
        }).finally(() => {
          searchResultLoading.value = false
          showEmpty.value = true // only show after first search
        })
      },
      time: 300
    })
  }

  const onRemove = (option) => {
    const { [trackBy.value]: trackedValue } = option
    const filteredValues = (value.value || []).filter(item => item !== trackedValue)
    onInput(filteredValues)
  }

  const onSearch = (query) => {
    lastSearchQuery = query
    if (lookup.value)
      _doSearch(query)
  }

  // redo search when lookup is mutated
  watch(lookup, () => {
    if (lastSearchQuery)
      onSearch(lastSearchQuery)
  })

  const isLoading = computed(() => currentValueLoading.value || searchResultLoading.value)

  const inputOptions = computed(() => {
    let unique = []
    return Array.prototype.slice.call([ // dereference for sort
    ...currentValueOptions.value,
    ...searchResultOptions.value
    ]).sort((...pair) => { // sort alpha
      const { 0: { [label.value]: labelA } = {}, 1: { [label.value]: labelB } = {} } = pair
      return labelA.localeCompare(labelB)
    }).filter(option => { // force unique (via trackBy)
      const { [trackBy.value]: tracked } = option
      if (unique.includes(tracked))
        return false
      unique.push(tracked)
      return true
    })
  })

  const multipleLabels = computed(() => inputOptions.value.reduce((labels, option) => {
    const { text, value } = option
    return { ...labels, [value]: text }
  }, {}))

  const inputValueWrapper = computed(() => {
    return (value.value || []).map(item => {
      const optionsIndex = inputOptions.value.findIndex(option => option[trackBy.value] === item)
      if (optionsIndex > -1)
        return inputOptions.value[optionsIndex]
      return ({ [label.value]: item, [trackBy.value]: item })
    })
  })

  const onInputWrapper = useEventFnWrapper(onInput, _value => {
    const { [trackBy.value]: trackedValue } = _value
    const filteredValues = (value.value || []).filter(item => item !== trackedValue)
    return [ ...filteredValues, trackedValue ]
  })

  // replace placeholder with 'Search' when isFocus
  const inputPlaceholder = computed(() => {
    if (isFocus.value)
      return i18n.t('Search')
    return placeholder.value
  })

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
    inputPlaceholder,

    // useInput
    isFocus,
    onFocus,
    onBlur,

    multipleLabels,
    inputOptions,
    isLoading,
    onRemove,
    onSearch,
    showEmpty
  }
}

// @vue/component
export default {
  name: 'base-form-group-chosen-multiple-searchable',
  extends: BaseFormGroupChosenMultiple,
  props,
  setup
}
