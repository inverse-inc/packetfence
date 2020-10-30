import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useEventFnWrapper from '@/composables/useEventFnWrapper'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import BaseInputChosen, { props as BaseInputChosenProps } from './BaseInputChosen'
import apiCall from '@/utils/api'

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

  const {
    lookup
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)
  const {
    label,
    trackBy,
    placeholder
  } = toRefs(metaProps)

  const {
    value,
    onInput
  } = useInputValue(metaProps, context)

  const currentValueOptions = ref([])
  const currentValueLoading = ref(false)
  let lastCurrentPromise = 0 // only use latest of 1+ promises
  watch(value, value => {
    if (!value)
      currentValueOptions.value = []
    else {
      const { field_name: fieldName, search_path: url, value_name: valueName } = lookup.value
      currentValueLoading.value = true
      const thisCurrentPromise = ++lastCurrentPromise
      apiCall.request({
        url,
        method: 'post',
        baseURL: '', // reset
        data: {
          query: { op: 'and', values: [{ op: 'or', values: [{ field: valueName, op: 'equals', value }] }] },
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

  const singleLabel = computed(() => {
    const _options = unref(currentValueOptions)
    const optionsIndex = _options.findIndex(option => {
      const { [unref(trackBy)]: trackedValue } = option
      return trackedValue === unref(value)
    })
    if (optionsIndex > -1)
      return _options[optionsIndex][unref(label)]
    else
      return unref(value)
  })

  const searchResultLoading = ref(false)
  const searchResultOptions = ref([])
  let lastSearchPromise = 0 // only use latest of 1+ promises
  let searchDebouncer
  const onSearch = (value) => {
    const { field_name: fieldName, search_path: url, value_name: valueName } = lookup.value
    searchResultLoading.value = true
    if (!searchDebouncer)
      searchDebouncer = createDebouncer()
    searchDebouncer({
      handler: () => {
        const thisSearchPromise = ++lastSearchPromise
        apiCall.request({
          url,
          method: 'post',
          baseURL: '', // reset
          data: {
            query: { op: 'and', values: [{ op: 'or', values: [{ field: fieldName, op: 'contains', value }] }] },
            fields: [fieldName, valueName],
            sort: [fieldName],
            cursor: 0,
            limit: 1
          }
        }).then(response => {
          if (thisSearchPromise === lastSearchPromise) { // ignore slow responses
            const { data: { items = [] } = {} } = response
            searchResultOptions.value = items.map(item => {
              const { [fieldName]: _field, [valueName]: _value } = item // unmap lookup field_name/value_name
              return { [label.value]: _field, [trackBy.value]: _value } // remap label/trackBy
            })
          }
        }).finally(() => {
          searchResultLoading.value = false
        })
      },
      time: 300
    })
  }

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
    else
      return placeholder.value
  })

  const onInputWrapper = useEventFnWrapper(onInput, value => {
    const { [unref(trackBy)]: trackedValue } = value
    return trackedValue
  })

  return {
    // wrappers
    inputValue: inputValueWrapper,
    onInput: onInputWrapper,
    inputPlaceholder: placeholderWrapper,

    singleLabel,
    inputOptions,
    isLoading,
    onSearch
  }
}

// @vue/component
export default {
  name: 'base-input-chosen-one-searchable',
  extends: BaseInputChosen,
  props,
  setup
}
