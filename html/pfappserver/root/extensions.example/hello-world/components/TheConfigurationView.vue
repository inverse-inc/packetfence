<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ title }}</h4>
    </b-card-header>
    <div class="card-body">
      <p>{{ $t('Visits during this session: {visits}', { visits }) }}</p>
    </div>
  </b-card>
</template>

<script>
import { computed, onMounted } from '@vue/composition-api'

const props = {
  title: {
    type: String
  }
}

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const visits = computed(() => $store.state.$_hello_world.visits)

  onMounted(() => $store.commit('$_hello_world/VISIT'))

  return {
    visits
  }
}

// @vue/component
export default {
  name: 'the-configuration-view',
  props,
  setup
}
</script>
