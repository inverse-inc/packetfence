<template>
  <b-dropdown v-bind="$attrs"
    @shown="isShown = true" @hidden="isShown = false"
    toggle-class="p-0"
    @click.native.stop
    @dblclick.native.stop="goToView"
    lazy>
    <template #button-content>
      <slot><mac v-text="id" /></slot>
    </template>
    <b-dropdown-text class="text-mono">
      {{ id }}
    </b-dropdown-text>
    <b-dropdown-divider />
    <b-dropdown-item v-if="isLoading" class="px-0">
      <icon class="position-absolute mt-1" name="circle-notch" spin />
      <span class="ml-4 pl-2">{{ $i18n.t('Loading') }}</span>
    </b-dropdown-item>
    <b-dropdown-item v-else-if="!isExists || !node" class="px-0">
      <icon class="position-absolute mt-1" name="exclamation-circle" />
      <span class="ml-4 pl-2">{{ $i18n.t('Node not found.') }}</span>
    </b-dropdown-item>
    <template v-else>
      <b-dropdown-form>
        <b-row class="flex-nowrap">
          <b-col cols="6" class="mr-auto text-nowrap">{{ $i18n.t('Status') }}</b-col>
          <b-col cols="auto">
            <span v-b-tooltip.right.d300 :title="$i18n.t('registered')" v-if="node.status === 'reg'">
              <icon name="check-circle" />
            </span>
            <span v-b-tooltip.right.d300 :title="$i18n.t('unregistered')" v-else-if="node.status === 'unreg'">
              <icon name="regular/times-circle" />
            </span>
            <span v-b-tooltip.right.d300 :title="$i18n.t('pending')" v-else>
              <icon name="regular/dot-circle" />
            </span>
          </b-col>
        </b-row>
        <b-row class="flex-nowrap">
          <b-col cols="6" class="mr-auto text-nowrap">{{ $i18n.t('Online') }}</b-col>
          <b-col cols="auto">
            <span v-b-tooltip.right.d300 :title="$i18n.t('on')" v-if="node.online === 'on'">
              <icon name="circle" class="text-success" />
            </span>
            <span v-b-tooltip.right.d300 :title="$i18n.t('off')" v-else-if="node.online === 'off'">
              <icon name="circle" class="text-danger" />
            </span>
            <span v-b-tooltip.right.d300 :title="$i18n.t('unknown')" v-else>
              <icon name="question-circle" class="text-warning" />
            </span>
          </b-col>
        </b-row>
      </b-dropdown-form>
      <b-dropdown-divider />
      <b-dropdown-form>
        <b-row v-if="node.device_class"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Device Class'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.device_class"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_manufacturer"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Device Manufacturer'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.device_manufacturer"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_type"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Device Type'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.device_type"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_version"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Device Version'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.device_version"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.computername"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Computer Name'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.computername"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.machine_account"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Machine Account'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.machine_account"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.pid"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Owner'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.pid"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.category"
          class="flex-nowrap">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap text-secondary" v-text="'Role'"></p>
            <p class="mb-2 text-nowrap text-dark" v-text="node.category"></p>
          </b-col>
        </b-row>
      </b-dropdown-form>
      <b-dropdown-divider />
      <b-dropdown-item :to="{ path: `/node/${id}` }" class="px-0">
        <icon class="position-absolute mt-1" name="plus-circle" />
        <span class="ml-4 pl-2">{{ $i18n.t('View Node') }}</span>
      </b-dropdown-item>
      <b-dropdown-item :to="{ path: `/status/network_communication/${id}` }" class="px-0">
        <icon class="position-absolute mt-1" name="chart-line" />
        <span class="ml-4 pl-2">{{ $i18n.t('View Communication') }}</span>
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


import { nextTick, ref, toRefs, watch } from '@vue/composition-api'
import store from '@/store'
import NodesStoreModule from '../_store'
import { useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const {
    isLoading,
    getItem
  } = useStore($store)

  const isExists = ref(false)
  const isShown = ref(false)
  const node = ref({})

  watch(isShown, () => {
    if (isShown.value) {
      if (!store.state.$_nodes)
        store.registerModule('$_nodes', NodesStoreModule)
      getItem({ id: id.value })
        .then(item => {
          node.value = item
          isExists.value = true
        })
        .catch(() => {
          isExists.value = false
        })
        .finally(() => nextTick(() => window.scrollBy(0, 1))) // center b-dropdown
    }
  })

  const goToView = () => {
    $router.push(`/node/${id.value}`)
  }

  return {
    isExists,
    isShown,
    isLoading,
    node,
    goToView,
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