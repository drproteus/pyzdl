dist/gui.app:
	python setup.py py2app

macos: dist/gui.app

.PHONY: clean
clean:
	rm -rf dist/*

.PHONY: test
test:
	python -m unittest
