<template>
  <b-card no-body>
    <b-card-header>
      <b-form>
        <b-input-group>
          <b-form-input v-model="filter" v-focus
            class="border-0" type="text" :placeholder="$t('Filter')" />
          <b-input-group-append v-if="filter">
            <b-btn @click="filter = ''"><icon name="times-circle" /></b-btn>
          </b-input-group-append>
        </b-input-group>
      </b-form>
    </b-card-header>
    <div class="card-body p-0 filtered-items">

      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectAll">{{ $i18n.t('All') }}</b-btn>
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectNone">{{ $i18n.t('None') }}</b-btn>
      <b-btn variant="link" size="sm" class="text-secondary"
        @click="onSelectInverse">{{ $i18n.t('Inverse') }}</b-btn>

      <b-row v-for="item in splitItems" :key="item.host"
        @click="onSelectItem(item)"
        align-h="end"
        align-v="center"
        :class="{
          'filter-selected': value.indexOf(item.host) > -1
        }"
        v-b-tooltip.hover.left.d300 :title="`.${item.host}`"
        >
        <b-col cols="1" class="px-0 py-1 ml-3 text-center">
          <template v-if="value.indexOf(item.host) > -1">
            <icon name="check-square" class="bg-white text-success" scale="1.125" />
          </template>
          <template v-else>
            <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
          </template>
        </b-col>
        <b-col cols="auto mr-auto" class="px-0 mr-3">
          <div class="d-inline align-items-center mr-1">
            <icon v-for="(icon, i) in item._tree" :key="i"
              v-bind="icon" />
          </div>
          <text-highlight :queries="[filter]">{{ item.host.split('.')[0] }}</text-highlight>
        </b-col>
        <b-col cols="auto mr-3">
          <b-badge class="ml-1">{{ uniqueCategories[item.host] }} {{ $i18n.t('categories') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueDevices[item.host] }} {{ $i18n.t('devices') }}</b-badge>
          <b-badge class="ml-1">{{ uniqueProtocols[item.host] }} {{ $i18n.t('protocols') }}</b-badge>
        </b-col>
      </b-row>


<pre>{{ {splitItems} }}</pre>

    </div>
  </b-card>
</template>

<script>
import TextHighlight from 'vue-text-highlight'
const components = {
  TextHighlight
}

import { focus } from '@/directives'
const directives = {
  focus
}

const props = {
  items: {
    type: Array
  },
  value: {
    type: Array
  }
}

