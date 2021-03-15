<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Import Nodes'"></h4>
    </b-card-header>
    <div class="card-body p-0">
      <b-tabs ref="tabs" v-model="tabIndex" card pills>
        <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified"
          :title="file.name" :title-link-class="(tabIndex === index) ? ['bg-primary', 'text-light'] : ['bg-light', 'text-primary']"
          no-body
        >
          <template v-slot:title>
            <b-button-close class="ml-2" :class="(tabIndex === index) ? 'text-white' : 'text-primary'" @click.stop.prevent="closeFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')">
              <icon name="times" class="align-top ml-1"></icon>
            </b-button-close>
            {{ file.name }}
          </template>
          <pf-csv-import :ref="'import-' + index"
            :file="file"
            :fields="importFields"
            :default-static-mapping="defaultStaticMapping"
            :events-listen="tabIndex === index"
            :is-loading="isLoading"
            :import-promise="importPromise"
            store-name="$_nodes"
            hover
            striped
          ></pf-csv-import>
        </b-tab>
        <template v-slot:tabs-end>
          <pf-form-upload @files="files = $event" @focus="tabIndex = $event" :multiple="true" :cumulative="true" accept="text/*, .csv">{{ $t('Open CSV File') }}</pf-form-upload>
        </template>
        <template v-slot:empty>
          <div class="text-center text-muted">
            <b-container class="my-5">
              <b-row class="justify-content-md-center text-secondary">
                  <b-col cols="12" md="auto">
                    <icon v-if="isLoading" name="sync" scale="2" spin></icon>
                    <b-media v-else>
                      <template v-slot:aside><icon name="file" scale="2"></icon></template>
                      <h4>{{ $t('There are no open CSV files') }}</h4>
                    </b-media>
                  </b-col>
              </b-row>
            </b-container>
          </div>
        </template>
      </b-tabs>
    </div>
  </b-card>
</template>

<script>
import pfCSVImport from '@/components/pfCSVImport'
import pfFormUpload from '@/components/pfFormUpload'
import { importFields } from '../_config/'

export default {
  name: 'the-csv-import',
  components: {
    'pf-csv-import': pfCSVImport,
    pfFormUpload
  },
  data () {
    return {
      files: [],
      tabIndex: 0,
      defaultStaticMapping: [{ 'key': 'status', 'value': 'reg' }],
      importFields, // ../_config/
      isLoading: false
    }
  },
  methods: {
    abortFile (index) {
      this.files[index].reader.abort()
    },
    closeFile (index) {
      const file = this.files[index]
      file.close()
      this.files.splice(index, 1)
    },
    importPromise (payload) {
      return this.$store.dispatch('$_nodes/bulkImport', payload)
    }
  },
  created () {
    this.$store.dispatch('session/getAllowedNodeRoles')
  }
}
</script>
