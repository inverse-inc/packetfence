<template>
  <div class="pf-table-sortable" :class="{ 'hover': hover, 'striped': striped }">

    <!-- head -->
    <b-row class="pf-table-sortable-head">
      <b-col cols="1">
        <icon name="sort" class="text-secondary"></icon>
      </b-col>
      <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex">
        {{ $t(field.label) }}
      </b-col>
    </b-row>
    <b-row v-if="!items || items.length === 0"
      class="pf-table-sortable-empty justify-content-md-center"
    >
      <b-col cols="12" md="auto">
        <slot name="empty" :is-loading="isLoading">
          <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
        </slot>
      </b-col>
    </b-row>

    <!-- body -->
    <template v-else>
      <b-row v-for="(item, itemIndex) in notSortableItems" :key="itemIndex"
        class="pf-table-sortable-row"
      >
        <b-col class="draghandle" cols="1">
          <icon class="draghandle-icon" name="lock"></icon>
          <span class="draghandle-index font-weight-bold">{{ itemIndex + 1 }}</span>
        </b-col>
        <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex" @click.stop="clickRow(item)">
          <slot :name="cell(field.key)" v-bind="item">{{ formatted(item, field) }}</slot>
        </b-col>
      </b-row>
      <draggable
        v-model="sortableItems"
        handle=".draghandle"
        dragClass="dragclass"
        @start="onDraggable('start', $event)"
        @add="onDraggable('add', $event)"
        @remove="onDraggable('remove', $event)"
        @update="onDraggable('update', $event)"
        @end="onDraggable('end', $event)"
        @choose="onDraggable('choose', $event)"
        @sort="onDraggable('sort', $event)"
        @filter="onDraggable('filter', $event)"
        @clone="onDraggable('clone', $event)"
      >
        <b-row v-for="(item, itemIndex) in sortableItems" :key="itemIndex"
          class="pf-table-sortable-row"
        >
          <b-col class="draghandle" cols="1">
            <icon v-if="disabled" name="lock"></icon>
            <template v-else>
              <icon class="draghandle-icon" :name="(sortableItems.length == 1 || item.not_sortable) ? 'lock' : 'th'" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
              <span class="draghandle-index">{{ notSortableItems.length + itemIndex + 1 }}</span>
            </template>
          </b-col>
          <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex" @click.stop="clickRow(item)">
            <slot :name="cell(field.key)" v-bind="item">{{ formatted(item, field) }}</slot>
          </b-col>
        </b-row>
      </draggable>
    </template>

  </div>
</template>

<script>
import draggable from 'vuedraggable'
import pfEmptyTable from '@/components/pfEmptyTable'

export default {
  name: 'pf-table-sortable',
  components: {
    draggable,
    pfEmptyTable
  },
  props: {
    items: {
      type: Array,
      default: () => { return null },
      required: false
    },
    fields: {
      type: Array,
      default: () => { return [] },
      required: true
    },
    hover: {
      type: Boolean,
      default: false
    },
    striped: {
      type: Boolean,
      default: false
    },
    isLoading: {
      type: Boolean,
      default: false
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      drag: false // true ondrag
    }
  },
  computed: {
    visibleFields () {
      return this.fields.filter(field => field.locked || field.visible)
    },
    sortableItems () {
      return this.items.filter(item => !item.not_sortable)
    },
    notSortableItems () {
      return this.items.filter(item => item.not_sortable)
    }
  },
  methods: {
    cell (name) {
      return `cell(${name})`
    },
    clickRow (item) {
      this.$emit('row-clicked', item)
    },
    onDraggable (type, event) {
      if (type === 'end') { // increment indexes past not_sortable
        let { oldIndex, newIndex } = event
        const shift = this.items.filter(item => 'not_sortable' in item && item.not_sortable).length
        oldIndex += shift
        newIndex += shift
        event = { ...event, oldIndex, newIndex }
      }
      switch (type) {
        case 'start':
          this.drag = true
          break
        case 'end':
          this.drag = false
          break
      }
      this.$emit(type, event)
    },
    formatted (item, field) {
      if ('formatter' in field) {
        return field.formatter(item)
      }
      return item[field.key]
    }
  }
}
</script>

<style lang="scss">
.pf-table-sortable {
  color: #495057;
  border-spacing: 2px;
  .draghandle {
    cursor: grab;
    line-height: 1em;
  }
  .dragclass {
    padding-top: .25rem !important;
    padding-bottom: .0625rem !important;
    background-color: $primary !important;
    path, /* svg icons */
    * {
      color: $white !important;
      border-color: transparent !important;
    }
    button.btn {
      border: 1px solid $white !important;
      border-color: $white !important;
      color: $white !important;
    }
    input,
    select,
    .multiselect__single {
      color: $primary !important;
    }
    .pf-form-fields-input-group {
      border-color: transparent !important;
    }
  }
  .pf-table-sortable-empty {
    background-color: rgba(0,0,0,.05);
    vertical-align: top;
  }
  .pf-table-sortable-head {
    border-top: 1px solid #dee2e6;
    border-bottom: 2px solid #dee2e6;
    font-weight: bold;
    vertical-align: middle;
    & > div {
      vertical-align: bottom;
    }
  }
  .pf-table-sortable-row {
    border-top: 1px solid #dee2e6;
    cursor: pointer;
    & .draghandle-icon,
    &:hover .draghandle-index {
      display: none;
    }
    & .draghandle-index,
    &:hover .draghandle-icon {
      display: inline;
    }
  }
  .pf-table-sortable-empty,
  .pf-table-sortable-head,
  .pf-table-sortable-row {
    border-color: #dee2e6;
    margin: 0;
    & > .col {
      align-self: center!important;
      padding: .75rem;
    }
    & > .col-1 {
      align-self: center!important;
      max-width: 50px;
      padding: .75rem;
      vertical-align: middle;
    }
  }
  &.striped {
    .pf-table-sortable-row {
      &:nth-of-type(odd) {
        background-color: rgba(0,0,0,.05);
      }
    }
  }
  &.hover {
    .pf-table-sortable-row {
      &:hover {
        background-color: rgba(0,0,0,.075);
        color: #495057;
      }
    }
  }
}
</style>
