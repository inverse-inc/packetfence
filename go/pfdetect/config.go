package main

type ParserRuleAction struct {
	Method   string
	Template []string
}

type ParserRule struct {
	Name        string
	RegexStr    string
	Actions     []ParserRuleAction
	LastIfMatch bool
}

type ParserConfig struct {
	Type   string
	Path   string
	Id     string
	Status bool
	Rules  []ParserRule
}
