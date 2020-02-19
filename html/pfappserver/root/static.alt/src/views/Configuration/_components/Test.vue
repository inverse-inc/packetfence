<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">Test - {{ formStoreName }}</h4>
    </b-card-header>
    <div class="card-body">

      <pf-form-boolean :form-store-name="formStoreName" form-namespace="condition" style="background-color:#e8e8e8;" class="p-3">

        <template v-slot:op="{ formStoreName, formNamespace }">
          <pf-form-chosen
            :form-store-name="formStoreName"
            :form-namespace="formNamespace + '.op'"
            :options="operators"
            :allow-empty="false"
            class="m-1"
          />
        </template>

        <template v-slot:value="{ value, formStoreName, formNamespace }">

          <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.field'" class="m-1"/>
          <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.op'" class="m-1"/>
          <pf-form-input :form-store-name="formStoreName" :form-namespace="formNamespace + '.value'" class="m-1"/>

          <!--
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

      <pre>{{ JSON.stringify(form, null, 2) }}</pre>

    </div>
  </b-card>
</template>

<script>
import pfFormBoolean from '@/components/pfFormBoolean'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'

export default {
  name: 'test',
  components: {
    pfFormBoolean,
    pfFormChosen,
    pfFormInput
  },
  data () {
    return {
      operators: [
        { value: 'and', text: this.$i18n.t('AND') },
        { value: 'or', text: this.$i18n.t('OR') },
        { value: 'nand', text: this.$i18n.t('NAND') },
        { value: 'nor', text: this.$i18n.t('NOR') }
      ]
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
              },
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
          },
          {
            op: 'and',
            values: [
              {
                op: 'contains',
                field: 'keyE',
                value: 'valueE'
              },
              {
                op: 'contains',
                field: 'keyF',
                value: 'valueF'
              },
              {
                op: 'contains',
                field: 'keyG',
                value: 'valueG'
              },
              {
                op: 'contains',
                field: 'keyH',
                value: 'valueH'
              }
            ]
          },
          {
            op: 'or',
            values: [
              {
                op: 'contains',
                field: 'keyI',
                value: 'valueI'
              },
              {
                op: 'contains',
                field: 'keyJ',
                value: 'valueJ'
              },
              {
                op: 'contains',
                field: 'keyK',
                value: 'valueK'
              },
              {
                op: 'contains',
                field: 'keyL',
                value: 'valueL'
              }
            ]
          }
        ]
      }
    })
  }
}

</script>