import { computed, nextTick, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    items,
    value
  } = toRefs(props)

  const { emit } = context

  const uniqueItems = computed(() => {
    return Object.values(items.value)
      .reduce((unique, item) => {
        if (unique.filter(u => u.host === item.host).length === 0) {
          return [ ...unique, item ]
        }
        return unique
      }, [])
      .sort((a, b) => a.host.localeCompare(b.host))
  })

  const filter = ref('')

  const filteredItems = computed(() => {
    if (!filter.value) {
      return uniqueItems.value
    }
    return uniqueItems.value
      .filter(item => (item.host.toLowerCase().indexOf(filter.value.toLowerCase()) > -1))
  })

  const splitItems = computed(() => {
    const flattened = filteredItems.value
      .reduce((decompressed, item) => {
        const hosts = item.host.split('.').reverse()
        for (let i = 0; i < hosts.length; i++) {
            let host = hosts.slice(0, i + 1).reverse().join('.')
            if (decompressed.indexOf(host) == -1) {
              decompressed.push(host)
            }
        }
        return decompressed
      }, [])
      .sort((a, b) => {
        let _a = a.split('.').reverse()
        let _b = b.split('.').reverse()
        for (let i = 0; i < Math.max(_a.length, _b.length); i++) {
          if (i >= _a.length) {
            return -1
          }
          if (i >= _b.length) {
            return 1
          }
          if (_a[i] === _b[i]) {
            continue
          }
          return _a[i].localeCompare(_b[i])
        }
      })

    const depths = flattened.map(host => host.split('.').length - 1)
    let minDepth = 99
    const trees = Array(flattened.length).fill([])
    for (let i = flattened.length - 1; i >= 0; i--) {
      const depth = depths[i]
      let last = false
      if (minDepth > depth || depth > depths[i + 1]) {
        minDepth = Math.min(minDepth, depth)
        last = true
      }
      let tree = [
        ...Array(minDepth).fill({}),
        ...Array(depth - minDepth).fill({ pass: true }),
        { last, node: true }
      ]
      trees[i] = tree.map(({last, node, pass}) => {
        switch (true) {
          case last:
            return { last, pass, node, name: 'tree-last', class: 'nav-icon' }
            // break
          case node:
            return { last, pass, node, name: 'tree-node', class: 'nav-icon' }
            // break
          case pass:
            return { last, pass, node, name: 'tree-pass', class: 'nav-icon' }
            // break
          default: // empty
            return { last, pass, node, name: 'tree-skip', class: 'nav-icon' }
            // break
        }
      })
    }

    return flattened.map((host, i) => {
      const _depth = depths[i]
      const _depthNext = depths[i + 1]
      const _tree = trees[i]
      const _children = (_depth < _depthNext)
      return {
        host,
        _depth,
        _children,
        _tree
      }
    })
  })

  const onSelectItem = item => {
    const isSelected = value.value.findIndex(host => host === item.host)
    if (isSelected > -1) { // remove
      emit('input', [ ...value.value.filter(host => host !== value.value[isSelected]) ])
    }
    else { // insert
      emit('input', [ ...value.value, item.host ])
    }
  }

  const onSelectAll = () => {
    let selected = value.value
    splitItems.value.forEach((item) => {
      let i = selected.indexOf(item.host)
      if (i === -1) {
        selected = [ ...selected, item.host ]
      }
    })
    emit('input', selected)
  }

  const onSelectNone = () => {
    let selected = value.value
    splitItems.value.forEach((item) => {
      let i = selected.indexOf(item.host)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
    })
    emit('input', selected)
  }

  const onSelectInverse = () => {
    let selected = value.value
    splitItems.value.forEach((item) => {
      let i = selected.indexOf(item.host)
      if (i > -1) {
        selected = selected.filter((_, j) => j !== i)
      }
      else {
        selected = [ ...selected, item.host ]
      }
    })
    emit('input', selected)
  }

  const uniqueCategories = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { host, device_class } = item
      unique[host] = [ ...unique[host] || [], device_class ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, host) => {
      return { ...unique, [host]: assoc[host].length }
    }, {})
  })

  const uniqueDevices = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { host, mac } = item
      unique[host] = [ ...unique[host] || [], mac ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, host) => {
      return { ...unique, [host]: assoc[host].length }
    }, {})
  })

  const uniqueProtocols = computed(() => {
    const assoc = items.value.reduce((unique, item) => {
      const { host, proto, port } = item
      const protocol = `${proto}/${port}`
      unique[host] = [ ...unique[host] || [], protocol ]
      return unique
    }, {})
    return Object.keys(assoc).reduce((unique, host) => {
      return { ...unique, [host]: assoc[host].length }
    }, {})
  })

  return {
    filter,
    filteredItems,
    uniqueItems,
splitItems,
    onSelectItem,
    onSelectAll,
    onSelectNone,
    onSelectInverse,

    uniqueCategories,
    uniqueDevices,
    uniqueProtocols,
  }
}

// @vue/component
export default {
  name: 'base-filter-hosts',
  components,
  directives,
  props,
  setup
}
</script>

<style lang="scss">
$table-cell-height: 1.875 * $spacer !default;

.card {
  .row {
    .col-auto {
      svg.fa-icon:not(.nav-icon) {
        min-width: $table-cell-height;
        height: auto;
        max-height: $table-cell-height/2;
        margin: 0.25rem 0;
      }
      svg.nav-icon {
        height: $table-cell-height;
        color: $gray-500;
      }
    }
  }
}
</style>