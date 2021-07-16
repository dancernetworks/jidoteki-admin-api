# Makefile

# Generic
.PHONY: all check run-tests html javascript js minify ui docs java

all: check

check: run-tests

run-tests:
		JIDO_ADMIN_PATH=$(PREFIX_DIR)/opt/jidoteki/tinyadmin ./test.l

html:
		jade -o . -P -E html ui/index.jade

javascript:
		cat ui/license.coffee ui/generic.coffee ui/ui.coffee | coffee --no-header -c -s > docs/ui.js

js: javascript

minify:
		head -n 8 docs/ui.js | tail -7 > docs/ui.min.js
		minify docs/ui.js >> docs/ui.min.js

java:
		cd password-validator && \
		javac -cp zxcvbn-1.5.2.jar ValidatePasswordStrength.java

docs:
		cd docs && \
		marked --gfm -i API.md -o api.tmp.html && \
		cat strapdown-prefix.html api.tmp.html strapdown-suffix.html > API.html && \
		rm api.tmp.html

ui: html javascript minify
