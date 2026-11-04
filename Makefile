dist/pyZDL.app:
	uv run python setup.py py2app

macos: dist/pyZDL.app

.PHONY: clean
clean:
	rm -rf dist/*

.PHONY: sync
sync:
	uv sync

.PHONY: test
test:
	uv run python -m unittest -v

.PHONY: lint
lint:
	uv run python -m ruff check .

.PHONY: format
format:
	uv run python -m black .

.PHONY: run
run:
	uv run python cli.py gui

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
	uv run python -m http.server -d pages/
