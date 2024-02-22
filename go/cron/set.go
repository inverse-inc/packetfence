package maint

type Set[E comparable] map[E]struct{}

func (s *Set[E]) Add(v E) {
	(*s)[v] = struct{}{}
}

func (s *Set[E]) AddIf(v E, f func(E) bool) {
	if f(v) {
		s.Add(v)
	}
}

func (s Set[E]) Contains(v E) bool {
	_, ok := s[v]
	return ok
}

func (s Set[E]) Members() []E {
	result := make([]E, 0, len(s))
	for v := range s {
		result = append(result, v)
	}
	return result
}

func NewSet[E comparable]() Set[E] {
	return Set[E]{}
}
