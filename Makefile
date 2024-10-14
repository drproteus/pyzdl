dist/gui.app:
	python setup.py py2app --iconfile assets/doom-cacodemon.png

macos: dist/gui.app

.PHONY: clean
clean:
	rm -rf dist/*

.PHONY: test
test:
	python -m unittest -v
