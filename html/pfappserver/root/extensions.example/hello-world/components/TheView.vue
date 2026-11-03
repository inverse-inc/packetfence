<template>
  <b-card no-body class="mt-3">
    <b-card-header>
      <h4 class="mb-0">
        <icon name="flask" class="mr-2" />
        {{ $t('Hello World') }}
      </h4>
    </b-card-header>
    <div class="card-body hello-world">
      <p v-t="'This view is provided by the hello-world UI extension.'" />
      <p>{{ $t('Hostname: {hostname}', { hostname: hostname || '...' }) }}</p>
      <b-button variant="outline-primary" @click="counter.increment()">
        {{ $t('Clicked {count} times', { count: counter.count }) }}
      </b-button>
    </div>
  </b-card>
</template>

<script>
import { computed, onMounted } from '@vue/composition-api'
import { useCounter } from '../store/counter'

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const counter = useCounter()
  const hostname = computed(() => $store.state.helloWorld?.hostname)

  onMounted(() => $store.dispatch('helloWorld/getHostname').catch(() => {}))

  return {
    counter,
    hostname
  }
}

// @vue/component
export default {
  name: 'the-view',
  setup
}
</script>

<style lang="scss">
.hello-world {
  border-left: 3px solid $primary;
  user-select: none;
}
</style>
