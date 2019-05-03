<template>
  <div class="pfTableSortable" :class="{ 'hover': hover, 'striped': striped }" @mouseleave="onMouseLeave()">

    <!-- head -->
    <b-row class="pfTableSortableHead" @mouseenter="onMouseLeave()" @mousemove="onMouseLeave()">
      <b-col cols="1">
        <icon name="sort" class="text-secondary"></icon>
      </b-col>
      <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex">
        {{ $t(field.label) }}
      </b-col>
    </b-row>
    <b-row v-if="items.length === 0"
      class="pfTableSortableEmpty justify-content-md-center"
    >
      <b-col cols="12" md="auto">
        <slot name="empty" v-bind="{ isLoading }">
          <pf-empty-table :isLoading="isLoading">{{ $t('No results found') }}</pf-empty-table>
        </slot>
      </b-col>
    </b-row>

    <!-- body -->
    <draggable v-else
      v-model="items"
      :options="{ handle: '.draghandle', dragClass: 'dragclass' }"
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
      <b-row v-for="(item, itemIndex) in items" :key="itemIndex"
        class="pfTableSortableRow"
        @mouseenter="onMouseEnter(itemIndex)"
        @mousemove="onMouseEnter(itemIndex)"
      >
        <b-col class="draghandle" cols="1">
          <template v-if="!disabled && hoverIndex === itemIndex && items.length > 1">
            <icon name="th" v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"></icon>
          </template>
          <template v-else>
            {{ itemIndex + 1 }}
          </template>
        </b-col>
        <b-col v-for="(field, fieldIndex) in visibleFields" :key="fieldIndex" @click.stop="clickRow(item)">
          <slot :name="field.key" v-bind="{ item }">{{ item[field.key] }}</slot>
        </b-col>
      </b-row>
    </draggable>

  </div>
</template>

<script>
import draggable from 'vuedraggable'
import pfEmptyTable from '@/components/pfEmptyTable'

export default {
  name: 'pfTableSortable',
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
      hoverIndex: null, // row index onmouseover
      drag: false // true ondrag
    }
  },
  computed: {
    visibleFields () {
      return this.fields.filter(field => field.visible)
    }
  },
  methods: {
    clickRow (item) {
      this.$emit('row-clicked', item)
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hoverIndex = index
    },
    onMouseLeave () {
      this.hoverIndex = null
    },
    onDraggable (type, event) {
      switch (type) {
        case 'start':
          this.drag = true
          break
        case 'end':
          this.drag = false
          break
      }
      this.$emit(type, event)
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

.pfTableSortable {
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
      color: $white !important;
      border: 1px solid $white !important;
      border-color: $white !important;
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
  .pfTableSortableEmpty {
    background-color: rgba(0,0,0,.05);
    vertical-align: top;
  }
  .pfTableSortableHead {
    border-top: 1px solid #dee2e6;
    border-bottom: 2px solid #dee2e6;
    font-weight: bold;
    vertical-align: middle;
    & > div {
      vertical-align: bottom;
    }
  }
  .pfTableSortableRow {
    border-top: 1px solid #dee2e6;
  }
  .pfTableSortableEmpty,
  .pfTableSortableHead,
  .pfTableSortableRow {
    border-color: #dee2e6;
    margin: 0;
    & > .col {
      align-self: center!important;
      padding: .75rem;
    }
    & > .col-1 {
      align-self: center!important;
      padding: .75rem;
      /*flex: 0 0 50px;*/
      max-width: 50px;
      vertical-align: middle;
    }
  }
  &.striped {
    .pfTableSortableRow {
      &:nth-of-type(odd) {
        background-color: rgba(0,0,0,.05);
      }
    }
  }
  &.hover {
    .pfTableSortableRow {
      &:hover {
        color: #495057;
        background-color: rgba(0,0,0,.075);
      }
    }
  }
}
</style>
