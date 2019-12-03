<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Test 001'"></h4>
    </b-card-header>
    <div class="card-body">
<pre>{{ JSON.stringify($form, null, 2) }}</pre>
      <b-input-group>
        <b-form-input v-model="vModel['firstname']" placeholder="Enter your first name" :state="isValidNS('$form.firstname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.firstname')">{{ feedbackNS('$form.firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="vModel['lastname']" placeholder="Enter your last name" :state="isValidNS('$form.lastname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.lastname')">{{ feedbackNS('$form.lastname') }}</b-form-invalid-feedback>
      </b-input-group>

      <br/><br/>

      <h2>Children (Array)</h2>

      <b-input-group>
        <b-form-input v-model="vModel['children[0].firstname']" placeholder="Enter child first name" :state="isValidNS('$form.children[0].firstname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.children[0].firstname')">{{ feedbackNS('$form.children[0].firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="vModel['children[0].lastname']" placeholder="Enter child last name" :state="isValidNS('$form.children[0].lastname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.children[0].lastname')">{{ feedbackNS('$form.children[0].lastname') }}</b-form-invalid-feedback>
      </b-input-group>
      <hr/>

      <b-input-group>
        <b-form-input v-model="vModel['children[1].firstname']" placeholder="Enter child first name" :state="isValidNS('$form.children[1].firstname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.children[1].firstname')">{{ feedbackNS('$form.children[1].firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="vModel['children[1].lastname']" placeholder="Enter child last name" :state="isValidNS('$form.children[1].lastname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.children[1].lastname')">{{ feedbackNS('$form.children[1].lastname') }}</b-form-invalid-feedback>
      </b-input-group>
      <hr/>

      <b-input-group>
        <b-form-input v-model="vModel['children[2].firstname']" placeholder="Enter child first name" :state="isValidNS('$form.children[2].firstname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.children[2].firstname')">{{ feedbackNS('$form.children[2].firstname') }}</b-form-invalid-feedback>
      </b-input-group>
      <b-input-group>
        <b-form-input v-model="vModel['children[2].lastname']" placeholder="Enter child last name" :state="isValidNS('$form.children[2].lastname')"></b-form-input>
        <b-form-invalid-feedback :state="isValidNS('$form.children[2].lastname')">{{ feedbackNS('$form.children[2].lastname') }}</b-form-invalid-feedback>
      </b-input-group>
      <hr/>


<pre>{{ JSON.stringify($v, null, 2) }}</pre>
    </div>
  </b-card>
</template>

<script>
import { required, minLength } from 'vuelidate/lib/validators'

export default {
  name: 'test001',
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      form: {
        firstname: null,
        lastname: 'satkunas',
        children: [
          {
            firstname: 'child1',
            lastname: 'satkunas'
          },
          {
            firstname: 'child2',
            lastname: 'satkunas'
          }/*,
          {
            firstname: 'child3',
            lastname: 'satkunas'
          }*/
        ]
      },
      validations: {
        $form: {
          firstname: {
            ['First name required.']: required,
            ['Minimum length 3 characters.']: minLength(3)
          },
          lastname: {
            ['Last name required.']: required,
            ['Minimum length 3 characters.']: minLength(3)
          },
          children: {
            $each: {
              firstname: {
                ['First name required.']: required,
                ['Minimum length 3 characters.']: minLength(3)
              },
              lastname: {
                ['Last name required.']: required,
                ['Minimum length 3 characters.']: minLength(3)
              }
            }
          }
        }
      }
    }
  },
  computed: {
    // temporary
    $v () { // (ro)
      return this.$store.getters[`${this.storeName}/$v`]
    },
    $form () {
      return this.$store.getters[`${this.storeName}/$form`]
    },




    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    stateNS () {
      return (namespace) => this.$store.getters[`${this.storeName}/$stateNS`](namespace)
    },
    isValidNS () {
      return (namespace) => !this.stateNS(namespace).$invalid
    },
    feedbackNS () {
      return (namespace) => this.$store.getters[`${this.storeName}/$feedbackNS`](namespace)
    },
    vModel () {
      return this.$store.getters[`${this.storeName}/$vModel`]
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/setForm`, this.form)
    this.$store.dispatch(`${this.storeName}/setValidations`, this.validations)
  }
}
</script>
