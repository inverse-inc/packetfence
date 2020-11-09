import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInput } from '@/composables/useInput'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import BaseInputChosen, { props as BaseInputChosenProps } from './BaseInputChosen'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'

export const props = {
  ...BaseInputChosenProps,

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
    lookup,
    trackBy,
    options,
    optionsLimit
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

  const currentValueOptions = ref(options.value) // use default options
  const currentValueLoading = ref(false)
  let lastCurrentPromise = 0 // only use latest of 1+ promises
  watch([value, lookup], (...args) => {
    if (!value.value || !lookup.value)
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
          query: { op: 'and', values: [{ op: 'or', values: [{ field: valueName, op: 'equals', value: value.value }] }] },
          fields: [fieldName, valueName],
          sort: [fieldName],
          cursor: 0,
          limit: 1
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
  }, { immediate: true })

  const showEmpty = ref(false)
  const searchResultLoading = ref(false)
  const searchResultOptions = ref([])
  let lastSearchPromise = 0 // only use latest of 1+ promises
  let searchDebouncer
  let lastSearchQuery

  const _doSearch = (query) => {
    if (!query.trim()) { // query is empty
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
            limit: optionsLimit.value - 1
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

  const inputValueWrapper = computed(() => {
    const _value = unref(value)
    const _options = unref(inputOptions)
    const optionsIndex = _options.findIndex(option => option[unref(trackBy)] === _value)
    if (optionsIndex > -1) {
      return _options[optionsIndex]
    }
    else {
      return { [unref(label)]: _value, [unref(trackBy)]: _value }
    }
  })

  // backend may use trackBy (value) as a placeholder w/ meta,
  //  use inputOptions to remap it to label (text).
  const placeholderWrapper = computed(() => {
    const _options = unref(inputOptions)
    const optionsIndex = _options.findIndex(option => {
      const { [trackBy.value]: trackedValue } = option
      return `${trackedValue}` === `${placeholder.value}`
    })
    if (optionsIndex > -1)
      return _options[optionsIndex][label.value]
    else if (isFocus.value)
      return i18n.t('Search')
    else
      return placeholder.value
  })

  const onInputWrapper = useEventFnWrapper(onInput, value => {
    const { [unref(trackBy)]: trackedValue } = value
    return trackedValue
  })

  const singleLabel = computed(() => {
    const _options = unref(currentValueOptions)
    const optionsIndex = _options.findIndex(option => {
      const { [unref(trackBy)]: trackedValue } = option
      return trackedValue === unref(value)
    })
    if (optionsIndex > -1)
      return _options[optionsIndex][unref(label)]
    else if (currentValueLoading.value)
      return '...'
    else
      return unref(value)
  })

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
    inputPlaceholder: placeholderWrapper,

    // useInput
    isFocus,
    onFocus,
    onBlur,

    singleLabel,
    inputOptions,
    isLoading,
    onSearch,
    showEmpty
  }
}

// @vue/component
export default {
  name: 'base-input-chosen-one-searchable',
  extends: BaseInputChosen,
  props,
  setup
}
