import { computed, ref, unref, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import apiCall, { baseURL as apiBaseURL } from '@/utils/api'
import i18n from '@/utils/locale'

export const useInputMultiselectProps = {
  id: {
    type: [Number, String]
  },
  options: {
    type: [Array, Promise],
    default: () => ([])
  },
  multiple: {
    type: Boolean,
    default: false
  },
  trackBy: {
    type: String,
    default: 'value'
  },
  label: {
    type: String,
    default: 'text'
  },
  searchable: {
    type: Boolean,
    default: true
  },
  clearOnSelect: {
    type: Boolean,
    default: true
  },
  hideSelected: {
    type: Boolean,
    default: false
  },
  allowEmpty: {
    type: Boolean,
    default: true
  },
  resetAfter: {
    type: Boolean,
    default: false
  },
  closeOnSelect: {
    type: Boolean,
    default: true
  },
  customLabel: {
    type: [Function, String]
  },
  taggable: {
    type: Boolean,
    default: false
  },
  tagPlaceholder: {
    type: String,
    default: i18n.t('Press enter to select this value')
  },
  tagPosition: {
    type: String,
    default: 'top'
  },
  max: {
    type: [Number, String],
    default: 1000
  },
  optionsLimit: {
    type: [Number, String],
    default: 1000
  },
  groupValues: {
    type: String
  },
  groupLabel: {
    type: String
  },
  groupSelect: {
    type: Boolean,
    default: false
  },
  internalSearch: {
    type: Boolean,
    default: false
  },
  preserveSearch: {
    type: Boolean,
    default: false
  },
  caseSensitiveSearch: {
    type: Boolean,
    default: false
  },
  preselectFirst: {
    type: Boolean,
    default: false
  },
  name: {
    type: String,
    default: ''
  },
  selectLabel: {
    type: String,
    default: i18n.t('') // Press enter to select
  },
  selectGroupLabel: {
    type: String,
    default: i18n.t('') // Press enter to select group
  },
  selectedLabel: {
    type: String,
    default: i18n.t('') // Selected
  },
  deselectLabel: {
    type: String,
    default: i18n.t('') // Press enter to remove
  },
  deselectGroupLabel: {
    type: String,
    default: i18n.t('') // Press enter to deselect group
  },
  showLabels: {
    type: Boolean,
    default: true
  },
  limit: {
    type: [Number, String],
    default: 1000
  },
  limitText: {
    type: [Function, String],
    default: count => i18n.t('and {count} more', { count })
  },
  openDirection: {
    type: String,
    default: ''
  },
  showPointer: {
    type: Boolean,
    default: true
  }
}

const BOOL_KEY_LOOKUP = true
const BOOL_QUERY_LOOKUP = false

// support Promise based options,
//  transform Promise to Vue ref to avoid redundant async handling later
export const useOptionsPromise = (optionsPromise, label) => {
  const options = ref([])
  watch([optionsPromise, () => i18n.locale], () => {
    Promise.resolve(optionsPromise.value).then(_options => {
      options.value = _options.map(option => {
        const { [label.value]: _label, ...rest } = option
        return { ...rest, [label.value]: i18n.t(_label) } // translate label
      })
    }).catch(() => {
      options.value = []
    })
  }, { immediate: true, deep: true })
  return options
}

// supersede VueMultiselect internal search
//  implement search from/to options using label
export const useOptionsSearch = (_options, _label, groupLabel, groupValues, caseSensitive = false) => {
  const query = ref(null)
  const onSearch = _query => {
    query.value = _query
  }
  const options = computed(() => {
    if (query.value) {
      if (groupLabel.value || groupValues.value) { // grouped search
        return _options.value.reduce((reduced = [], option) => {
          const { [groupLabel.value]: group, [groupValues.value]: options } = option
          if ((caseSensitive)
            ? group.includes(query.value)
            : group.toLowerCase().includes(query.value.toLowerCase())
          ) {
            reduced = [ ...reduced, option ]
          }
          else {
            const filtered = options.filter(option => {
              const { [_label.value]: label } = option
              return (caseSensitive)
                ? label.includes(query.value)
                : label.toLowerCase().includes(query.value.toLowerCase())
            })
            if (filtered.length > 0) {
              reduced = [ ...reduced, { [groupLabel.value]: group, [groupValues.value]: filtered } ]
            }
          }
          return reduced
        }, [])
      }
      else { // non-grouped search
        return _options.value.filter(option => {
          const { [_label.value]: label } = option
          return (caseSensitive)
            ? label.includes(query.value)
            : label.toLowerCase().includes(query.value.toLowerCase())
        })
      }
    }
    return _options.value
  })
  return {
    options,
    onSearch
  }
}

export const useSingleValueLookupOptions = (value, onInput, lookup, options, optionsLimit, trackBy, label) => {

  const currentValueOptions = ref([])
  const currentValueLoading = ref(false)
  let lastCurrentPromise = 0 // only use latest of 1+ promises

  watch([value, lookup], (...args) => {
    if (!value.value || !lookup.value) {
      currentValueOptions.value = []
      return
    }

    // avoid (re)lookup when watch is triggered without value change
    //  false-positives occur when parent array pushes/pops siblings
    const { 0: { 0: newValue, 1: newLookup } = {}, 1: { 0: oldValue, 1: oldLookup } = {} } = args
    if (newValue === oldValue && JSON.stringify(newLookup) === JSON.stringify(oldLookup))
      return // These are not the droids you're looking for...

    currentValueLoading.value = true
    const thisCurrentPromise = ++lastCurrentPromise

    if (lookup.value.constructor === Function) { // handle lookup Function (manual)
      Promise.resolve(lookup.value(value.value, BOOL_KEY_LOOKUP))
        .then(options => {
          if (thisCurrentPromise === lastCurrentPromise) // ignore slow responses
            currentValueOptions.value = options
        })
        .finally(() => {
          currentValueLoading.value = false
        })
    }
    else { // handle lookup Object (automatic)
      const { field_name: fieldName, search_path: url, value_name: valueName, base_url: baseURL } = lookup.value
      apiCall.request({
        url,
        method: 'post',
        baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
        data: {
          query: {
            op: 'and', values: [{
              op: 'or',
              values: [{ field: valueName, op: 'equals', value: value.value }]
            }]
          },
          fields: [...new Set([fieldName, valueName])],
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
      searchResultOptions.value = []
      return
    }
    searchResultLoading.value = true
    if (!searchDebouncer)
      searchDebouncer = createDebouncer()
    if (lookup.value.constructor === Function) { // handle lookup Function (manual)
      searchDebouncer({
        handler: () => {
          const thisSearchPromise = ++lastSearchPromise
          Promise.resolve(lookup.value(query, BOOL_QUERY_LOOKUP))
          .then(options => {
            if (thisSearchPromise === lastSearchPromise) // ignore slow responses
              searchResultOptions.value = options
          })
          .finally(() => {
            searchResultLoading.value = false
          })
        },
        time: 300
      })
    }
    else { // handle lookup Object (automatic)
      const { field_name: fieldName, search_path: url, value_name: valueName, base_url: baseURL } = lookup.value
      searchDebouncer({
        handler: () => {
          const thisSearchPromise = ++lastSearchPromise
          // split query by space(s)
          const values = query
            .trim() // trim outside whitespace
            .split(' ') // separate terms by space
            .filter(q => q) // ignore multiple spaces
            .map(query => ({ op: 'or', values: [{ field: valueName, op: 'contains', value: query }, { field: fieldName, op: 'contains', value: query }] }))

          apiCall.request({
            url,
            method: 'post',
            baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
            data: {
              query: { op: 'and', values },
              fields: [...new Set([fieldName, valueName])],
              sort: [fieldName],
              cursor: 0,
              limit: optionsLimit.value - 1
            }
          }).then(response => {
            if (thisSearchPromise === lastSearchPromise) { // ignore late responses from earlier reqs
              const { data: { items = [] } = {} } = response
              searchResultOptions.value = items.map(item => {
                const { [fieldName]: _field, [valueName]: _value } = item // unmap lookup field_name/value_name
                return { [label.value]: `${_field} (${_value})`, [trackBy.value]: _value } // remap label/trackBy
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
  }

  const onRemove = () => onInput()

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

  const mergedOptions = computed(() => {
    let unique = []
    return [
      ...Array.prototype.slice.call([ // dereference for sort
        ...currentValueOptions.value,
        ...searchResultOptions.value
      ]).sort((...pair) => { // sort alpha
        const { 0: { [label.value]: labelA } = {}, 1: { [label.value]: labelB } = {} } = pair
        return labelA.localeCompare(labelB)
      }),
      ...((lastSearchQuery)
        ? [] // omit prop options
        : options.value // inc prop options
      ),
    ].filter(option => { // force unique (via trackBy)
      const { [trackBy.value]: tracked } = option
      if (unique.includes(tracked))
        return false
      unique.push(tracked)
      return true
    })
  })

  return {
    options: mergedOptions,
    isLoading,
    onRemove,
    onSearch,
    showEmpty
  }
}

export const useMultipleValueLookupOptions = (value, onInput, lookup, options, optionsLimit, trackBy, label) => {

  const currentValueOptions = ref([])
  const currentValueLoading = ref(false)
  let lastCurrentPromise = 0 // only use latest of 1+ promises

  watch([value, lookup], (...args) => {
    if (!value.value || value.value.length === 0 || !lookup.value) {
      currentValueOptions.value = []
      return
    }
    // avoid (re)lookup when watch is triggered without value change
    //  false-positives occur when parent array pushes/pops siblings
    const { 0: { 0: newValue, 1: newLookup } = {}, 1: { 0: oldValue, 1: oldLookup } = {} } = args
    if (newValue === oldValue && JSON.stringify(newLookup) === JSON.stringify(oldLookup))
      return // These are not the droids you're looking for...

    const { field_name: fieldName, search_path: url, value_name: valueName, base_url: baseURL } = lookup.value
    currentValueLoading.value = true
    const thisCurrentPromise = ++lastCurrentPromise
    apiCall.request({
      url,
      method: 'post',
      baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
      data: {
        query: { op: 'and', values: [{
          op: 'or',
          values: value.value.map(value => ({ field: valueName, op: 'equals', value }))
        }] },
        fields: [...new Set([fieldName, valueName])],
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
  }, { immediate: true, deep: true })

  const searchResultLoading = ref(false)
  const searchResultOptions = ref([])
  const showEmpty = ref(false)
  let lastSearchPromise = 0 // only use latest of 1+ promises
  let searchDebouncer
  let lastSearchQuery

  const _doSearch = (query) => {
    if (!query) { // query is empty
      searchResultOptions.value = []
      return
    }
    const { field_name: fieldName, search_path: url, value_name: valueName, base_url: baseURL } = lookup.value
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
          baseURL: (baseURL || baseURL === '') ? baseURL : apiBaseURL,
          data: {
            query: { op: 'and', values },
            fields: [...new Set([fieldName, valueName])],
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

  const mergedOptions = computed(() => {
    let unique = []
    return [
      ...Array.prototype.slice.call([ // dereference for sort
        ...currentValueOptions.value,
        ...searchResultOptions.value
      ]).sort((...pair) => { // sort alpha
        const { 0: { [label.value]: labelA } = {}, 1: { [label.value]: labelB } = {} } = pair
        return labelA.localeCompare(labelB)
      }),
      ...((lastSearchQuery)
        ? [] // omit prop options
        : options.value // inc prop options
      ),
    ].filter(option => { // force unique (via trackBy)
      const { [trackBy.value]: tracked } = option
      if (unique.includes(tracked))
        return false
      unique.push(tracked)
      return true
    })
  })

  return {
    options: mergedOptions,
    isLoading,
    onRemove,
    onSearch,
    showEmpty
  }
}

// backend specifies `placeholder` in meta using `trackBy`, not `label`
//  use options to remap `trackBy` to `label`.
export const useOptionsValue = (options, trackBy, label, groupValues, value, isFocus, isLoading) => computed(() => {
  let _options
  if (groupValues.value) {
    _options = unref(options).reduce((options, group) => {
      return [...options, ...group[groupValues.value] ]
    }, [])
  }
  else {
    _options = unref(options)
  }
  const optionsIndex = _options.findIndex(option => {
    const { [trackBy.value]: trackedValue } = option
    return `${trackedValue}` === `${value.value}`
  })
  if (optionsIndex > -1)
    return _options[optionsIndex][label.value]
  else if (isLoading && isLoading.value)
    return '...'
  else if (isFocus && isFocus.value && !value.value)
    return i18n.t('Search')
  else
    return value.value
})

