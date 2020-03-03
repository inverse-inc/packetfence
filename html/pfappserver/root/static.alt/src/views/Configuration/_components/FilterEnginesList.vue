<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Filter Engines'"></h4>

<pre>{{ JSON.stringify(collections, null, 2) }}</pre>

      </b-card-header>
      <b-card class="m-3" v-for="(collection, index) in collections" :key="index">
        <h4 class="mb-3">{{ collection.name }}</h4>
        <b-button class="mb-3" variant="outline-primary" :to="{ name: 'newFilterEngine', params: collection }">{{ $t('New Filter') }}</b-button>
        <pf-table-sortable
          :items="collection.items"
          :fields="columns"
          @row-clicked="view(collection, $event)"
          hover
          striped
          @end="sort(collection, $event)"
        >
          <template v-slot:empty>
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new filter.')">{{ $t('No filters defined') }}</pf-empty-table>
          </template>
          <template v-slot:cell(status)="item">
            <pf-form-range-toggle
              v-model="item.status"
              :values="{ checked: 'enabled', unchecked: 'disabled' }"
              :icons="{ checked: 'check', unchecked: 'times' }"
              :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
              :rightLabels="{ checked: $t('Enabled'), unchecked: $t('Disabled') }"
              :lazy="{ checked: enable(collection, item), unchecked: disable(collection, item) }"
              @click.stop.prevent
            />
          </template>
          <template v-slot:cell(buttons)="item">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Filter?')" @on-delete="remove(item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(collection, item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </pf-table-sortable>
      </b-card>
    </b-card>
  </div>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfTableSortable from '@/components/pfTableSortable'
import { columns } from '../_config/filterEngine'

export default {
  name: 'filter-engines-list',
  components: {
    pfButtonDelete,
    pfEmptyTable,
    pfFormRangeToggle,
    pfTableSortable
  },
  data () {
    return {
      columns, // ../_config/filterEngines
      collections: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_filter_engines/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_filter_engines/getCollections').then(collections => {
        for (let i = 0; i < collections.length; i++) {
          this.$store.dispatch('$_filter_engines/getCollection', collections[i].collection).then(collection => {
            this.$set(this.collections, i, collection)
          })
        }
      })
    },
    sort (_collection, event) {
      const { collection, items } = _collection
      const { oldIndex, newIndex } = event // shifted, not swapped
      const tmp = items[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          items[i] = items[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          items[i] = items[i + 1]
        }
      }
      items[newIndex] = tmp
// resort
      this.$store.dispatch('$_filter_engines/sortFilterEngines', { collection, data: items.map(item => item.id) }).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('{name} resorted.', { name: this.$store.getters['$_filter_engines/collectionToName'](collection) } ) })
      })
    },
    remove () {

    },
    clone (_collection, item) {
      const { collection } = _collection
      const { id } = item
      this.$router.push({ name: 'cloneFilterEngine', params: { collection, id } })
    },
    view (_collection, item) {
      const { collection } = _collection
      const { id } = item
      this.$router.push({ name: 'filter_engine', params: { collection, id } })
    },
    enable (_collection, item) {
      const { collection } = _collection
      const { id } = item
      return () => { // 'enabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_filter_engines/enableFilterEngine', { collection, id }).then(() => {
            resolve('enabled')
          }).catch(() => {
            reject() // reset
          })
        })
      }
    },
    disable (_collection, item) {
      const { collection } = _collection
      const { id } = item
      return () => { // 'disabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_filter_engines/disableFilterEngine', { collection, id }).then(() => {
            resolve('disabled')
          }).catch(() => {
            reject() // reset
          })
        })
      }
    }
  },
  created () {
    this.init()
  }
}
</script>
