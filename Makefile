SHELL := bash

PATH = $(shell nix develop --command bash -c 'echo $$PATH')

PHONY: serve
serve:
	rm -rf public
	hugo server --buildDrafts

PHONY: new
new:
	bash new.sh

PHONY: generate-chroma-styles
generate-chroma-styles:
	# https://xyproto.github.io/splash/docs/all.html
	echo '@media (prefers-color-scheme: light) {' > ./themes/mine/assets/css/light.css
	hugo gen chromastyles --style=modus-operandi >> ./themes/mine/assets/css/light.css
	echo '}' >> ./themes/mine/assets/css/light.css
	echo
	echo '@media (prefers-color-scheme: dark) {' > ./themes/mine/assets/css/dark.css
	hugo gen chromastyles --style=modus-vivendi >> ./themes/mine/assets/css/dark.css
	echo '}' >> ./themes/mine/assets/css/dark.css
	echo
	prettier ./themes/mine/assets/css/light.css --write
	prettier ./themes/mine/assets/css/dark.css --write

