<template>
  <div class="d-flex" :key="id">
    <bread-crumb v-if="device.parent_id"
      :id="device.parent_id" :scope="scope" />
    <b-button v-else
      variant="link" class="px-0 mr-2 text-secondary"
      :to="{ name: 'fingerbankDevicesByScope', params: { scope } }"
    >
      <icon name="times" variant="primary" />
    </b-button>
    <b-button
      variant="link" class="px-0 mr-2 text-primary"
      :to="{ name: 'fingerbankDevicesByParentId', params: { parentId: device.id } }"
    >
      <icon v-if="device.parent_id"
        name="caret-right" variant="text-secondary" class="mr-1" />
      {{ device.name }}
    </b-button>
  </div>
</template>
<script>
const props = {
  id: {
    type: String
  },
  scope: {
    type: String
  }
}

import { onMounted, ref, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const device = ref({ name: '...' })
  onMounted(() => {
    $store.dispatch('$_fingerbank/getDevice', id.value).then(item => {
      device.value = item
    })
  })

  return {
    device
  }
}
// @vue/component
export default {
  name: 'bread-crumb',
  inheritAttrs: false,
  props,
  setup
}
</script>
