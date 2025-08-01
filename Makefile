SHELL := nix develop --command bash

serve:
	rm -rf public && \
	hugo server --buildDrafts --bind 0.0.0.0

new:
	bash new.sh

# https://xyproto.github.io/splash/docs/all.html
generate-chroma-styles:
	export light_theme="./themes/mine/assets/sass/light.scss" && \
	export dark_theme="./themes/mine/assets/sass/dark.scss" && \
	echo '@media (prefers-color-scheme: light) {' > "$$light_theme" && \
	hugo gen chromastyles --style=modus-operandi >> "$$light_theme" && \
	echo '}' >> "$$light_theme" && \
	echo '@media (prefers-color-scheme: dark) {' > "$$dark_theme" && \
	hugo gen chromastyles --style=modus-vivendi >> "$$dark_theme" && \
	echo '}' >> "$$dark_theme" && \
	prettier "$$light_theme" --write && \
	prettier "$$dark_theme" --write

.PHONY: serve new generate-chroma-styles
