<template>
  <div>
    <transition name="fade" mode="out-in">
      <div v-if="advancedMode">
        <b-form @submit.prevent="onSearchAdvanced" @reset.prevent="onSearchReset">
          <base-search-input-advanced
            v-model="conditionAdvanced"
            :disabled="disabled || isLoading"
            :fields="fields"
            @search="onSearchAdvanced"
          />
          <b-container fluid class="text-right mt-3 px-0">
            <b-button class="ml-1" type="reset" variant="secondary" :disabled="disabled || isLoading">{{ $t('Reset') }}</b-button>
            <b-button-group>
              <base-button-save-search
                class="ml-1"
                v-model="conditionAdvanced"
                :disabled="disabled || isLoading"
                :save-search-namespace="`${uuid}::advancedSearch`"
                :use-search="useSearch"
                @search="onSearchAdvanced"
                @load="onLoadAdvanced"
              />
              <b-button variant="primary" :disabled="disabled || isLoading" @click="advancedMode = false"
                v-b-tooltip.hover.top.d300 :title="$t('Switch to basic search.')">
                <icon name="search-minus" />
              </b-button>
            </b-button-group>
          </b-container>
        </b-form>
      </div>
      <div class="d-flex" v-else>
        <base-search-input-basic class="flex-grow-1" :key="hint"
          v-model="conditionBasic"
          :disabled="disabled || isLoading"
          :title="titleBasic"
          :save-search-namespace="`${uuid}::basicSearch`"
          :use-search="useSearch"
          @reset="onSearchReset"
          @search="onSearchBasic"
        >
          <b-button variant="primary" :disabled="disabled || isLoading" @click="advancedMode = true"
            v-b-tooltip.hover.top.d300 :title="$t('Switch to advanced search.')">
            <icon name="search-plus" />
          </b-button>
        </base-search-input-basic>
      </div>
    </transition>
    <b-row align-h="end">
      <b-col cols="auto" class="mr-auto my-3">
        <slot />
      </b-col>
      <b-col cols="auto" class="my-3 align-self-end d-flex">
        <base-search-input-limit
          :value="limit" @input="setLimit"
          size="md"
          :limits="limits"
          :disabled="disabled || isLoading"
        />
        <base-search-input-page
          :value="page" @input="setPage"
          class="ml-3"
          :limit="limit"
          :total-rows="totalRows"
          :disabled="disabled || isLoading"
        />
      </b-col>
    </b-row>
  </div>
</template>
<script>
import BaseButtonConfirm from './BaseButtonConfirm'
import BaseButtonSaveSearch from './BaseButtonSaveSearch'
import BaseInputToggleAdvancedMode from './BaseInputToggleAdvancedMode'
import BaseSearchInputBasic from './BaseSearchInputBasic'
import BaseSearchInputAdvanced from './BaseSearchInputAdvanced'
import BaseSearchInputLimit from './BaseSearchInputLimit'
import BaseSearchInputPage from './BaseSearchInputPage'

const components = {
  BaseButtonConfirm,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputLimit,
  BaseSearchInputPage
}

const props = {
  useSearch: {
    type: Function
  },
  disabled: {
    type: Boolean
  }
}

import { onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { v4 as uuidv4 } from 'uuid'
import { useQuery } from '@/router'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    useSearch
  } = props
  const search = useSearch()

  const {
    uuid,
    setUp,
    setPage,
    defaultCondition,
    doSearchCondition,
    doSearchString,
    doReset
  } = search

  const {
    columns,
    page,
    limit,
    sortBy,
    sortDesc
  } = toRefs(search)

  const { emit, root: { $router, $store } = {} } = context

  const saveSearchNamespace = `${uuid}::defaultSearch`
  let saveSearchLoaded = false
  watch([columns, page, limit, sortBy, sortDesc], () => {
    if (!saveSearchLoaded)
      return
    $store.dispatch('preferences/get', saveSearchNamespace)
      .then(({ meta, ...value }) => {
        $store.dispatch('preferences/set', {
          id: saveSearchNamespace,
          value: {
            ...value,
            columns: columns.value.filter(c => c.visible).map(c => c.key),
            page: page.value,
            limit: limit.value,
            sortBy: sortBy.value,
            sortDesc: sortDesc.value
          }
        })
      })
  })

  const advancedMode = ref(false)
  const conditionBasic = ref(null)
  const conditionAdvanced = ref(defaultCondition()) // default
  const hint = ref(uuidv4())

  const query = useQuery()
  const _clearRouteQuery = () => {
    if (Object.keys(query.value).length) { // clear query
      const { currentRoute: { path } = {} } = $router
      $router.push({ path })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
    }
  }

  onMounted(() => {
    watch(query, () => {
      if (Object.keys(query.value).length) { // [1] use router query
        saveSearchLoaded = false
        try {
          const q = Object.keys(query.value).reduce((q, param) => {
            q[param] = JSON.parse(query.value[param])
            return q
          }, {})
          const { conditionBasic: _conditionBasic, conditionAdvanced: _conditionAdvanced, ...value } = q
          setUp(value)
          if (_conditionAdvanced) {
            conditionAdvanced.value = _conditionAdvanced
            conditionBasic.value = null
            advancedMode.value = true
            hint.value = uuidv4()
            return doSearchCondition(conditionAdvanced.value)
          }
          else if (_conditionBasic) {
            conditionAdvanced.value = defaultCondition()
            conditionBasic.value = _conditionBasic
            advancedMode.value = false
            hint.value = uuidv4()
            return doSearchString(conditionBasic.value)
          }
        } catch(e) {
          $store.dispatch('notification/danger', { message: i18n.t('URL query is malformed.'), url: e })
        }
        doReset()
      }
      else { // [2] use savedSearch
        $store.dispatch('preferences/get', saveSearchNamespace)
          .then(({ meta, ...value }) => {
            if (value) {
              const {
                conditionAdvanced: _conditionAdvanced,
                conditionBasic: _conditionBasic
              } = value
              setUp(value)
              if (_conditionAdvanced) {
                conditionAdvanced.value = _conditionAdvanced
                conditionBasic.value = null
                advancedMode.value = true
                hint.value = uuidv4()
                return doSearchCondition(conditionAdvanced.value)
              }
              else if (_conditionBasic) {
                conditionAdvanced.value = defaultCondition()
                conditionBasic.value = _conditionBasic
                advancedMode.value = false
                hint.value = uuidv4()
                return doSearchString(conditionBasic.value)
              }
            }
            doReset()
          })
          .finally(() => saveSearchLoaded = true)
      }
    }, { deep: true, immediate: true })
  })

  const onSearchBasic = () => {
    if (conditionBasic.value) {
      doSearchString(conditionBasic.value)
      $store.dispatch('preferences/get', saveSearchNamespace)
        .then(({ meta, ...value }) => {
          const { conditionAdvanced, ...rest } = value || {}
          $store.dispatch('preferences/set', { id: saveSearchNamespace, value: { ...rest, conditionBasic: conditionBasic.value } })
        })
        .finally(() => _clearRouteQuery())
    }
    else
      doReset()
    emit('basic', conditionBasic.value)
  }

  const onSearchAdvanced = () => {
    if (conditionAdvanced.value) {
      doSearchCondition(conditionAdvanced.value)
      $store.dispatch('preferences/get', saveSearchNamespace)
        .then(({ meta, ...value }) => {
          const { conditionBasic, ...rest } = value || {}
          $store.dispatch('preferences/set', { id: saveSearchNamespace, value: { ...rest, conditionAdvanced: conditionAdvanced.value } })
        })
        .finally(() => _clearRouteQuery())
    }
    else
      doReset()
    emit('advanced', conditionAdvanced.value)
  }

  const onLoadAdvanced = search => {
    const { currentRoute: { path } = {} } = $router
    const { id, query: conditionAdvanced, ...rest } = search // strip id, rename query
    const _query = { conditionAdvanced, ...rest }
    const query = Object.keys(_query).reduce((query, param) => {
      query[param] = JSON.stringify(_query[param])
      return query
    }, {})
    $router.push({ path, query })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }

  const onSearchReset = () => {
    conditionBasic.value = null
    conditionAdvanced.value = defaultCondition()
    setPage(1)
    $store.dispatch('preferences/get', saveSearchNamespace)
      .then(({ meta, ...value }) => {
        const { conditionAdvanced, conditionBasic, ...rest } = value || {}
        $store.dispatch('preferences/set', { id: saveSearchNamespace, value: rest })
      })
      .finally(() => _clearRouteQuery())
    doReset()
    emit('reset')
  }

  return {
    hint,
    uuid,
    advancedMode,
    conditionBasic,
    conditionAdvanced,
    onSearchBasic,
    onSearchAdvanced,
    onLoadAdvanced,
    onSearchReset,

    ...toRefs(search),
    columns
  }
}

// @vue/component
export default {
  name: 'base-search',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>