MJML_FILES=$(wildcard emails*.mjml)
HTML_FILES=$(MJML_FILES:.mjml=.html)

export PATH := node_modules/.bin:$(PATH)

all: info init html

clean:
	rm *.html

info:
	echo "https://mjml.io/"

init:
	npm install

%.html: %.mjml
	mjml -r $< -o $@

html: $(HTML_FILES)
