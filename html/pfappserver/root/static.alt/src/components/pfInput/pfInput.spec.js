import { shallowMount } from '@vue/test-utils'
import Component from './pfInput'

const factory = ({ propsData = {}, mocks = {}, stubs = {}, methods = {} } = {}) => {
  // shallowMount
  return shallowMount(Component, { propsData, mocks, stubs, methods })
}

describe('Object', () => {
  it('has scoped data', () => {
    expect(Component.data.constructor).toBe(Function)
  })
})

describe('Component', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory()
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('wrapper mounted', () => {
    // assert wrapper was mounted
    expect(wrapper).toBeTruthy()
  })

  it('ref="input"', () => {
    // assert input ref exists
    expect(wrapper.findAllComponents({ ref: 'input' }).exists()).toBe(true)
  })

  it('prop :disabled', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(false)

    wrapper.setProps({ disabled: true })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(true)

    wrapper.setProps({ disabled: false })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(false)
  })

  it('prop :readonly', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(false)

    wrapper.setProps({ readonly: true })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(true)

    wrapper.setProps({ readonly: false })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(false)
  })

  it('prop :placeholder', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe(null)

    wrapper.setProps({ placeholder: 'test' })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe('test')

    wrapper.setProps({ placeholder: null })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe(null)
  })

  it('prop :value', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe('')

    wrapper.setProps({ value: 'test' })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe('test')

    wrapper.setProps({ value: null })
    await vm.$nextTick()
    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe(null)
  })

  it('event @input', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().input).toBeFalsy()

    vm.$emit('input', 'test')
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().input).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().input.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().input[0]).toEqual(['test'])
  })

  it('event @change', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().change).toBeFalsy()

    vm.$emit('change', 'test')
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().change).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().change.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().change[0]).toEqual(['test'])
  })
})
