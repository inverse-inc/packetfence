<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right">
        <base-input-toggle-advanced-mode
          v-model="advancedMode"
          :disabled="isLoading"
          label-left
        />
      </div>
      <h4 class="mb-0">
        {{ $t('Roles') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_introduction_to_role_based_access_control" />
      </h4>
    </b-card-header>    
    <div class="card-body">
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
              <b-button class="mr-1" type="reset" variant="secondary" :disabled="isLoading">{{ $t('Clear') }}</b-button>
              <base-button-save-search 
                save-search-namespace="roles-advanced" 
                v-model="conditionAdvanced"
                :disabled="isLoading"
                @search="onSearchAdvanced"
              />
            </b-container>
          </b-form>
        </div>
        <base-search-input-basic v-else
          save-search-namespace="roles-basic"
          v-model="conditionBasic"
          :disabled="isLoading"
          :placeholder="$t('Search by name or description')"
          @reset="onSearchReset"
          @search="onSearchBasic"
        />
      </transition>
    </div>
    <div class="card-body pt-0">
      <b-row>
        <b-col cols="auto" class="mr-auto mb-3">
          <b-button variant="outline-primary" :to="{ name: 'newRole' }">{{ $t('New Role') }}</b-button>
        </b-col>
      </b-row>
      <b-row align-h="end" align-v="center">
        <b-col>
          <base-search-input-columns 
            v-model="columns"
            :disabled="isLoading"
          />
        </b-col>
        <b-col cols="auto">
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
                :limit="limit"
                :total-rows="totalRows"
                :disabled="isLoading"
              />
              <base-button-export-csv 
                class="mb-3" size="md"
                :filename="`${$route.path.slice(1).replace('/', '-')}.csv`" 
                :disabled="isLoading"
                :columns="columns" :data="itemsTree"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table
        class="the-tree-list"
        :busy="isLoading"
        :hover="itemsTree.length > 0"
        :items="itemsTree"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="onSortChanged"
        @row-clicked="onRowClicked"
        show-empty
        small
        borderless
        responsive
        no-local-sorting
        sort-icon-left
        fixed
        striped
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
              <pf-empty-table :is-loading="isLoading">{{ $t('No results found') }}</pf-empty-table>
          </slot>
        </template>
        <template v-slot:cell(id)="{ item }">
          <icon v-for="(icon, i) in item._tree" :key="i"
            v-bind="icon" /> 
          <b-link v-if="item.children"
            :class="(collapsedRoles.includes(item.id)) ? 'text-danger' : 'text-secondary'"
             @click.stop="onToggleRole(item.id)"
          >
            <icon v-bind="item._icon" />       
          </b-link>
          <icon v-else
            v-bind="item._icon" />       
          {{ item.id }} 
        </template>
        <template v-slot:cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Role?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="onClone(item.id)">{{ $t('Clone') }}</b-button>
            <b-button v-if="isInline" size="sm" variant="outline-primary" class="mr-1" :to="trafficShapingRoute(item.id)">{{ $t('Traffic Shaping') }}</b-button>
          </span>
        </template>        
      </b-table>
      <b-modal v-model="showDeleteErrorsModal" size="lg"
        centered lazy scrollable
        :no-close-on-backdrop="isLoading"
        :no-close-on-esc="isLoading"
      >
        <template v-slot:modal-title>
          {{ $t('Delete Role') }} <b-badge variant="secondary">{{ deleteId }}</b-badge>
        </template>
        <b-media no-body class="alert alert-danger">
          <template v-slot:aside>
            <icon name="exclamation-triangle" scale="2"/>
          </template>
          <div class="mx-2">{{ $t('The role could not be deleted. Either manually handle the following errors and try again, or re-reassign the resources to another existing role.') }}</div>
        </b-media>
        <h5>{{ $t('Role is still in use for:') }}</h5>
        <b-row v-for="error in deleteErrors" :key="error.reason">
          <b-col cols="auto" class="mr-auto">{{ reasons[error.reason] }}</b-col>
          <b-col cols="auto">{{ error.reason }}</b-col>
        </b-row>
        <template v-slot:modal-footer>
          <b-row class="w-100">
            <b-col cols="auto" class="mr-auto pl-0">
              <b-form-select size="sm" class="d-inline"
                v-model="reassignRole"
                :options="reassignableRoles"
              />
              <b-button size="sm" class="ml-1" variant="outline-primary"  @click="reAssign()" :disabled="isLoading">{{ $i18n.t('Reassign Role') }}</b-button>
            </b-col>
            <b-col cols="auto" class="pr-0">
              <b-button variant="secondary"  @click="showDeleteErrorsModal = false" :disabled="isLoading">{{ $i18n.t('Fix Manually') }}</b-button>
            </b-col>
          </b-row>
        </template>
      </b-modal>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
} from '@/components/new/'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  pfButtonHelp,
  pfEmptyTable
}

