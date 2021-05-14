<template>
  <div>
    <transition name="fade" mode="out-in">
      <div v-if="advancedMode">
        <b-form @submit.prevent="onSearchAdvanced" @reset.prevent="onSearchReset">
          <base-search-input-advanced
            v-model="conditionAdvanced"
            :disabled="isLoading"
            :fields="fields"
            @reset="onSearchReset"
            @search="onSearchAdvanced"
          />
          <b-container fluid class="text-right mt-3 px-0">
            <b-button class="ml-1" type="reset" variant="secondary" :disabled="isLoading">{{ $t('Clear') }}</b-button>
            <base-button-save-search
              save-search-namespace="tenants-advanced"
              class="ml-1"
              v-model="conditionAdvanced"
              :disabled="isLoading"
              @search="onSearchAdvanced"
            />
            <b-button class="ml-1" variant="outline-primary" @click="advancedMode = false"
              v-b-tooltip.hover.top.d300 :title="$t('Switch to basic search.')">
              <icon name="search-minus" />
            </b-button>
          </b-container>
        </b-form>
      </div>
      <div class="d-flex" v-else>
        <base-search-input-basic class="flex-grow-1"
          save-search-namespace="tenants-basic"
          v-model="conditionBasic"
          :disabled="isLoading"
          :placeholder="$t('Search by name or description')"
          @reset="onSearchReset"
          @search="onSearchBasic"
        />
        <b-button class="ml-1" variant="outline-primary" @click="advancedMode = true"
          v-b-tooltip.hover.top.d300 :title="$t('Switch to advanced search.')">
          <icon name="search-plus" />
        </b-button>
      </div>
    </transition>
    <b-row align-h="end" align-v="center">
      <b-col cols="auto" class="mr-auto my-3">
        <slot />
      </b-col>
      <b-col cols="auto" class="my-3">
        <b-container fluid>
          <b-row align-v="center">
            <base-search-input-limit
              v-model="limit"
              size="md"
              :limits="limits"
              :disabled="isLoading"
            />
            <base-search-input-page
              v-model="page"
              class="ml-3"
              :limit="limit"
              :total-rows="totalRows"
              :disabled="isLoading"
            />
            <base-button-export-csv
              size="md" class="ml-3"
              :filename="`${$route.path.slice(1).replace('/', '-')}.csv`"
              :disabled="isLoading"
              :columns="columns" :data="items"
            />
          </b-row>
        </b-container>
      </b-col>
    </b-row>
  </div>
</template>
<script>
import BaseButtonConfirm from './BaseButtonConfirm'
import BaseButtonExportCsv from './BaseButtonExportCsv'
import BaseButtonSaveSearch from './BaseButtonSaveSearch'
import BaseInputToggleAdvancedMode from './BaseInputToggleAdvancedMode'
import BaseSearchInputBasic from './BaseSearchInputBasic'
import BaseSearchInputAdvanced from './BaseSearchInputAdvanced'
import BaseSearchInputLimit from './BaseSearchInputLimit'
import BaseSearchInputPage from './BaseSearchInputPage'

const components = {
  BaseButtonConfirm,
  BaseButtonExportCsv,
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
  }
}

import { onMounted, ref, toRefs } from '@vue/composition-api'
import { useRouterQueryParam } from '@/composables/useRouter'

const setup = (props, context) => {

  const {
    useSearch
  } = toRefs(props)

  const search = useSearch.value()

  const {
    defaultCondition,
    doSearchCondition,
    doSearchString,
    doReset
  } = search

  // ref(router ?query=...)
  const { root: { $router } = {} } = context
  const routerQueryParam = useRouterQueryParam($router, 'query')

  const advancedMode = ref(false)
  const conditionBasic = ref(null)
  const conditionAdvanced = ref(defaultCondition()) // default

  onMounted(() => {
    if (routerQueryParam.value) {
      switch(routerQueryParam.value.constructor) {
        case Array: // advanced search
          conditionAdvanced.value = routerQueryParam.value
          advancedMode.value = true
          doSearchCondition(conditionAdvanced.value)
          break
        case String: // basic search
        default:
          conditionBasic.value = routerQueryParam.value
          advancedMode.value = false
          doSearchString(conditionBasic.value)
          break
      }
    }
    else
      doReset()
  })

  const onSearchBasic = () => {
    if (conditionBasic.value) {
      doSearchString(conditionBasic.value)
      routerQueryParam.value = conditionBasic.value
    }
    else
      doReset()
  }

  const onSearchAdvanced = () => {
    if (conditionAdvanced.value) {
      doSearchCondition(conditionAdvanced.value)
      routerQueryParam.value = conditionAdvanced.value
    }
    else
      doReset()
  }

  const onSearchReset = () => {
    conditionBasic.value = null
    conditionAdvanced.value = defaultCondition()
    routerQueryParam.value = undefined
    doReset()
  }

  return {
    advancedMode,
    conditionBasic,
    conditionAdvanced,
    onSearchBasic,
    onSearchAdvanced,
    onSearchReset,

    ...toRefs(search)
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