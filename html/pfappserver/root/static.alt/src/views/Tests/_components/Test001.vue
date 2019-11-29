<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Test 001'"></h4>
    </b-card-header>
    <div class="card-body">
<pre>{{ JSON.stringify($v.$invalid, null, 2) }}</pre>
<pre>{{ JSON.stringify($form, null, 2) }}</pre>
      <b-input-group>
        <b-form-input v-model="$form.firstname" placeholder="Enter your first name" :state="state('$form.firstname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.firstname')">{{ feedback('$form.firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="$form.lastname" placeholder="Enter your last name" :state="state('$form.lastname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.lastname')">{{ feedback('$form.lastname') }}</b-form-invalid-feedback>
      </b-input-group>

      <h2>Children (Array)</h2>
      <b-input-group>
        <b-form-input v-model="$form.children[0].firstname" placeholder="Enter child first name" :state="state('$form.children.0.firstname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.children.0.firstname')">{{ feedback('$form.children.0.firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="$form.children[0].lastname" placeholder="Enter child last name" :state="state('$form.children.0.lastname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.children.0.lastname')">{{ feedback('$form.children.0.lastname') }}</b-form-invalid-feedback>
      </b-input-group>
      <hr/>

      <b-input-group>
        <b-form-input v-model="$form.children[1].firstname" placeholder="Enter child first name" :state="state('$form.children.1.firstname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.children.1.firstname')">{{ feedback('$form.children.1.firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="$form.children[1].lastname" placeholder="Enter child last name" :state="state('$form.children.1.lastname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.children.1.lastname')">{{ feedback('$form.children.1.lastname') }}</b-form-invalid-feedback>
      </b-input-group>
      <hr/>

      <b-input-group>
        <b-form-input v-model="$form.children[2].firstname" placeholder="Enter child first name" :state="state('$form.children.2.firstname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.children.2.firstname')">{{ feedback('$form.children.2.firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="$form.children[2].lastname" placeholder="Enter child last name" :state="state('$form.children.2.lastname')"></b-form-input>
        <b-form-invalid-feedback :state="state('$form.children.2.lastname')">{{ feedback('$form.children.2.lastname') }}</b-form-invalid-feedback>
      </b-input-group>
      <hr/>


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
    },
    state () {
      return (namespace) => this.$store.getters[`${this.storeName}/$state`](namespace)
    },
    feedback () {
      return (namespace) => this.$store.getters[`${this.storeName}/$feedback`](namespace)
    }
  },
  created () {
    /*
    setTimeout(() => {
      this.$store.dispatch(`${this.storeName}/$touch`)
    }, 3000)
    */
  }
}
</script>
