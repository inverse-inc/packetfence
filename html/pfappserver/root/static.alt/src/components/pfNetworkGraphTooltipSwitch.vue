<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">{{ id }}</h4>
    </b-card-header>
    <div class="card-body">
      ...
    </div>
  </b-card>
</template>

<script>
export default {
  name: 'pf-network-graph-tooltip-switch',
  props: {
    id: {
      type: String
    }
  }
}
</script>
