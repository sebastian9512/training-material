# Settings
JEKYLL=bundle exec jekyll
CHROME=google-chrome-stable
TUTORIALS=$(shell find _site/training-material -name 'tutorial.html' | sed 's/_site\/training-material\///')
SLIDES=$(shell find _site/training-material -name 'slides.html' | sed 's/_site\/training-material\///')
SLIDES+=$(shell find _site/training-material/*/*/slides/* | sed 's/_site\/training-material\///')
SITE_URL=http://localhost:4000/training-material
PDF_DIR=_pdf
REPO=$(shell echo "$${ORIGIN_REPO:-galaxyproject/training-material}")
BRANCH=$(shell echo "$${ORIGIN_BRANCH:-master}")
MINICONDA_URL = https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
SHELL=bash
CONDA_VERSION := $(shell conda --version 2>/dev/null)

ifeq ($(shell uname -s),Darwin)
	CHROME=/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome
	MINICONDA_URL=https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh
endif

default: help

serve: ## run a local server
	${JEKYLL} serve -d _site/training-material
.PHONY: serve

detached-serve: clean ## run a local server in detached mode
	${JEKYLL} serve --detach -d _site/training-material
.PHONY: detached-serve

build: clean ## build files but do not run a server
	${JEKYLL} build -d _site/training-material
.PHONY: build

check-html: build ## validate HTML
	bundle exec htmlproofer \
          --assume-extension \
          --http-status-ignore 405,503,999 \
          --url-ignore "/.*localhost.*/","/.*vimeo\.com.*/","/.*gitter\.im.*/","/.*drmaa\.org.*/" \
          --url-swap "github.com/galaxyproject/training-material/tree/master:github.com/${REPO}/tree/${BRANCH}" \
          --file-ignore "/.*\/files\/.*/","/.*\/node_modules\/.*/" \
          --allow-hash-href \
        ./_site
.PHONY: check-html

check-slides: build  ## check the markdown-formatted links in slides
	find _site -path "**/slides*.html" \
        | xargs -L 1 -I '{}' sh -c \
        "awesome_bot \
           --allow 405 \
           --allow-redirect \
           --white-list localhost,127.0.0.1,fqdn,vimeo.com,drmaa.com \
           --allow-ssl \
           --allow-dupe \
           --skip-save-results \
         -f {}"
.PHONY: check-slides

check-yaml: ## lint yaml files
	find . -path "**/*.yaml" | xargs -L 1 -I '{}' sh -c "yamllint {}"
.PHONY: check-yaml

check: check-yaml check-html check-slides  ## run all checks
.PHONY: check

check-links-gh-pages:  ## validate HTML on gh-pages branch (for daily cron job)
	bundle exec htmlproofer \
          --assume-extension \
          --http-status-ignore 405,503,999 \
          --url-ignore "/.*localhost.*/","/.*vimeo\.com.*/","/.*gitter\.im.*/","/.*drmaa\.org.*/" \
          --file-ignore "/.*\/files\/.*/" \
          --allow-hash-href \
        .
	find . -path "**/slides*.html" \
        | xargs -L 1 -I '{}' sh -c \
        "awesome_bot \
           --allow 405 \
           --allow-redirect \
           --white-list localhost,127.0.0.1,fqdn,vimeo.com,drmaa.com \
           --allow-ssl \
           --allow-dupe \
           --skip-save-results \
       -f {}"
.PHONY: check-links-gh-pages

clean: ## clean up junk files
	@rm -rf _site
	@rm -rf .sass-cache
	@find . -name .DS_Store -exec rm {} \;
	@find . -name '*~' -exec rm {} \;
.PHONY: clean

install-conda: ## install Miniconda
ifndef CONDA_VERSION
	wget $(MINICONDA_URL) -O miniconda.sh
	bash miniconda.sh -b
	conda config --set show_channel_urls yes --set always_yes yes
	conda update conda conda-env
	conda config --system --add channels conda-forge
	conda config --system --add channels defaults
	conda config --system --add channels r
	conda config --system --add channels bioconda
endif
.PHONY: install-conda

create-env: install-conda ## create conda environment
	conda env create -f environment.yml -q --force
.PHONY: create-env	

install: ## install dependencies
	npm install decktape
	gem install --install-dir $(CONDA_PREFIX) bundler
	bundle install
.PHONY: install

pdf: detached-serve ## generate the PDF of the tutorials and slides
	mkdir -p _pdf
	@for t in $(TUTORIALS); do \
		name="$(PDF_DIR)/$$(echo $$t | tr '/' '-' | sed -e 's/html/pdf/' -e 's/topics-//' -e 's/tutorials-//')"; \
		${CHROME} \
            --headless \
            --disable-gpu \
            --print-to-pdf="$$name" \
            "$(SITE_URL)/$$t?with-answers" \
            2> /dev/null ; \
    done
	@for s in $(SLIDES); do \
		name="$(PDF_DIR)/$$(echo $$s | tr '/' '-' | sed -e 's/html/pdf/' -e 's/topics-//' -e 's/tutorials-//')"; \
		`npm bin`/decktape \
			automatic \
			"$(SITE_URL)/$$s?with-answers" \
			"$$name" \
            2> /dev/null ; \
	done
	pkill -f jekyll
.PHONY: pdf

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help
