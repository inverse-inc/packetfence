package main

import (
	"fmt"
	"reflect"

	"github.com/fatih/structtag"
	"gopkg.in/yaml.v2"
)

func GenerateSchema(s interface{}) *OpenAPISchema {
	visited := make(map[reflect.Type]string)
	return generateSchemaFromType(reflect.TypeOf(s), visited)
}

func generateSchemaFromType(t reflect.Type, visited map[reflect.Type]string) *OpenAPISchema {
	schema := &OpenAPISchema{}

	if t.Kind() == reflect.Ptr {
		t = t.Elem()
	}

	switch t.Kind() {
	case reflect.Struct:
		if name, found := visited[t]; found {
			schema.Ref = "#/components/schemas/" + name
			return schema
		}

		visited[t] = t.Name()

		schema.Type = "object"
		schema.Properties = make(map[string]*OpenAPISchema)

		for i := 0; i < t.NumField(); i++ {
			field := t.Field(i)
			tags, err := structtag.Parse(string(field.Tag))
			if err != nil {
				continue
			}

			jsonTag, err := tags.Get("json")
			fieldName := field.Name
			if err == nil && jsonTag.Name != "" {
				fieldName = jsonTag.Name
			}

			schema.Properties[fieldName] = generateSchemaFromType(field.Type, visited)
		}
	case reflect.Slice, reflect.Array:
		schema.Type = "array"
		schema.Items = generateSchemaFromType(t.Elem(), visited)
	case reflect.String:
		schema.Type = "string"
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		schema.Type = "integer"
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		schema.Type = "integer"
	case reflect.Float32, reflect.Float64:
		schema.Type = "number"
	case reflect.Bool:
		schema.Type = "boolean"
	default:
		schema.Type = t.Kind().String()
	}

	return schema
}

type OpenAPISchema struct {
	Type                 string                    `json:"type,omitempty" yaml:"type,omitempty"`
	Format               string                    `json:"format,omitempty" yaml:"format,omitempty"`
	Title                string                    `json:"title,omitempty" yaml:"title,omitempty"`
	Description          string                    `json:"description,omitempty" yaml:"description,omitempty"`
	Default              interface{}               `json:"default,omitempty" yaml:"default,omitempty"`
	Example              interface{}               `json:"example,omitempty" yaml:"example,omitempty"`
	Enum                 []interface{}             `json:"enum,omitempty" yaml:"enum,omitempty"`
	Items                *OpenAPISchema            `json:"items,omitempty" yaml:"items,omitempty"`
	Properties           map[string]*OpenAPISchema `json:"properties,omitempty" yaml:"properties,omitempty"`
	AdditionalProperties *OpenAPISchema            `json:"additionalProperties,omitempty" yaml:"additionalProperties,omitempty"`
	MinLength            *int                      `json:"minLength,omitempty" yaml:"minLength,omitempty"`
	MaxLength            *int                      `json:"maxLength,omitempty" yaml:"maxLength,omitempty"`
	Pattern              string                    `json:"pattern,omitempty" yaml:"pattern,omitempty"`
	Minimum              *float64                  `json:"minimum,omitempty" yaml:"minimum,omitempty"`
	Maximum              *float64                  `json:"maximum,omitempty" yaml:"maximum,omitempty"`
	ExclusiveMinimum     *float64                  `json:"exclusiveMinimum,omitempty" yaml:"exclusiveMinimum,omitempty"`
	ExclusiveMaximum     *float64                  `json:"exclusiveMaximum,omitempty" yaml:"exclusiveMaximum,omitempty"`
	MultipleOf           *float64                  `json:"multipleOf,omitempty" yaml:"multipleOf,omitempty"`
	Required             []string                  `json:"required,omitempty" yaml:"required,omitempty"`
	MinItems             *int                      `json:"minItems,omitempty" yaml:"minItems,omitempty"`
	MaxItems             *int                      `json:"maxItems,omitempty" yaml:"maxItems,omitempty"`
	UniqueItems          bool                      `json:"uniqueItems,omitempty" yaml:"uniqueItems,omitempty"`
	AllOf                []*OpenAPISchema          `json:"allOf,omitempty" yaml:"allOf,omitempty"`
	OneOf                []*OpenAPISchema          `json:"oneOf,omitempty" yaml:"oneOf,omitempty"`
	AnyOf                []*OpenAPISchema          `json:"anyOf,omitempty" yaml:"anyOf,omitempty"`
	Not                  *OpenAPISchema            `json:"not,omitempty" yaml:"not,omitempty"`
	ReadOnly             bool                      `json:"readOnly,omitempty" yaml:"readOnly,omitempty"`
	WriteOnly            bool                      `json:"writeOnly,omitempty" yaml:"writeOnly,omitempty"`
	Nullable             bool                      `json:"nullable,omitempty" yaml:"nullable,omitempty"`
	Ref                  string                    `json:"$ref,omitempty" yaml:"$ref,omitempty"`
}

type Person struct {
	Name     string `json:"name"`
	Age      int    `json:"age"`
	Email    string `json:"email"`
	Children []Person
}

func main() {
	schema := GenerateSchema(Person{})
	yamlSchema, _ := yaml.Marshal(schema)
	fmt.Println(string(yamlSchema))
}
