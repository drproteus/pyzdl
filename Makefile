dist/pyZDL.app:
	python setup.py py2app --iconfile assets/doom-cacodemon.png

macos: dist/pyZDL.app

.PHONY: clean
clean:
	rm -rf dist/*

.PHONY: test
test:
	python -m unittest -v

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
