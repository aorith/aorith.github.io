#!/usr/bin/env make

export PATH := $(shell nix develop --command bash -c 'echo $$PATH')

PHONY: serve
serve:
	hugo server --buildDrafts

PHONY: new
new:
	bash new.sh

PHONY: generate-chroma-styles
generate-chroma-styles:
	# https://xyproto.github.io/splash/docs/all.html
	echo '@media (prefers-color-scheme: light) {' > ./themes/bw/assets/css/light.css
	hugo gen chromastyles --style=modus-operandi >> ./themes/bw/assets/css/light.css
	echo '}' >> ./themes/bw/assets/css/light.css
	echo
	echo '@media (prefers-color-scheme: dark) {' > ./themes/bw/assets/css/dark.css
	hugo gen chromastyles --style=monokai >> ./themes/bw/assets/css/dark.css
	echo '}' >> ./themes/bw/assets/css/dark.css
	echo
	prettier ./themes/bw/assets/css/light.css --write
	prettier ./themes/bw/assets/css/dark.css --write
