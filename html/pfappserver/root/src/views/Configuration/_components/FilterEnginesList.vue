<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Filter Engines'"></h4>
    </b-card-header>
    <b-card v-if="isLoadingCollections">
      <b-container class="my-5">
          <b-row class="justify-content-md-center text-secondary">
              <b-col cols="12" md="auto">
                <b-media>
                  <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
                  <h4>{{ $t('Loading Filter Engines') }}</h4>
                </b-media>
              </b-col>
          </b-row>
      </b-container>
    </b-card>
    <b-tabs v-else
      ref="tabs" :value="tabIndex" :key="tabIndex" card>
      <b-tab v-for="(collection, index) in collections" :key="index"
        :title="(collection && collection.name) ? collection.name : '...'" @click="tabIndex = index">
        <b-card v-if="collection">
          <h4 class="mb-3">{{ (collection && collection.name) ? collection.name : '...' }}</h4>
          <b-button class="mb-3" variant="outline-primary" :to="{ name: 'newFilterEngine', params: collection }">{{ $t('New Filter') }}</b-button>
          <pf-table-sortable
            :items="(collection && collection.items) ? collection.items : []"
            :fields="columns"
            @row-clicked="view(collection, $event)"
            hover
            striped
            @end="sort(collection, $event)"
          >
            <template v-slot:empty>
              <pf-empty-table :isLoading="isLoadingCollection(collection)" :text="$t('Click the button to define a new filter.')">{{ $t('No filters defined') }}</pf-empty-table>
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
            <template v-slot:cell(scopes)="item">
              <b-badge v-for="(scope, index) in item.scopes" :key="index" class="mr-1" variant="secondary">{{ scope }}</b-badge>
            </template>
            <template v-slot:cell(buttons)="item">
              <span class="float-right text-nowrap">
                <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Filter?')" @on-delete="remove(collection, item)" reverse/>
                <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(collection, item)">{{ $t('Clone') }}</b-button>
              </span>
            </template>
          </pf-table-sortable>
        </b-card>
      </b-tab>
    </b-tabs>
  </b-card>
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
  props: {
    collection: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      columns, // ../_config/filterEngines
      collections: []
    }
  },
  computed: {
    // tabIndex defined by this.collection param via $router
    tabIndex: {
      get () {
        const found = this.collections.findIndex(c => {
          return c && c.collection === this.collection
        })
        return (found > -1) ? found : 0
      },
      set (newTabIndex) {
        let { collections: { [newTabIndex]: { collection } = {} } = {} } = this
        if (collection) {
          this.$router.push({ name: 'filterEnginesCollection', params: { collection } })
        }
      }
    },
    isLoadingCollections () {
      return this.$store.getters['$_filter_engines/isLoadingCollections']
    },
    isLoadingCollection () {
      return (_collection = {}) => {
        const { collection } = _collection
        return !collection || this.$store.getters['$_filter_engines/isLoadingCollection'](collection)
      }
    },
    isLoading () {
      return this.$store.getters['$_filter_engines/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_filter_engines/getCollections').then(collections => {
        collections = collections.sort((a, b) => a.name.localeCompare(b.name)) // sort by name
        for (let i = 0; i < collections.length; i++) {
          this.$store.dispatch('$_filter_engines/getCollection', collections[i].collection).then(collection => {
            this.$set(this.collections, i, collection)
          })
        }
      })
    },
    sort (_collection, event) {
      const { collection, items } = _collection
      let data = items.map(item => item.id)
      const { oldIndex, newIndex } = event // shifted, not swapped
      const tmp = data[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          data[i] = data[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          data[i] = data[i + 1]
        }
      }
      data[newIndex] = tmp
      this.$store.dispatch('$_filter_engines/sortCollection', { collection, data }).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('{name} resorted.', { name: this.$store.getters['$_filter_engines/collectionToName'](collection) } ) })
      })
    },
    remove (_collection, item) {
      const { collection } = _collection
      const { id } = item
      this.$store.dispatch('$_filter_engines/deleteFilterEngine', { collection, id })
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
            this.$store.dispatch('notification/info', { message: this.$i18n.t('{collection} <code>{id}</code> enabled.', { collection: this.$store.getters['$_filter_engines/collectionToName'](collection), id } ) })
          }).catch(() => {
            this.$store.dispatch('notification/danger', { message: this.$i18n.t('{collection} <code>{id}</code> could not be enabled.', { collection: this.$store.getters['$_filter_engines/collectionToName'](collection), id } ) })
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
            this.$store.dispatch('notification/info', { message: this.$i18n.t('{collection} <code>{id}</code> disabled.', { collection: this.$store.getters['$_filter_engines/collectionToName'](collection), id } ) })
          }).catch(() => {
            this.$store.dispatch('notification/danger', { message: this.$i18n.t('{collection} <code>{id}</code> could not be disabled.', { collection: this.$store.getters['$_filter_engines/collectionToName'](collection), id } ) })
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
