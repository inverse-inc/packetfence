<template>
  <b-dropdown v-bind="$attrs"
    @shown="isShown = true" @hidden="isShown = false"
    lazy>
    <template #button-content>
      <slot><mac v-text="id" /></slot>
    </template>
    <b-dropdown-item v-if="isLoading">
      <icon class="position-absolute mt-1" name="circle-notch" spin />
      <span class="ml-4">{{ $t('Loading') }}</span>
    </b-dropdown-item>
    <template v-else>
      <b-dropdown-form>
        <b-row v-if="node.device_class"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Class'"></p>
            <p class="mb-2 text-nowrap" v-text="node.device_class"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_manufacturer"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Manufacturer'"></p>
            <p class="mb-2 text-nowrap" v-text="node.device_manufacturer"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_type"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Type'"></p>
            <p class="mb-2 text-nowrap" v-text="node.device_type"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_version"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Version'"></p>
            <p class="mb-2 text-nowrap" v-text="node.device_version"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.computername"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Computer Name'"></p>
            <p class="mb-2 text-nowrap" v-text="node.computername"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.machine_account"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Machine Account'"></p>
            <p class="mb-2 text-nowrap" v-text="node.machine_account"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.pid"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Owner'"></p>
            <p class="mb-2 text-nowrap" v-text="node.pid"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.category"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Role'"></p>
            <p class="mb-2 text-nowrap" v-text="node.category"></p>
          </b-col>
        </b-row>
      </b-dropdown-form>
      <b-dropdown-divider />
      <b-dropdown-form>
        <b-row class="flex-nowrap">
          <b-col cols="6" class="mr-auto text-nowrap">{{ $t('Status') }}</b-col>
          <b-col cols="auto">
            <b-badge v-if="node.status === 'reg'" pill variant="success">{{ $i18n.t('Reg') }}</b-badge>
            <b-badge v-else pill variant="danger">{{ $i18n.t('Unreg') }}</b-badge>
          </b-col>
        </b-row>
        <b-row class="flex-nowrap">
          <b-col cols="6" class="mr-auto text-nowrap">{{ $t('Auto Reg') }}</b-col>
          <b-col cols="auto">
            <b-badge v-if="node.autoreg === 'yes'" pill variant="success">{{ $i18n.t('Yes') }}</b-badge>
            <b-badge v-else pill variant="danger">{{ $i18n.t('No') }}</b-badge>
          </b-col>
        </b-row>
        <b-row class="flex-nowrap">
          <b-col cols="6" class="mr-auto text-nowrap">{{ $t('VOIP') }}</b-col>
          <b-col cols="auto">
            <b-badge v-if="node.voip === 'yes'" pill variant="success">{{ $i18n.t('Yes') }}</b-badge>
            <b-badge v-else pill variant="danger">{{ $i18n.t('No') }}</b-badge>
          </b-col>
        </b-row>
      </b-dropdown-form>
      <b-dropdown-divider />
      <b-dropdown-item :to="{ path: `/node/${id}` }">
        <icon class="position-absolute mt-1" name="plus-circle" />
        <span class="ml-4">{{ $t('View Node') }}</span>
      </b-dropdown-item>
    </template>
  </b-dropdown>
</template>

<script>
const props = {
  id: {
    type: [Number, String]
  }
}


import { ref, toRefs, watch } from '@vue/composition-api'
import store from '@/store'
import NodesStoreModule from '../_store'
import { useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const {
    isLoading,
    getItem
  } = useStore($store)

  const isShown = ref(false)
  const node = ref({})

  watch(isShown, () => {
    if (isShown.value) {
      if (!store.state.$_nodes)
        store.registerModule('$_nodes', NodesStoreModule)
      getItem({ id: id.value })
        .then(item => {
          node.value = item
        })
    }
  })

  return {
    isShown,
    isLoading,
    node
  }
}

// @vue/component
export default {
  name: 'base-button-dropdown',
  inheritAttrs: false,
  props,
  setup
}
</script>