import { computed, onMounted, ref } from '@vue/composition-api'
import { useSearch, useRouter } from '@/views/Configuration/roles/_composables/useCollection'
import { reasons } from '../config'

const defaultCondition = () => ([{ values: [{ field: 'parent_id', op: 'equals', value: null }] }])

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const advancedMode = ref(false)
  const conditionBasic = ref(null)
  const conditionAdvanced = ref(defaultCondition()) // default
  const search = useSearch(props, context)
  const {
    doReset,
    doSearchString,
    doSearchCondition,
    reSearch,
    items,
    sortBy,
    sortDesc
  } = search

  const collapsedRoles = ref([])
  const _clearExpandedRoles = () => { collapsedRoles.value = [] }
  const _expandRole = id => {
    collapsedRoles.value = collapsedRoles.value.filter(expanded => expanded !== id)
  }
  const _collapseRole = id => {
    if (!collapsedRoles.value.includes(id))
      collapsedRoles.value = [ ...collapsedRoles.value, id ]
  }
  const onToggleRole = id => {
    if (collapsedRoles.value.includes(id))
      _expandRole(id)
    else
      _collapseRole(id)
  }

  const _sortFn =(a, b) => {
    const sortMod = ((sortDesc.value) ? -1 : 1)
    const { [sortBy.value]: sortByA, id: idA, parent_id: parentIdA } = a 
    const { [sortBy.value]: sortByB, id: idB, parent_id: parentIdB } = b
    if (parentIdA === parentIdB)
      return sortByA.toString().localeCompare(sortByB.toString()) * sortMod
    else {
      if (parentIdA === idB)
        return 1 // always show before
      else if (parentIdB === idA)
        return -1 // always show after
    }
    return 0 // use natural
  }  

  const _flattenFamilies = (_families) => {
    return _families.reduce((families, family) => {
      let { _children, ..._family } = family
      if (_children) {
        const children = _flattenFamilies(_children)
          .sort(_sortFn)
        if (children.length > 0)
          children[children.length - 1]._last = true // mark _last
        return [ ...families, _family, ...children ]
      }
      return [ ...families, _family ]
    }, [])
  }

  const itemsTree = computed(() => {
    const _items = items.value

    // build associative array for lookups
    const associative = _items.reduce((items, item) => {
      const { id } = item
      const _item = { 
        ...item, 
        _children: [], // post-processed
        _match: true // found in search
      }
      return { ...items, [id]: _item }
    }, {})

    // an item only seen as `parent_id` or `children`, not `id`
    const GHOST = {
      _children: [], // post-processed
      _match: false, // not found in search
      _rowVariant: 'row-disabled', // CSSable
      not_deletable: true // defer uncertainty
    }

    // track depth for later processing
    let maxDepth = 0

    // helper: calculate inherent tree depth(s)
    const _getDepth = (id) => {
      let depth = 0 // not exists
      if (id in associative) { // exists
        const { parent_id, children } = associative[id]
        if (parent_id && parent_id in associative)
          depth = _getDepth(parent_id) + 1
        else if (parent_id) {
          associative[parent_id] = { 
            id: parent_id,
            children: [id], 
            _depth: 0, 
            ...GHOST
          } // push ghost parent
          depth = 1
        }
        else
          depth = 0 // root
        // opportunistic ghost children handling
        if (children) {
          children.forEach(child => {
            if (!(child in associative)) {
              associative[child] = {
                id: child,
                parent_id: id,
                children: [],
                _depth: depth + 1,
                ...GHOST
              } // push ghost child
              maxDepth = Math.max(maxDepth, depth + 1) // post-process hint
            }
          })
        }
      }
      return depth
    }

    // append inherent depth to all items
    Object.values(associative).forEach(item => {
      const { id } = item
      const depth = _getDepth(id)
      maxDepth = Math.max(maxDepth, depth)
      associative[id]._depth = depth
    })

    // reorganize by family, associate children
    for(let m = maxDepth; m > 0; m--) {
      Object.values(associative)
        .filter(({ _depth }) => _depth === m)
        .forEach(item => {
          const { parent_id } = item
          if (!collapsedRoles.value.includes(parent_id)) // ignore collapsed parent
            associative[parent_id]._children.push(item)
        })
    }

    // organize families
    const families = Object.values(associative)
      .filter(({ _depth }) => _depth === 0) // truncate 
      .sort(_sortFn) // sort root families

    // flatten families
    const flattened = _flattenFamilies(families)

    // decorate items
    const decorated = flattened      
      .map(item => {
        const { children = [], _depth, _last } = item || {}
        let _tree = []
        if (_depth > 0) {
          _tree.push(
            ...(
              new Array(_depth - 1).fill(null)
                .map(() => ({
                  name: 'tree-pass', class: 'nav-icon'
                }))
            ),
            ...((_last)
              ? [{ name: 'tree-last', class: 'nav-icon' }]
              : [{ name: 'tree-node', class: 'nav-icon' }]
            )
          )
        }
        const _icon = ((children && children.length)
          ? { name: 'user-plus', class: 'ml-1 text-black' }
          : { name: 'user', class: 'text-black-50' }
        )
        return { ...item, _tree, _icon }
      })
    return decorated
  })

  onMounted(() => {
    const { currentRoute: { query: { query } = {} } = {} } = $router
    if (query) { 
      const parsedQuery = JSON.parse(query)
      switch(parsedQuery.constructor) {
        case Array: // advanced search
          conditionAdvanced.value = parsedQuery
          advancedMode.value = true
          doSearchCondition(conditionAdvanced.value)
          break
        case String: // basic search
        default:
          conditionBasic.value = parsedQuery
          advancedMode.value = false
          doSearchString(conditionBasic.value)
          break
      }
    }
    else
      doReset()
  })

  const _setQueryParam = query => {
    const { currentRoute } = $router
    $router.replace({ ...currentRoute, query: { query } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }
  const _clearQueryParam = () => _setQueryParam()

  const onSearchBasic = () => {
    _clearExpandedRoles()
    if (conditionBasic.value) {
      doSearchString(conditionBasic.value)
      _setQueryParam(JSON.stringify(conditionBasic.value))
    }
    else
      doReset()
  }

  const onSearchAdvanced = () => {
    _clearExpandedRoles()
    if (conditionAdvanced.value) {
      doSearchCondition(conditionAdvanced.value)
      _setQueryParam(JSON.stringify(conditionAdvanced.value))
    }
    else
      doReset()
  }

  const onSearchReset = () => {
    conditionBasic.value = null
    conditionAdvanced.value = defaultCondition() // dereference
    _clearQueryParam()
    _clearExpandedRoles()
    doReset()
  }

  const onRowClicked = item => {
    const {
      goToItem
    } = useRouter(props, context)
    goToItem(item.id)
  }

  const onClone = id => {
    $router.push({ name: 'cloneRole', params: { id } })
  }

  const deleteId = ref(null)
  const deleteErrors = ref(null)
  const showDeleteErrorsModal = ref(false)
  const onRemove = id => {
    $store.dispatch('$_roles/deleteRole', id)
      .then(() => reSearch())
      .catch(error => {
        const { response: { data: { errors = [] } = {} } = {} } = error
        if (errors.length) {
          deleteId.value = id
          deleteErrors.value = errors
          showDeleteErrorsModal.value = true
        }
      })
  }

  const reassignRole = ref('default')
  const reassignableRoles = computed(() => {
    return items.value
      .filter(role => role.id !== deleteId.value)
      .map(role => ({ text: role.id, value: role.id }))
  })
  const reAssign = () => {
    $store.dispatch('$_roles/reassignRole', { from: deleteId.value, to: reassignRole.value })
      .then(() => {
        showDeleteErrorsModal.value = false
        // cascade delete
        onRemove(deleteId.value)
      })
  }

  const _trafficShapingPolicies = ref([])
  $store.dispatch('$_traffic_shaping_policies/all')
    .then(response => {
      _trafficShapingPolicies.value = response.map(policy => policy.id)
    })

  const trafficShapingRoute = id => {
    return (_trafficShapingPolicies.value.includes(id))
      ? { name: 'traffic_shaping', params: { id } } // exists
      : { name: 'newTrafficShaping', params: { role: id } } // not exists
  }

  const isInline = computed(() => $store.getters['system/isInline'])

  return {
    advancedMode,
    conditionBasic,
    collapsedRoles,
    onToggleRole,
    onSearchBasic,
    conditionAdvanced,
    onSearchAdvanced,
    onSearchReset,
    onRowClicked,
    itemsTree,
    onClone,
    onRemove,
    deleteId,
    deleteErrors,
    showDeleteErrorsModal,    
    reassignRole,
    reassignableRoles,
    reasons,
    reAssign,
    trafficShapingRoute,
    isInline,
    ...search
  }
}

// @vue/component
export default {
  name: 'the-list',
  inheritAttrs: false,
  components,
  setup
}
</script>

<style lang="scss">
.the-tree-list {
  thead[role="rowgroup"] {
    border-bottom: 1px solid #dee2e6 !important;
  }
  tr[role="row"],
  tr[role="row"] > th[role="columnheader"] {
    cursor: pointer;
    outline-width: 0;
    td[role="cell"] {
      padding: 0 0.3rem;
      text-wrap: nowrap;
      div[variant="link"] {
        line-height: 1em;
      }
    }
    td[aria-colindex="1"] {
      svg.fa-icon:not(.nav-icon) {
        margin: 0.25rem 0;
        min-width: 36px;
        height: auto;
        max-height: 18px;
      }
      svg.nav-icon {
        color: $gray-500;
        height: 36px;
      }
    }
  }
  .table-row-disabled {
    opacity: 0.6;
  }
}
</style>