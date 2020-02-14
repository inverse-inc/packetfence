<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">Test - {{ formStoreName }}</h4>
    </b-card-header>
    <div class="card-body">
<pre>{{ JSON.stringify(form, null, 2) }}</pre>

      <pf-form-boolean :form-store-name="formStoreName" form-namespace="condition">
        <template v-slot:default="{ value, formStoreName, formNamespace }">

          <strong>{{ formStoreName }} {{ formNamespace }}</strong>
          <pre>{{ JSON.stringify(value, null, 2) }}</pre>

          <!-- -->
          <b-row>
            <b-col>op</b-col>
            <b-col><pf-form-input v-model="value.op"/></b-col>
          </b-row>
          <b-row>
            <b-col>field</b-col>
            <b-col><pf-form-input v-model="value.field"/></b-col>
          </b-row>
          <b-row>
            <b-col>value</b-col>
            <b-col><pf-form-input v-model="value.value"/></b-col>
          </b-row>
          <!-- -->

          <!--
          <b-row>
            <b-col>op</b-col>
            <b-col><pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.op'"/></b-col>
          </b-row>
          <b-row>
            <b-col>field</b-col>
            <b-col><pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.field'"/></b-col>
          </b-row>
          <b-row>
            <b-col>value</b-col>
            <b-col><pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.value'"/></b-col>
          </b-row>
          -->

        </template>
      </pf-form-boolean>

    </div>
  </b-card>
</template>

<script>
import pfFormBoolean from '@/components/pfFormBoolean'
import pfFormInput from '@/components/pfFormInput'

export default {
  name: 'test',
  components: {
    pfFormBoolean,
    pfFormInput
  },
  data () {
    return {

    }
  },
  props: {
    formStoreName: {
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    }
  },
  methods: {

  },
  created () {
    this.$store.dispatch(`${this.formStoreName}/setForm`, {
      condition: {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              {
                op: 'contains',
                field: 'keyA',
                value: 'valueA'
              },
              {
                op: 'contains',
                field: 'keyB',
                value: 'valueB'
              }
            ]
          },
          {
            op: 'or',
            values: [
              {
                op: 'contains',
                field: 'keyC',
                value: 'valueC'
              },
              {
                op: 'contains',
                field: 'keyD',
                value: 'valueD'
              }
            ]
          }
        ]
      }
    })
  }
}

</script>
