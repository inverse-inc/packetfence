<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Test 001'"></h4>
    </b-card-header>
    <div class="card-body">
<pre>{{ JSON.stringify($v.$invalid, null, 2) }}</pre>
<pre>{{ JSON.stringify($form, null, 2) }}</pre>
      <b-form-input v-model="$form.firstname" placeholder="Enter your first name"></b-form-input>
      <b-form-input v-model="$form.lastname" placeholder="Enter your last name"></b-form-input>
<pre>{{ JSON.stringify($v, null, 2) }}</pre>
    </div>
  </b-card>
</template>

<script>
export default {
  name: 'test001',
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    $form () { // (rw)
      return this.$store.getters[`${this.storeName}/$form`]
    },
    $v () { // (ro)
      return this.$store.getters[`${this.storeName}/$v`]
    }
  }
}
</script>
