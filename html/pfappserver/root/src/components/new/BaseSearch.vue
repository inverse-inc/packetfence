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
            <b-button class="ml-1" type="reset" variant="secondary" :disabled="isLoading">{{ $t('Reset') }}</b-button>
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
          :placeholder="placeholderBasic"
          @reset="onSearchReset"
          @search="onSearchBasic"
        />
        <b-button class="ml-1" variant="outline-primary" @click="advancedMode = true"
          v-b-tooltip.hover.top.d300 :title="$t('Switch to advanced search.')">
          <icon name="search-plus" />
        </b-button>
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
          :disabled="isLoading"
        />
        <base-search-input-page
          :value="page" @input="setPage"
          class="ml-3"
          :limit="limit"
          :total-rows="totalRows"
          :disabled="isLoading"
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
  }
}

import { onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { toKebabCase } from '@/utils/strings'
import { usePreference } from '@/views/Configuration/_store/preferences'

const setup = (props) => {

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

  const saveSearch = usePreference(`search::${toKebabCase(uuid)}`)

  watch([columns, page, limit, sortBy, sortDesc], () => {
    Promise.resolve(saveSearch.value).then(_saveSearch => {
      saveSearch.value = {
        ..._saveSearch,
        columns: columns.value.filter(c => c.visible).map(c => c.key),
        page: page.value,
        limit: limit.value,
        sortBy: sortBy.value,
        sortDesc: sortDesc.value
      }
    })
  })

  const advancedMode = ref(false)
  const conditionBasic = ref(null)
  const conditionAdvanced = ref(defaultCondition().values) // default

  onMounted(() => {
    Promise.resolve(saveSearch.value).then(value => {
      if (value) {
        const {
          conditionAdvanced: _conditionAdvanced,
          conditionBasic: _conditionBasic
        } = value
        setUp(value)
        if (_conditionAdvanced) {
          conditionAdvanced.value = _conditionAdvanced
          advancedMode.value = true
          doSearchCondition(conditionAdvanced.value)
        }
        else {
          conditionBasic.value = _conditionBasic || ''
          advancedMode.value = false
          doSearchString(conditionBasic.value)
        }
      }
      else
        doReset()
    })
  })

  const onSearchBasic = () => {
    if (conditionBasic.value) {
      doSearchString(conditionBasic.value)
      Promise.resolve(saveSearch.value).then(_saveSearch => {
        const { conditionAdvanced, ...rest } = _saveSearch || {}
        saveSearch.value = { ...rest, conditionBasic: conditionBasic.value }
      })
    }
    else
      doReset()
  }

  const onSearchAdvanced = () => {
    if (conditionAdvanced.value) {
      doSearchCondition(conditionAdvanced.value)
      Promise.resolve(saveSearch.value).then(_saveSearch => {
        const { conditionBasic, ...rest } = _saveSearch || {}
        saveSearch.value = { ...rest, conditionAdvanced: conditionAdvanced.value }
      })
    }
    else
      doReset()
  }

  const onSearchReset = () => {
    conditionBasic.value = null
    conditionAdvanced.value = defaultCondition().values
    setPage(1)
    Promise.resolve(saveSearch.value).then(_saveSearch => {
      const { conditionAdvanced, conditionBasic, ...rest } = _saveSearch || {}
      saveSearch.value = rest
    })
    doReset()
  }

  return {
    advancedMode,
    conditionBasic,
    conditionAdvanced,
    onSearchBasic,
    onSearchAdvanced,
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