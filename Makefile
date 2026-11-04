dist/pyZDL.app:
	python setup.py py2app

macos: dist/pyZDL.app

.PHONY: clean
clean:
	rm -rf dist/*

PYTHON ?= python3

.PHONY: test
test:
	$(PYTHON) -m unittest -v

.PHONY: lint
lint:
	$(PYTHON) -m ruff check .

.PHONY: format
format:
	$(PYTHON) -m black .

.PHONY: run
run:
	$(PYTHON) cli.py gui

pages/index.html:
	mkdir -p pages/
	cp -av templates/site/*.html pages/.
	cp -av assets pages/assets

pages: pages/index.html

.PHONY: clean-pages
clean-pages:
	rm -rf pages/*

.PHONY: serve-pages
serve-pages: pages
	python -m http.server -d pages/
