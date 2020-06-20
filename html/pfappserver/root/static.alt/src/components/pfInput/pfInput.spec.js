import { factory, shallowFactory } from '@/utils/test'
import Component from './pfInput'

describe('Component', () => {
  it('has scoped data', () => {
    expect(Component.data.constructor).toBe(Function)
  })
})

describe('Handlers', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = shallowFactory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('provides @focus handler', async () => {
    // assert method exists
    expect('focus' in vm).toBe(true)

    // assert method
    expect(vm.focus.constructor).toBe(Function)
  })

  it('provides @blur handler', async () => {
    // assert method exists
    expect('blur' in vm).toBe(true)

    // assert method
    expect(vm.blur.constructor).toBe(Function)
  })
})


describe('Props', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('has <input ref="input">', () => {
    // assert input ref exists
    expect(wrapper.findAllComponents({ ref: 'input' }).exists()).toBe(true)
  })

  it('propagates :disabled => <input disabled=":disabled">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(false)

    wrapper.setProps({ disabled: true })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(true)
  })

  it('propagates :readonly => <input readonly=":readonly">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(false)

    wrapper.setProps({ readonly: true })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(true)
  })

  it('propagates :placeholder => <input placeholder=":placeholder">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe(null)

    wrapper.setProps({ placeholder: 'test' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe('test')
  })

  it('propagates :type => <input type=":type">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('type')).toBe('text')

    wrapper.setProps({ type: 'password' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('type')).toBe('password')
  })
})

describe('Value', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('propagates :value => <input value=":value">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe('')

    wrapper.setProps({ value: 'test' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe('test')
  })

  it('emits <input @input>', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().input).toBeFalsy()

    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().input).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().input.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().input[0]).toEqual(['test'])
  })

  it('emits <input @change>', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().change).toBeFalsy()

    wrapper.find('input[type="text"]').setValue('test')
    wrapper.find('input[type="text"]').trigger('change')
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().change).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().change.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().change[0]).toEqual(['test'])
  })
})
