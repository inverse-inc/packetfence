<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="onClose" v-b-tooltip.hover.left.d300 :title="$t('Close')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0" v-t="'Import Switches'"></h4>
    </b-card-header>
    <div class="card-body p-0">
      <b-tabs ref="tabs" v-model="tabIndex" card pills>
        <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified"
          :title="file.name" :title-link-class="(tabIndex === index) ? ['bg-primary', 'text-light'] : ['bg-light', 'text-primary']"
          no-body
        >
          <template v-slot:title>
            <b-button-close class="ml-2" :class="(tabIndex === index) ? 'text-white' : 'text-primary'" @click.stop.prevent="onCloseFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')">
              <icon name="times" class="align-top ml-1"></icon>
            </b-button-close>
            {{ file.name }}
          </template>
          <base-csv-import :ref="'import-' + index"
            :file="file"
            :fields="importFields"
            :is-loading="isLoading"
            :import-promise="importPromise"
            hover
            striped
          />
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
import {
  BaseCsvImport
} from '@/components/new/'
import pfFormUpload from '@/components/pfFormUpload'

const components = {
  BaseCsvImport,
  pfFormUpload
}

import { ref } from '@vue/composition-api'
import { importFields } from '../config'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context
  
  const files = ref([])
  const tabIndex = ref(0)
  const isLoading = ref(false)

  const onClose = () => $router.push({ name: 'switches' })
  
  const onCloseFile = (index) => {
    const { [index]: { file } = {} } = files.value
    file.close()
    files.value.splice(index, 1)    
  }

  const importPromise = (payload) => {
    isLoading.value = true
    return $store.dispatch('$_switches/bulkImport', payload)
      .finally(() => {
        isLoading.value = false
      })
  }
  
  return {
    importFields,

    files,
    tabIndex,
    isLoading,
    onClose,
    onCloseFile,
    importPromise
  }
}

// @vue/component
export default {
  name: 'the-csv-import',
  inheritAttrs: false,
  components,
  setup
}
</script>
