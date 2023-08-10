package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"strings"
)

func Generator() {
	sourceFile := "example.go"
	outputFile := "generated.go"

	// Read the source file.
	source, err := ioutil.ReadFile(sourceFile)
	if err != nil {
		fmt.Println("Error reading source file:", err)
		os.Exit(1)
	}

	// Parse the source file.
	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, sourceFile, source, parser.ParseComments)
	if err != nil {
		fmt.Println("Error parsing source file:", err)
		os.Exit(1)
	}

	// Generate new Go code from comments.
	var output strings.Builder
	output.WriteString("package main\n\n")
	ast.Inspect(node, func(n ast.Node) bool {
		switch x := n.(type) {
		case *ast.TypeSpec:
			if x.Doc != nil {
				output.WriteString("/*\n")
				output.WriteString(x.Doc.Text())
				output.WriteString("*/\n")
				output.WriteString("type ")
				output.WriteString(x.Name.Name)
				output.WriteString(" struct {\n")

				// Iterate through the struct fields.
				structType := x.Type.(*ast.StructType)
				for _, field := range structType.Fields.List {
					if len(field.Names) > 0 && field.Doc != nil {
						output.WriteString("\t")
						output.WriteString(field.Doc.Text())
						output.WriteString("\t")
						output.WriteString(field.Names[0].Name)
						output.WriteString(" ")
						output.WriteString(getTypeString(field.Type))
						output.WriteString("\n")
					}
				}

				output.WriteString("}\n\n")
			}
		case *ast.FuncDecl:
			if x.Doc != nil {
				output.WriteString("/*\n")
				output.WriteString(x.Doc.Text())
				output.WriteString("*/\n")
				output.WriteString("func ")
				output.WriteString(x.Name.Name)
				output.WriteString("() {\n")
				output.WriteString("\t// TODO: Implement function\n")
				output.WriteString("}\n\n")
			}
		}
		return true
	})

	// Write the generated code to the output file.
	err = ioutil.WriteFile(outputFile, []byte(output.String()), 0644)
	if err != nil {
		fmt.Println("Error writing to output file:", err)
		os.Exit(1)
	}

	fmt.Printf("Generated code written to %s\n", outputFile)
}

func getTypeString(expr ast.Expr) string {
	switch t := expr.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.SelectorExpr:
		return fmt.Sprintf("%s.%s", getTypeString(t.X), t.Sel.Name)
	case *ast.StarExpr:
		return fmt.Sprintf("*%s", getTypeString(t.X))
	case *ast.ArrayType:
		return fmt.Sprintf("[]%s", getTypeString(t.Elt))
	case *ast.MapType:
		return fmt.Sprintf("map[%s]%s", getTypeString(t.Key), getTypeString(t.Value))
	case *ast.InterfaceType:
		return "interface{}"
	case *ast.ChanType:
		return fmt.Sprintf("chan %s", getTypeString(t.Value))
	case *ast.FuncType:
		return "func()"
	default:
		return "<unknown type>"
	}
}
