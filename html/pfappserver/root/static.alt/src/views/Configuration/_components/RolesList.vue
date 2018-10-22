<script>
import BaseList from './_lib/BaseList'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export default {
  name: 'RolesList',
  extends: BaseList,
  props: {
    pfMixinSearchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'config/roles',
        defaultSortKeys: ['id'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: null },
              { field: 'notes', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'configuration/roles' }
      })
    },
    tableValues: {
      type: Array,
      default: () => []
    }
  },
  data () {
    return {
      config: {
        pageTitle: this.$i18n.t('Roles'),
        buttonAddLabel: this.$i18n.t('Add Role'),
        buttonAddRoute: { name: 'newRole' },
        emptyTableText: this.$i18n.t('No role found')
      },
      // Fields must match the database schema
      fields: [ // keys match with b-form-select
        {
          value: 'id',
          text: 'Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'notes',
          text: 'Description',
          types: [conditionType.SUBSTRING]
        }
      ],
      columns: [
        {
          key: 'id',
          label: this.$i18n.t('Name'),
          sortable: true,
          visible: true
        },
        {
          key: 'notes',
          label: this.$i18n.t('Description'),
          sortable: true,
          visible: true
        },
        {
          key: 'max_nodes_per_pid',
          label: this.$i18n.t('Max nodes per user'),
          sortable: true,
          visible: true
        }
      ]
    }
  },
  methods: {
    onRowClick (item, index) {
      this.$router.push({ name: 'role', params: { id: item.id } })
    }
  }
}
</script>
