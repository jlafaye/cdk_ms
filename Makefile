# Agnostic Python Makefile
#
APM_MAKEFILE_VERSION = 0.29.0
#
# copyright : cfm, 2020
# author    : jdhalimi
# team      : it-core
#
# MODIFICATION IS NOT RECOMMENDED TO ENJOY FURTHER UPGRADES
#
# customization available via optional config.mk and custom.mk files.
# https://confluence.fr.cfm.fr/display/ITCORE/apm+-+Python+Makefile
#
# =============================================================================

.SUFFIXES:
.SUFFIXES: .mk .recursive

MAKEFLAGS += -r
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --warn-undefined-variables

SHELL=/bin/bash


# -----------------------------------------------------------------------------
# environment variables used (declared to avoid further unused warning)
# -----------------------------------------------------------------------------
CONDA_DEFAULT_ENV ?=
CONDA_PREFIX ?=

CFM_ENV_VERSION ?=
CFM_ENV_PATH ?=
VIRTUAL_ENV ?=
CONDA_DEFAULT_ENV ?=
HTTP_PROXY ?=
HTTPS_PROXY ?=
TMPDIR ?=
WORKSPACE ?=
TMP_AUTO_ENVNAME ?=
TMP_ENV_LOCATION ?=
TMP_ENV_TYPE ?=
TMP_ENV_SUBFOLDER ?=
NUMPY_VERSION ?=

APM_MAKEFILE_DIST ?=
APM_PIP_ISOLATION ?= yes

# -----------------------------------------------------------------------------
# system commands
# -----------------------------------------------------------------------------
CD = cd
CP = cp
CHMOD := chmod
CURL = /usr/bin/curl --silent
ECHO = @echo -e
FIND = find
LN = ln -s
MV = mv
RM = rm -rf
WGET = wget
READLINK := readlink -m
TOUCH = touch
PYTHON = python
JQ = /usr/bin/jq


ifeq ($(shell uname),Darwin)
ECHO := @echo
READLINK := readlink
endif

# -----------------------------------------------------------------------------
# constants used
# -----------------------------------------------------------------------------
DEFAULT_BUILD_REQ_TXT := $(wildcard build-requirements.txt)
DEFAULT_BUILD_REQ_CONDA := $(wildcard build-requirements.conda)
DEFAULT_BUILD_REQ_PIP := $(wildcard build-requirements.pip)
DEFAULT_DOCS_REQUIREMENTS := $(wildcard docs-requirements.txt)
DEFAULT_CONDA_REQUIREMENTS := $(wildcard conda-requirements.txt)
DEFAULT_PIP_REQUIREMENTS := $(wildcard requirements.txt)
DEFAULT_DEPLOY_REQUIREMENTS := $(wildcard deploy-requirements.txt)

DEFAULT_LINE_LENGTH := 120
DEFAULT_APM_STYLE_CHECK := pep8
DEFAULT_SONAR_URL := https://sonar.fr.cfm.fr
DEFAULT_REPO_NAME := repository.development.cfm.fr
DEFAULT_CFM_PYPI := pypi.infra.cfm.fr
DEFAULT_APM_ENVS := apm
DEFAULT_RESEARCH_MAINTAINER := /opt/research-maintainer/cfm
DEFAULT_FRONT_MAINTAINER := /opt/front-maintainer/cfm
DEFAULT_CONDA_MAINTAINER := /opt/conda-maintainer
DEFAULT_BUILD_MAINTAINER := /opt/build-maintainer/cfm
DEFAULT_CFM_BASHRC := etc/cfm-bashrc
DEFAULT_REPO_URL := https://$(DEFAULT_REPO_NAME)

DEFAULT_CHANNEL_ALIAS := $(DEFAULT_REPO_URL)/conda
DEFAULT_CHANNEL_APM := $(DEFAULT_CHANNEL_ALIAS)/cfm_common
DEFAULT_APM_INDEX_URL := $(DEFAULT_REPO_URL)/cfm-common/python/

# use simple = to allow post definition of LINE_LENGTH
PEP8_LINE_LENGTH ?= $(DEFAULT_LINE_LENGTH)
DEFAULT_FLAKE8_OPTS = --max-line-length=$(PEP8_LINE_LENGTH) --extend-ignore E203

ifeq ($(APM_PIP_ISOLATION),yes)
DEFAULT_PIP_OPTIONS := --index-url $(DEFAULT_APM_INDEX_URL)
DEFAULT_PIP_OPTIONS += --trusted-host $(DEFAULT_REPO_NAME)
DEFAULT_PIP_OPTIONS += --isolated --cert /etc/ssl/certs/ca-bundle.crt
PIP_OPTIONS_APM := $(DEFAULT_PIP_OPTIONS)
else
DEFAULT_PIP_OPTIONS := --index-url http://$(DEFAULT_CFM_PYPI)/simple/
DEFAULT_PIP_OPTIONS += --trusted-host $(DEFAULT_CFM_PYPI)
DEFAULT_PIP_OPTIONS += --trusted-host $(DEFAULT_REPO_NAME)
PIP_OPTIONS_APM := $(DEFAULT_PIP_OPTIONS) --extra-index-url $(DEFAULT_APM_INDEX_URL)
endif

DEFAULT_CONDA_PLATFORM := noarch

CST_REPOSITORY_CFM_URL := $(DEFAULT_REPO_URL)/cfm
CST_REPOSITORY_CFM_VERSION := version
CST_REPOSITORY_CFM_OLD_VERSION := $(CST_REPOSITORY_CFM_URL)/old/$(CST_REPOSITORY_CFM_VERSION)
CST_REPOSITORY_CFM_NXT_VERSION := $(CST_REPOSITORY_CFM_URL)/rc/$(CST_REPOSITORY_CFM_VERSION)
CST_REPOSITORY_CFM_CUR_VERSION := $(CST_REPOSITORY_CFM_URL)/current/$(CST_REPOSITORY_CFM_VERSION)

DEFAULT_MAKEFILE_VERSION_URL := $(DEFAULT_REPO_URL)/it-core/tools/python/Makefile.version

CST_NULL  :=
CST_SPACE := $(CST_NULL) # dot remove this
CST_COMMA := ,

CST_TYPE_CONDA := conda
CST_TYPE_PREFIX := condaprefix
CST_TYPE_VIRTUALENV := virtualenv
CST_TYPE_RESEARCH := research
CST_TYPE_FRONT := front
CST_TYPE_SCL := scl
CST_TYPE_LIST := $(CST_TYPE_CONDA) $(CST_TYPE_PREFIX) $(CST_TYPE_VIRTUALENV) $(CST_TYPE_RESEARCH) $(CST_TYPE_FRONT)
CST_TYPE_DEFAULT := $(CST_TYPE_CONDA)

THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_PROJECT := $(notdir $(patsubst %/,%,$(dir $(THIS_MAKEFILE))))
THIS_DIRECTORY := $(dir $(THIS_MAKEFILE))

# -----------------------------------------------------------------------------
# environment variable patches
# -----------------------------------------------------------------------------

# in research/front maintainers CONDA_DEFAULT_ENV should be removed
ifneq ($(findstring $(DEFAULT_RESEARCH_MAINTAINER),$(strip $(CONDA_DEFAULT_ENV))),)
CONDA_DEFAULT_ENV :=
endif
ifneq ($(findstring $(DEFAULT_FRONT_MAINTAINER),$(strip $(CONDA_DEFAULT_ENV))),)
CONDA_DEFAULT_ENV :=
endif

ENV_CONDA_PREFIX :=
TMP_ORIGIN := $(origin CONDA_PREFIX)
ifeq ($(TMP_ORIGIN),environment)
ENV_CONDA_PREFIX := $(CONDA_PREFIX)
else ifeq ($(TMP_ORIGIN),command line)
_ENVIRONMENT_TYPE := $(CST_TYPE_PREFIX)
_ENVIRONMENT_NAME := $(shell basename $(shell $(READLINK) $(CONDA_PREFIX)))
_ENVIRONMENT_LOCATION := $(shell dirname $(shell $(READLINK) $(CONDA_PREFIX)))
APM_CONDA_PREFIX := $(CONDA_PREFIX)
endif

# -----------------------------------------------------------------------------
# phony goals
# -----------------------------------------------------------------------------
.PHONY: env                            ##T.ENV##    creates build environment
.PHONY: env-create                             #       - creates environment
.PHONY: env-install                            #       - installs project and dependencies
.PHONY: env-build                              #       - install dev requirements
.PHONY: env-docs                               #       - installs docs requirements
.PHONY: clean                          ##T.ENV##    removes build artefacts
.PHONY: distclean                      ##T.ENV##    remove build artefacts and environment
.PHONY: clean-pyc                              #       - remove python pyc
.PHONY: upgrade-me                     ##T.ENV##    upgrades makefile with last version
.PHONY: ipykernel                      ##T.ENV##    integrate environment to jupyter

.PHONY: clean-env-artefacts                    #
.PHONY: clean-artefacts                        #
.PHONY: clean-env-artefacts                    #

.PHONY: pep8                           ##T.TST##    (deprecated: use style) runs pep8 checks on project and tests
.PHONY: mypy                           ##T.TST##    runs mypy checks on project and tests
.PHONY: pylint                         ##T.TST##    runs pylint on project
.PHONY: cfm-lint                       ##T.TST##    runs cfm-lint on project
.PHONY: black                          ##T.TST##    (deprecated: use style) checks black formatting
.PHONY: black-reformat                 ##T.TST##    formats with black
.PHONY: style                          ##T.TST##    runs style checks

.PHONY: tests_
.PHONY: coverage_                              #
.PHONY: tests-trial                            #    make tests with trial
.PHONY: tests-pytest                           #    make tests with pytest
.PHONY: coverage-trial                         #    make coverage with trial
.PHONY: coverage-pytest                        #    make coverage with pytest

.PHONY: tests                          ##T.TST##    runs projects tests
.PHONY: tests-fast                     ##T.TST##    runs projects tests
.PHONY: tests-full                     #T.TST##    runs projects tests
.PHONY: coverage                       ##T.TST##    run tests and coverage on default scope
.PHONY: coverage-fast                  ##T.TST##    run tests and coverage on fast scope
.PHONY: coverage-full                  ##T.TST##    run tests and coverage on full scope
.PHONY: coverage-check                 ##T.TST##    checks coverage rate
.PHONY: fake-junit                     ##T.TST##    force creation of a dummy junit file.

.PHONY: clean-tests                            #
.PHONY: clean-coverage                         #    remove coverage artefacts

.PHONY: sonar-issues                   ##T.TST##    runs sonar analysis and print issues
.PHONY: sonar-preview                  ##T.TST##    runs sonar analysis and render a local report
.PHONY: sonar-upload                   ##T.TST##    runs sonar analysis and upload results

.PHONY: sdist-pkg                      ##T.PKG##    creates a pip sdist package
.PHONY: sdist-upload                   ##T.PKG##    upload pip sdist package to webdav repository
.PHONY: sdist-check-upload                     #    check package version does not exists on repository
.PHONY: conda-pkg                      ##T.PKG##    creates a conda package from uploaded sdist package
.PHONY: conda-recipe                   ##T.PKG##    creates conda recipe from sdist package
.PHONY: conda-upload                   ##T.PKG##    uploads conda package to webdav
.PHONY: conda-check-upload             ##T.PKG##    check package version does not exists on repository
.PHONY: clean-package                  ##T.PKG##    remove package artefacts
.PHONY: dist                           ##T.PKG##    produces the full build distribution
.PHONY: dist-properties                ##T.PKG##    produces build properties

.PHONY: docs                           ##T.DOC##    builds documentation with sphinx
.PHONY: clean-docs                             #    cleans documentation artefacts
.PHONY: docs-upload                    ##T.DOC##    uploads documentation package to webdav

.PHONY: info                           ##T.HLP##    information about current project
.PHONY: help                                   #    this help

.PHONY: help-goals                     ##T.HLP##    makefile goals details
.PHONY: help-config                    ##T.HLP##    makefile customization variables
.PHONY: help-env                       ##T.HLP##    environment manipulation
.PHONY: help-tests                     ##T.HLP##    tests related information
.PHONY: help-docs                      ##T.HLP##    docs related information
.PHONY: help-package                   ##T.HLP##    packaging related information

# -----------------------------------------------------------------------------
# switch between single / multi
# -----------------------------------------------------------------------------
.PHONY: multi-clean         single-clean
.PHONY: multi-pep8          single-pep8
.PHONY: multi-mypy          single-mypy
.PHONY: multi-pylint        single-pylint
.PHONY: multi-style         single-style
.PHONY: multi-tests         single-tests
.PHONY: multi-test-only     single-tests-only
.PHONY: multi-tests-fast    single-tests-fast
.PHONY: multi-tests-full    single-tests-full
.PHONY: multi-coverage      single-coverage
.PHONY: multi-coverage-fast single-coverage-fast
.PHONY: multi-coverage-full single-coverage-full
.PHONY: multi-docs          single-docs

# -----------------------------------------------------------------------------
# docker
# -----------------------------------------------------------------------------

.PHONY: docker-build
.PHONY: docker-push
.PHONY: docker-login
.PHONY: docker-clean

# -----------------------------------------------------------------------------
# utility functions
# -----------------------------------------------------------------------------

define print_info
	printf "\n\033[1m%s\033[0m\n" $1
endef

define print_param
	printf "\033[36m%-25s\033[0m %s\n" $1 $2
endef

define print_action
	@$(call print_header)
	printf "\033[36m%s\033[0m\n" $1
endef

define print_error
	printf "\033[0;31m%s\033[0m\n" $1
endef

define print_success
	printf "\033[0;32m%s\033[0m\n" $1
endef

define print_header
	@$(MAKEFILE_HEADER)
	$(eval MAKEFILE_HEADER := )
endef

define print_help_comment
	python -c "print ('%s\n' % '\n'.join(map(lambda x : '\033[36m%-25s\033[0m %s'% x, \
		map(lambda x: (x[0].replace('.PHONY:','').split()[0],x[2].strip()), \
		filter(lambda x: len(x) == 3 and '$1' in x[1], map(lambda x: x.split('##'), open('$(THIS_MAKEFILE)')))))))"
endef

# -----------------------------------------------------------------------------
# start with variables shell
# -----------------------------------------------------------------------------
ENV_ERROR :=
ENV_WARNINGS :=

# -----------------------------------------------------------------------------
# include custom configuration
# -----------------------------------------------------------------------------
-include $(wildcard user.mk)
-include $(wildcard ~/.apm/python/config.mk)
-include $(wildcard config.mak)
-include $(wildcard config.mk)
-include $(wildcard user.mak)

# -----------------------------------------------------------------------------
# configuration variables (override by export, commandline or config.mak)
# -----------------------------------------------------------------------------

ENVIRONMENT_TYPE ?= 										##C.ENV##    $(CST_TYPE_LIST)
ENVIRONMENT_VERSION ?= 										##C.ENV##    technical stack version (current/rc/...)
ENVIRONMENT_NAME ?= 										##C.ENV##    environment name (virtualenv, conda)
ENVIRONMENT_LOCATION ?= 									##C.ENV##    environment location
RESEARCH_MAINTAINER ?=										##C.ENV##    research-maintainer version (current/rc/...)
FRONT_MAINTAINER ?=											##C.ENV##    font-maintainer version (current/rc/...)
DONT_USE_BUILD_MAINTAINER ?= 								##C.ENV##    Force fresh install of components run from the build-maintainer
BUILD_MAINTAINER ?= current                                 ##C.ENV##    build-maintainer version (current/rc/...)

ADD_TESTS_OPTS ?=                                			##C.TST##    extra tests parameters
APM_AUTO_ENVNAME ?=                                         ##C.ENV##    environment name by default
APM_CONDA_CHANNELS ?=                                       ##C.ENV##    conda channels to override
APM_EXTRA_CONDA_CHANNELS ?=									##C.ENV##    extra conda channels to override (paths, links, etc...)
APM_CONDA_VERSION ?=                                        ##C.ENV##    conda version to use (old, current, rc, conda-4.6.14...)
APM_BUILD_NUMBER ?= 1                                       ##C.ENV##    Force build number for conda package.
APM_BUILD_NUMBER_FOLLOW_CI_NUMBER ?= yes                    ##C.ENV##    set build number as conda package build no
APM_BUILD_TYPE ?=
APM_USE_PRE_CHANNEL ?=
APM_BRANCH_NAME ?=
APM_EXTRA_INDEX_URLS ?=										##C.ENV##    CFM pip extra index url to override
APM_CONDA_PLATFORM ?= $(DEFAULT_CONDA_PLATFORM)             ##C.PKG##    Specify the target architecture for conda (linux-64, noarch, etc.)
APM_MULTI_ENV ?=                                            ##C.ENV##    folders for apm install (multi-projects)
APM_INSTALL_OPTIONS ?=                                      ##C.ENV##    extra options for apm install (multi-projects)
APM_PACKAGE ?= apm                                          ##C.ENV##    force apm package spec (ex. apm==0.1.2)
APM_PYTHON_VERSION ?=                                       ##C.ENV##    enforce python version for environment
APM_ENV_ACTIVATE ?=                                         ##C.ENV##    enforce activation script name
BUILD_DIR ?=                                                ##C.ENV##    build results directory
BUILD_REQUIREMENTS ?= $(DEFAULT_BUILD_REQ_TXT)              ##C.ENV##    extra build requirements for both pip and conda
BUILD_REQUIREMENTS_CONDA ?= $(DEFAULT_BUILD_REQ_CONDA)      ##C.ENV##    extra build requirements for conda
BUILD_REQUIREMENTS_PIP ?= $(DEFAULT_BUILD_REQ_PIP)          ##C.ENV##    extra build requirements for pip
COVERAGE_INCLUDE ?=                                         ##C.TST##    coverage exclusion files
COVERAGE_LIMIT ?= 0                                         ##C.TST##    coverage inclusion files
COVERAGE_OMIT ?=                                            ##C.TST##    coverage ignored files
DOCS_DIR ?= docs                                            ##C.DOC##    location of docs folder
APM_DOCS_OUTPUT ?=								            ##C.DOC##    output directory for building docs
DOCS_REQUIREMENTS ?= $(DEFAULT_DOCS_REQUIREMENTS)           ##C.ENV##    extra requirements for docs
APM_STYLE_CHECK ?= $(DEFAULT_APM_STYLE_CHECK)               ##C.TST##    list of tools for style checking
BLACK_LINE_LENGTH ?= 88                                     ##C.TST##    line length for black
USE_PYPROJECT_TOML ?= no                                    ##C.TST##    use settings from pyproject.toml (for black, ...)
PEP8_LINE_LENGTH ?= $(DEFAULT_LINE_LENGTH)                  ##C.TST##    line length for pep8
FLAKE8_MODULES ?=                                           ##C.TST##    flake8 checks inclusion
FLAKE8_OPTIONS ?= $(DEFAULT_FLAKE8_OPTS)                    ##C.TST##    flake8 options
FORCED ?= no												##C.ENV##    bypass checks in upgrade-me (yes/no)
FORCE_UPLOAD ?= no                                          ##C.PKG##    bypass checks during upload (yes/no)
MAINTAINER_ENVIRONMENT ?=									##C.ENV##    maintainer script to source
PACKAGE_MODULES ?=                                          ##C.PKG##    enforce package directory location
PACKAGE_NAME ?=                                             ##C.PKG##    enforce package name
PACKAGE_EGG ?=                                              ##C.PKG##    Name of the generated egg-info
PACKAGE_TEAM ?=                                             ##C.PKG##    enforce package team
PACKAGE_VERSION ?=                                          ##C.PKG##    enforce package version (deprecated)
PIP_OPTIONS ?= $(DEFAULT_PIP_OPTIONS)                       ##C.PKG##    overrides pip install options
MYPY_OPTIONS ?=                                             ##C.TST##    overrides mypy options
MYPY_PACKAGES ?=                                            ##C.TST##    overrides mypy options
PYLINT_OPTIONS ?= --reports=n                               ##C.TST##    overrides pylint options
PYTEST_OPTIONS ?= -v -s --doctest-modules                   ##C.TST##    overrides pytest options
PYTEST_MONITOR ?= no                                        ##C.TST##    set on yes to enable pytest monitor
PYTEST_MONITOR_COMPONENT ?= $(PACKAGE_NAME)                 ##C.TST##    Component to report when using pytest-monitor
PYTEST_MONITOR_SERVER ?= http://itco030.vm.cfm.fr:8050      ##C.TST##    Server for pytest-monitor
PYTEST_PLUGINS ?= -p no:cacheprovider                       ##C.TST##    Control pytest plugins to load or unload.
PROFILE ?= no                                               ##C.TST##    flag to enable profiling
REPOSITORY_CURRENT_DOC ?= latest                            ##C.PKG##    remote repository subfolder for latest doc
REPOSITORY_PASSWORD ?=                                      ##C.PKG##    remote repository password for upload
REPOSITORY_SPACE ?=                                         ##C.PKG##    remote repository space for upload
REPOSITORY_URL ?= $(DEFAULT_REPO_URL)                       ##C.PKG##    overrides cfm package repository url
REPOSITORY_USER ?=                                          ##C.PKG##    remote repository user for upload
REQUIREMENTS_PIP ?= $(DEFAULT_PIP_REQUIREMENTS)             ##C.ENV##    overrides requirements.txt
REQUIREMENTS_CONDA ?= $(DEFAULT_CONDA_REQUIREMENTS)         ##C.ENV##    overrides conda-requirements.txt
SCRIPTS_DIR ?= scripts                                      ##C.PKG##    enforce project scripts location
SKIP_ENV ?= no                                              ##C.ENV##    skip env creation on targets
SONAR_ISSUES_OPTIONS ?= --new                               ##C.TST##    sonar analysis options for issue mode
SONAR_RUNNER ?=                                             ##C.DEV##    overrides sonar-scanner location
SONAR_TOKEN ?=                                              ##C.DEV##    sonar identification token
SONAR_URL ?= $(DEFAULT_SONAR_URL)                           ##C.DEV##    overrides cfm sonar server url
SOURCES_DIR ?=                                              ##C.PKG##    enforce sources directory location
SONAR_EXCLUSIONS ?= **/tests/**                             ##C.DEV##    enforce sources directory location
TESTS_BEFORE_DEPENDENCIES ?=                                ##C.TST##    enforce tests prerequisites  (ex. env)
TESTS_DIR ?= tests                                          ##C.TST##    enforce default tests location
TESTS_EXTRA_DEPENDENCIES ?= style                           ##C.TST##    enforce tests post treatments (ex. pep8)
TESTS_MARKERS_FAST ?= not (slow or full)                    ##C.TST##    overrides tests markers for tests-fast
TESTS_MARKERS_DEFAULT ?= not full                           ##C.TST##    default tests markers for fast and slow
TESTS_MARKERS_FULL ?=                                       ##C.TST##    overrides tests markers for tests-full
PYTEST_MARKERS ?=                                           ##C.TST##    Markers to use. Default value depends on make target.
TESTS_TOOL ?= pytest                                        ##C.TST##    enforce python tests runner
TESTS_FILTER ?=                                             ##C.TST##    enforce python tests runner
VERBOSE ?=                                                  ##C.ENV##    force makefile displays command (yes/no)

MTRC_ENVIRONMENT ?=                                         ##C.ENV##    deprecated: use alias RESEARCH_MAINTAINER
VIRTUAL_ENVIRONMENT ?=                                      ##C.ENV##    deprecated: ENVIRONMENT_TYPE / ENVIRONMENT_NAME
APM_CONDA_PREFIX ?=                                         ##C.ENV##    deprecated: ENVIRONMENT_TYPE / ENVIRONMENT_NAME
CONDA_ENVIRONMENT ?=                                        ##C.ENV##    deprecated: ENVIRONMENT_TYPE / ENVIRONMENT_NAME


# ------------------------------
# docker
# ------------------------------

DOCKER = docker

DOCKER_REMOTE_CHANNEL ?=
DOCKER_IMAGE_NAME ?= $(PACKAGE_NAME)
DOCKER_IMAGE_VERSION ?= $(word 1,$(subst +, ,$(PACKAGE_VERSION)))
DOCKER_REGISTRY ?= artifactory.fr.cfm.fr:443

_DOCKER_IMAGE_TAG=$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)
_DOCKER_REGISTRY_URL ?= https://$(DOCKER_REGISTRY)/
_DOCKER_FILE = $(or $(wildcard Dockerfile),$(wildcard docker/Dockerfile))


ifneq ($(WORKSPACE),)
_DOCKER_BUILD_FLAGS = --pull --no-cache -f $(_DOCKER_FILE)
else
_DOCKER_BUILD_FLAGS = -f $(_DOCKER_FILE)
endif


_ENVIRONMENT_TYPE := $(ENVIRONMENT_TYPE)
_ENVIRONMENT_NAME := $(ENVIRONMENT_NAME)
_ENVIRONMENT_LOCATION := $(ENVIRONMENT_LOCATION)

# translate parameters: RESEARCH_MAINTAINER, FRONT_MAINTAINER, MAINTAINER_ENVIRONMENT
ifneq ($(RESEARCH_MAINTAINER),)
	_ENVIRONMENT_TYPE := $(CST_TYPE_RESEARCH)
else ifneq ($(FRONT_MAINTAINER),)
	_ENVIRONMENT_TYPE := $(CST_TYPE_FRONT)
endif

# For the next few blocks, ENV_VERSION is the variable we use to compute the canonical name
# We'll resolve it and put it back into the ENVIRONMENT_VERSION variable, used by the CJL.
ENV_VERSION:= $(word 1, $(RESEARCH_MAINTAINER) $(FRONT_MAINTAINER) $(ENVIRONMENT_VERSION) $(CFM_ENV_VERSION) current)

# in Bamboo or Jenkins force directory
ENV_INSIDE_CI_BUILD := no
CONDA_SKELETON_EXTRA_OPTIONS :=
ifneq ($(WORKSPACE),)
_ENVIRONMENT_LOCATION := $(WORKSPACE)/$(DEFAULT_APM_ENVS)
ENV_INSIDE_CI_BUILD := yes
ifeq ($(strip $(APM_BUILD_NUMBER_FOLLOW_CI_NUMBER)),yes)
APM_BUILD_NUMBER := $(BUILD_NUMBER)
CONDA_SKELETON_EXTRA_OPTIONS := --build-number $(APM_BUILD_NUMBER)
endif
endif


# variants handling here. For 1901-sp2-py3, LEVEL=1901, VARIANT=sp2, PYTHON=py3,
# we support LEVEL, LEVEL-PYTHON, LEVEL-VARIANT, or LEVEL-VARIANT-PYTHON
_TMP_ENVIRONMENT_LEVEL := $(strip $(shell echo $(ENV_VERSION) | cut -d'-' -f1))
_TMP_ENVIRONMENT_VARIANT := $(strip $(shell echo $(ENV_VERSION) | cut -d'-' -f2 -s))
_TMP_ENVIRONMENT_PYTHON := $(strip $(shell echo $(ENV_VERSION) | cut -d'-' -f3 -s))


# LEVEL-PYTHON ?
ifeq ($(_TMP_ENVIRONMENT_VARIANT),py3)
_TMP_ENVIRONMENT_PYTHON := py3
_TMP_ENVIRONMENT_VARIANT :=
endif

ifeq ($(_TMP_ENVIRONMENT_VARIANT),py2)
_TMP_ENVIRONMENT_PYTHON := py2
_TMP_ENVIRONMENT_VARIANT :=
endif

# LEVEL-VARIANT or LEVEL-VARIANT-PYTHON ?
ifneq ($(_TMP_ENVIRONMENT_VARIANT),)
ENV_VERSION := $(_TMP_ENVIRONMENT_LEVEL)-$(_TMP_ENVIRONMENT_VARIANT)
else
ENV_VERSION := $(_TMP_ENVIRONMENT_LEVEL)
endif

ifeq ($(_TMP_ENVIRONMENT_PYTHON),py3)
APM_PYTHON_VERSION = 3
else ifeq ($(_TMP_ENVIRONMENT_PYTHON),py2)
APM_PYTHON_VERSION = 2
endif


ifeq ($(APM_PYTHON_VERSION),)
ifeq ($(_TMP_ENVIRONMENT_PYTHON),)
APM_PYTHON_VERSION := 3
endif
endif

# -----------------------------------------------------------------------------
# adjust deprecated arguments
# -----------------------------------------------------------------------------

ifneq ($(CONDA_ENVIRONMENT),)
_ENVIRONMENT_TYPE := $(CST_TYPE_CONDA)
_ENVIRONMENT_NAME := $(CONDA_ENVIRONMENT)
else ifneq ($(VIRTUAL_ENVIRONMENT),)
_ENVIRONMENT_TYPE := $(CST_TYPE_VIRTUALENV)
_ENVIRONMENT_NAME := $(shell basename $(shell $(READLINK) $(VIRTUAL_ENVIRONMENT)))
_ENVIRONMENT_LOCATION := $(shell dirname $(shell $(READLINK) $(VIRTUAL_ENVIRONMENT)))
else ifneq ($(APM_CONDA_PREFIX),)
_ENVIRONMENT_TYPE := $(CST_TYPE_PREFIX)

_ENVIRONMENT_NAME := $(shell basename $(shell $(READLINK) $(APM_CONDA_PREFIX)))
_ENVIRONMENT_LOCATION := $(shell dirname $(shell $(READLINK) $(APM_CONDA_PREFIX)))
else ifneq ($(MTRC_ENVIRONMENT),)
_ENVIRONMENT_TYPE := $(CST_TYPE_RESEARCH)
endif

# Legacy support: Removed the ability of MTRC_ENVIRONMENT and MAINTAINER_ENVIRONMENT to impact ENV_VERSION

APM_CONDA_PREFIX :=
VIRTUAL_ENVIRONMENT :=
CONDA_ENVIRONMENT :=
MTRC_ENVIRONMENT :=


# -----------------------------------------------------------------------------
# translate alias arguments
# -----------------------------------------------------------------------------
ifeq ($(ENV_INSIDE_CI_BUILD),yes)
APM_ENV_ACTIVATE := env_activate
VERBOSE := yes
ifeq ($(strip $(BUILD_DIR)),)
BUILD_DIR := build
endif
endif

# -----------------------------------------------------------------------------
# translate alias arguments
# -----------------------------------------------------------------------------

# expand version and replace whatever was given to us. The CJL uses the ENVIRONMENT_VERSION flag
override ENVIRONMENT_VERSION := $(shell $(CURL) $(CST_REPOSITORY_CFM_URL)/$(ENV_VERSION)/$(CST_REPOSITORY_CFM_VERSION) | head -n 1)
ENVIRONMENT_LEVEL := $(strip $(shell echo $(ENVIRONMENT_VERSION) | cut -d'-' -f1))

OLD_ENVIRONMENT_VERSION = $(eval OLD_ENVIRONMENT_VERSION := \
                            $(strip \
                              $(shell $(CURL) $(CST_REPOSITORY_CFM_OLD_VERSION) | head -n 1 | cut -d'-' -f1)))$(OLD_ENVIRONMENT_VERSION)
ifneq ($(findstring DOCTYPE,$(OLD_ENVIRONMENT_VERSION)),)
OLD_ENVIRONMENT_VERSION =
endif
NEXT_ENVIRONMENT_VERSION = $(eval NEXT_ENVIRONMENT_VERSION := \
                             $(strip \
                               $(shell $(CURL) $(CST_REPOSITORY_CFM_NXT_VERSION) | head -n 1 | cut -d'-' -f1)))$(NEXT_ENVIRONMENT_VERSION)
ifneq ($(findstring DOCTYPE,$(NEXT_ENVIRONMENT_VERSION)),)
NEXT_ENVIRONMENT_VERSION =
endif

CURRENT_VERSION = $(eval CURRENT_VERSION := $(shell $(CURL) $(CST_REPOSITORY_CFM_CUR_VERSION) | head -n 1))$(CURRENT_VERSION)

FRONT_MAINTAINER :=
RESEARCH_MAINTAINER :=

ifneq (,$(findstring ENVIRONMENT_VERSION,$(REPOSITORY_SPACE)))
REPOSITORY_SPACE := $(subst ENVIRONMENT_VERSION,$(ENVIRONMENT_VERSION),$(REPOSITORY_SPACE))
endif


# -----------------------------------------------------------------------------
# strip all variables
# -----------------------------------------------------------------------------

APM_OK_VARS :=
APM_OK_VARS += ADD_TESTS_OPTS

APM_OK_VARS += APM_AUTO_ENVNAME
APM_OK_VARS += APM_BUILD_NUMBER
APM_OK_VARS += APM_CONDA_CHANNELS
APM_OK_VARS += APM_EXTRA_CONDA_CHANNELS
APM_OK_VARS += APM_CONDA_PREFIX
APM_OK_VARS += APM_CONDA_VERSION
APM_OK_VARS += APM_ENV_ACTIVATE
APM_OK_VARS += APM_EXTRA_INDEX_URLS
APM_OK_VARS += APM_PACKAGE
APM_OK_VARS += APM_BUILD_TYPE
APM_OK_VARS += APM_USE_PRE_CHANNEL
APM_OK_VARS += APM_PYTHON_VERSION
APM_OK_VARS += APM_BRANCH_NAME
APM_OK_VARS += APM_CONDA_PLATFORM
APM_OK_VARS += APM_STYLE_CHECK
APM_OK_VARS += BUILD_DIR
APM_OK_VARS += BUILD_REQUIREMENTS
APM_OK_VARS += BUILD_REQUIREMENTS_CONDA
APM_OK_VARS += BUILD_REQUIREMENTS_PIP
APM_OK_VARS += CONDA_PREFIX
APM_OK_VARS += COVERAGE_INCLUDE
APM_OK_VARS += COVERAGE_LIMIT
APM_OK_VARS += COVERAGE_OMIT
APM_OK_VARS += DOCS_DIR
APM_OK_VARS += APM_DOCS_OUTPUT
APM_OK_VARS += DOCS_REQUIREMENTS
APM_OK_VARS += FLAKE8_MODULES
APM_OK_VARS += FLAKE8_OPTIONS
APM_OK_VARS += FORCE_UPLOAD
APM_OK_VARS += ENVIRONMENT_VERSION
APM_OK_VARS += RESEARCH_MAINTAINER
APM_OK_VARS += FRONT_MAINTAINER
APM_OK_VARS += PACKAGE_MODULES
APM_OK_VARS += PACKAGE_NAME
APM_OK_VARS += PACKAGE_EGG
APM_OK_VARS += PACKAGE_TEAM
APM_OK_VARS += PACKAGE_VERSION
APM_OK_VARS += PIP_OPTIONS
APM_OK_VARS += PYLINT_OPTIONS
APM_OK_VARS += PYTEST_OPTIONS
APM_OK_VARS += PYTEST_MONITOR
APM_OK_VARS += REPOSITORY_CURRENT_DOC
APM_OK_VARS += REPOSITORY_PASSWORD
APM_OK_VARS += REPOSITORY_SPACE
APM_OK_VARS += REPOSITORY_URL
APM_OK_VARS += REPOSITORY_USER
APM_OK_VARS += REQUIREMENTS_PIP
APM_OK_VARS += REQUIREMENTS_CONDA
APM_OK_VARS += SCRIPTS_DIR
APM_OK_VARS += SKIP_ENV
APM_OK_VARS += SONAR_ISSUES_OPTIONS
APM_OK_VARS += SONAR_RUNNER
APM_OK_VARS += SONAR_URL
APM_OK_VARS += SOURCES_DIR
APM_OK_VARS += SONAR_EXCLUSIONS
APM_OK_VARS += TESTS_BEFORE_DEPENDENCIES
APM_OK_VARS += TESTS_DIR
APM_OK_VARS += TESTS_FILTER
APM_OK_VARS += TESTS_EXTRA_DEPENDENCIES
APM_OK_VARS += TESTS_MARKERS_FAST
APM_OK_VARS += TESTS_MARKERS_DEFAULT
APM_OK_VARS += TESTS_MARKERS_FULL
APM_OK_VARS += TESTS_TOOL
APM_OK_VARS += VERBOSE

APM_DEPREC_VARS :=
APM_DEPREC_VARS +=  REPOSITORY_CURRENT_DOC
APM_DEPREC_VARS +=  CONDA_ENVIRONMENT
APM_DEPREC_VARS +=  VIRTUAL_ENVIRONMENT
APM_DEPREC_VARS +=  APM_CONDA_PREFIX
APM_DEPREC_VARS +=  MTRC_ENVIRONMENT

# -----------------------------------------------------------------------------
# strip APM_ALL_VARS used after
# -----------------------------------------------------------------------------
TMP_ALL_VARS := $(APM_OK_VARS) $(APM_DEPREC_VARS)
$(foreach v, $(TMP_ALL_VARS), $(eval $(v) := $(strip $($(v)))))

# -----------------------------------------------------------------------------
# default values
# -----------------------------------------------------------------------------
ifeq ($(APM_PYTHON_VERSION),)
ifneq (,$(findstring Python 2,$(shell python --version 2>&1)))
APM_PYTHON_VERSION := 2
else
APM_PYTHON_VERSION := 3
endif
endif

NEW_PYTEST :=
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \< 1901),0)
NEW_PYTEST := yes
endif

BM_BIN_PATH =
ifeq ($(DONT_USE_BUILD_MAINTAINER),)
BM_PATH = $(strip $(DEFAULT_BUILD_MAINTAINER))/$(strip $(BUILD_MAINTAINER))
BM_BIN_PATH = $(BM_PATH)/bin/
BM_SHARE_PATH = $(BM_PATH)/share/
ifeq ($(wildcard $(BM_BIN_PATH)python),)
$(error There is no build-maintainer with version '$(strip $(BUILD_MAINTAINER))' under '$(strip $(DEFAULT_BUILD_MAINTAINER))')
endif # ifeq ($(wildcard $(BM_BIN_PATH)/bin/python),)
endif # ifeq($(DONT_USE_BUILD_MAINTAINER),)


# -----------------------------------------------------------------------------
# ENVIRONMENT: detect if activated already if env is activated
# -----------------------------------------------------------------------------
# variable to be set
ENV_ACTIVATED :=

# need to override parameters below if environment is active
ifeq ($(VIRTUAL_ENV)$(CONDA_DEFAULT_ENV),)
ENV_ACTIVATED := no
else
ENV_ACTIVATED := yes
endif # ENV_ACTIVATED := yes

# -----------------------------------------------------------------------------
#  detect if specific conda maintainer should be used
# -----------------------------------------------------------------------------

ifeq ($(APM_CONDA_VERSION),)
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \< 2201),0)
APM_CONDA_VERSION=conda-4.6.14
else
APM_CONDA_VERSION=current
endif
endif

ifeq ($(wildcard $(DEFAULT_CONDA_MAINTAINER)/$(APM_CONDA_VERSION)),)
$(error No such version of conda can be found.)
endif

# -----------------------------------------------------------------------------
#  adjust VERBOSE
# -----------------------------------------------------------------------------
ifeq ($(VERBOSE),full)
SHELL += -x
VERBOSE := yes
endif

# -----------------------------------------------------------------------------
# detection of front-maintainer or research maintainer
# -----------------------------------------------------------------------------
# variable to set
ENV_SCRIPT_MAINTAINER :=
ENV_EXEC_MAINTAINER :=

ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_RESEARCH))
MAINTAINER_ENVIRONMENT := $(DEFAULT_RESEARCH_MAINTAINER)/$(ENVIRONMENT_VERSION)/$(DEFAULT_CFM_BASHRC)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_FRONT))
MAINTAINER_ENVIRONMENT := $(DEFAULT_FRONT_MAINTAINER)/$(ENVIRONMENT_VERSION)/$(DEFAULT_CFM_BASHRC)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_SCL))
MAINTAINER_ENVIRONMENT := scl_source enable $(shell scl --list | grep python$(APM_PYTHON_VERSION))
else ifeq ($(shell command -v conda),)
ENV_EXEC_MAINTAINER := source /opt/conda-maintainer/$(APM_CONDA_VERSION)/enable
endif

ifneq ($(MAINTAINER_ENVIRONMENT),)
ENV_EXEC_MAINTAINER := source $(MAINTAINER_ENVIRONMENT)
endif


# -----------------------------------------------------------------------------
# find executables
# -----------------------------------------------------------------------------
# variables to set in this block
VIRTUALENV_EXE :=
CONDA_EXE :=
SONAR_RUNNER_EXE :=

ifeq ($(ENV_ACTIVATED),no)
ifneq ($(ENV_EXEC_MAINTAINER),)
VIRTUALENV_EXE := bash -c '$(ENV_EXEC_MAINTAINER) && $$0 "$$@"' virtualenv
CONDA_EXE := bash -c '$(ENV_EXEC_MAINTAINER) && $$0 "$$@"' conda
endif
endif
VIRTUALENV_EXE := $(or $(VIRTUALENV_EXE),$(shell command -v virtualenv))
CONDA_EXE := $(or $(CONDA_EXE),/opt/conda-maintainer/$(APM_CONDA_VERSION)/conda)
SONAR_RUNNER_EXE := $(or $(SONAR_RUNNER), $(BM_SHARE_PATH)/sonar-scanner/bin/sonar-scanner)

# -----------------------------------------------------------------------------
# ENVIRONMENT identification
# -----------------------------------------------------------------------------
# variables to set in this block
ENV_CONDAENV :=
ENV_CONDAPREFIX :=
ENV_VIRTUALENV :=

# working variable
TMP_CONDAENV_PATH :=

# ACTIVATED: find information
# ---------------------------
ifeq ($(ENV_ACTIVATED),yes)
ifneq ($(VIRTUAL_ENV),)
# virtualenv activated already
ENV_CONDAENV :=
ENV_CONDAPREFIX :=
ENV_VIRTUALENV := $(shell $(READLINK) $(VIRTUAL_ENV))
else ifneq ($(CONDA_DEFAULT_ENV),)
ifeq ($(CONDA_DEFAULT_ENV),$(ENV_CONDA_PREFIX))
ENV_CONDAENV :=
ENV_CONDAPREFIX := $(CONDA_DEFAULT_ENV)
ENV_VIRTUALENV :=
else
ENV_CONDAENV := $(CONDA_DEFAULT_ENV)
TMP_CONDAENV_PATH := $(ENV_CONDA_PREFIX)
ENV_CONDAPREFIX :=
ENV_VIRTUALENV :=
endif
endif
endif

# -----------------------------------------------------------------------------
# NOT ACTIVATED
# -----------------------------------------------------------------------------
ifeq ($(ENV_ACTIVATED),no)

# choose environment type
TMP_ENV_TYPE :=
TMP_ENV_SUBFOLDER :=

ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_CONDA))
TMP_ENV_TYPE := $(CST_TYPE_CONDA)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_PREFIX))
TMP_ENV_TYPE := $(CST_TYPE_PREFIX)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_VIRTUALENV))
TMP_ENV_TYPE := $(CST_TYPE_VIRTUALENV)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_RESEARCH))
TMP_ENV_TYPE := $(CST_TYPE_VIRTUALENV)
TMP_ENV_SUBFOLDER := $(CST_TYPE_RESEARCH)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_FRONT))
TMP_ENV_TYPE := $(CST_TYPE_VIRTUALENV)
TMP_ENV_SUBFOLDER := $(CST_TYPE_FRONT)
else ifeq ($(_ENVIRONMENT_TYPE),$(CST_TYPE_SCL))
TMP_ENV_TYPE := $(CST_TYPE_VIRTUALENV)
TMP_ENV_SUBFOLDER :=
else ifneq ($(_ENVIRONMENT_TYPE),)
TMP_ENV_TYPE := $(_ENVIRONMENT_TYPE)
TMP_ENV_SUBFOLDER := $(TMP_ENV_TYPE)
else ifneq ($(wildcard /home/$(USER)),)
TMP_ENV_TYPE := $(CST_TYPE_CONDA)
TMP_ENV_SUBFOLDER := $(TMP_ENV_TYPE)
else
TMP_ENV_TYPE := $(CST_TYPE_DEFAULT)
TMP_ENV_SUBFOLDER := $(TMP_ENV_TYPE)
endif

# environment name
TMP_AUTO_ENVNAME :=

ifneq ($(APM_AUTO_ENVNAME),)
TMP_AUTO_ENVNAME := $(APM_AUTO_ENVNAME)
else
TMP_AUTO_ENVNAME := $(notdir $(shell pwd))
endif

TMP_AUTO_ENVNAME := $(TMP_AUTO_ENVNAME)_$(ENVIRONMENT_VERSION)

ifeq ($(APM_PYTHON_VERSION),2)
TMP_AUTO_ENVNAME := $(TMP_AUTO_ENVNAME)_py2
else
TMP_AUTO_ENVNAME := $(TMP_AUTO_ENVNAME)_py3
endif


# location for environments
TMP_ENV_LOCATION :=
ifeq ($(_ENVIRONMENT_LOCATION),)
ifneq ($(wildcard /tmp),)
TMP_ENV_LOCATION := /tmp/$(USER)/$(DEFAULT_APM_ENVS)/$(TMP_ENV_SUBFOLDER)
endif
ifneq ($(TMPDIR),)
ifneq ($(wildcard $(TMPDIR)),)
TMP_ENV_LOCATION := $(TMPDIR)/$(DEFAULT_APM_ENVS)/$(TMP_ENV_SUBFOLDER)
endif
endif
ifneq ($(wildcard /opt/tmp),)
TMP_ENV_LOCATION := /opt/tmp/$(USER)/$(DEFAULT_APM_ENVS)/$(TMP_ENV_SUBFOLDER)
endif
else
TMP_ENV_LOCATION := $(_ENVIRONMENT_LOCATION)
endif

#name for environment
ifneq ($(_ENVIRONMENT_NAME),)
TMP_ENV_NAME := $(_ENVIRONMENT_NAME)
else
TMP_ENV_NAME := $(TMP_AUTO_ENVNAME)
endif

# definitive environment information
ifeq ($(TMP_ENV_TYPE),$(CST_TYPE_CONDA))
ENV_CONDAENV := $(TMP_ENV_NAME)
else ifeq ($(TMP_ENV_TYPE),$(CST_TYPE_PREFIX))
ENV_CONDAPREFIX := $(TMP_ENV_LOCATION)/$(TMP_ENV_NAME)
else ifeq ($(TMP_ENV_TYPE),$(CST_TYPE_VIRTUALENV))
ENV_VIRTUALENV := $(TMP_ENV_LOCATION)/$(TMP_ENV_NAME)
endif

endif  # env not activated

# Finalize pip options
ifneq ($(APM_EXTRA_INDEX_URLS),)
TMP_APM_EXTRA_INDEX_URL := $(patsubst %, --extra-index-url $(DEFAULT_REPO_URL)/%/python, $(APM_EXTRA_INDEX_URLS))
PIP_OPTIONS_APM += $(TMP_APM_EXTRA_INDEX_URL)
PIP_OPTIONS += $(TMP_APM_EXTRA_INDEX_URL)
endif


# -----------------------------------------------------------------------------
# ENV INFORMATION SHOULD BE OK
# determine environment description (type, path, ..)
# -----------------------------------------------------------------------------
# variables to set in this block
ENV_TYPE :=
ENV_IS_CONDA :=
ENV_NAME :=
ENV_PATH := /dev/null
ENV_CONDARC :=

ifneq ($(ENV_VIRTUALENV),)
ENV_VIRTUALENV := $(shell $(READLINK) $(ENV_VIRTUALENV))
ENV_TYPE := virtualenv
ENV_IS_CONDA := no
ENV_NAME := $(notdir $(ENV_VIRTUALENV))
ENV_PATH := $(ENV_VIRTUALENV)
else ifneq ($(ENV_CONDAENV),)
ENV_TYPE := conda
ENV_IS_CONDA := yes
ENV_NAME := $(ENV_CONDAENV)
ifneq ($(TMP_CONDAENV_PATH),)
ENV_PATH :=$(TMP_CONDAENV_PATH)
else
ENV_PATH := $(shell $(CONDA_EXE) info --json 2>/dev/null | python -c "import sys,json; print(json.load(sys.stdin)['envs_dirs'][0]);" 2>/dev/null)
ifneq ($(and $(ENV_PATH),$(ENV_NAME)),)
ENV_PATH := $(shell $(READLINK) $(ENV_PATH)/$(ENV_NAME))
endif
endif
else ifneq ($(ENV_CONDAPREFIX),)
ENV_CONDAPREFIX := $(shell $(READLINK) $(ENV_CONDAPREFIX))
ENV_TYPE = $(CST_TYPE_PREFIX)
ENV_IS_CONDA := yes
ENV_NAME := $(ENV_CONDAPREFIX)
ENV_PATH := $(ENV_CONDAPREFIX)
endif

# for activation script
ifneq ($(MAINTAINER_ENVIRONMENT),)
ENV_SCRIPT_MAINTAINER := source $(MAINTAINER_ENVIRONMENT)
endif

# -----------------------------------------------------------------------------
# ENV INFORMATIONS SHOULD BE OK
# -----------------------------------------------------------------------------
ifeq ($(ENV_TYPE),)
ENV_TYPE := invalid
ENV_PATH := /dev/null
ENV_ERROR += invalid environment setup.
endif


ENV_ACTIVATE_SCRIPT := /dev/null
ifeq ($(ENV_TYPE),$(CST_TYPE_VIRTUALENV))
ifneq ($(ENV_PATH),)
TMP_VIRTUALENV_OPTIONS := -q --system-site-packages --no-download
ENV_ACTIVATE_SCRIPT := ./activate_virtualenv
endif
else ifeq ($(ENV_TYPE),$(CST_TYPE_CONDA))
ifneq ($(ENV_NAME),)
ENV_ACTIVATE_SCRIPT := ./activate_conda
endif
else ifeq ($(ENV_TYPE),$(CST_TYPE_PREFIX))
ifneq ($(ENV_PATH),)
ENV_ACTIVATE_SCRIPT := ./activate_prefix
endif
endif

ENV_ACTIVATE_SCRIPT_MESSAGE :=

ifneq ($(APM_ENV_ACTIVATE),)
ENV_ACTIVATE_SCRIPT := $(APM_ENV_ACTIVATE)
else
ifeq ($(APM_PYTHON_VERSION),2)
ENV_ACTIVATE_SCRIPT := $(ENV_ACTIVATE_SCRIPT)_$(ENVIRONMENT_VERSION)_py2
else
ENV_ACTIVATE_SCRIPT := $(ENV_ACTIVATE_SCRIPT)_$(ENVIRONMENT_VERSION)_py3
endif #ifeq ($(APM_PYTHON_VERSION),3)
endif #ifneq($(APM_ENV_ACTIVATE),)

# -----------------------------------------------------------------------------
# program command aliases (installed in environment or in build-maintainer)
# -----------------------------------------------------------------------------
APM_CARTOGRAPHY = $(BM_BIN_PATH)cfm-apm-cartography
BLACK = $(BM_BIN_PATH)black
CFM_APM = $(BM_BIN_PATH)cfm-apm
CFM_LINT = $(BM_BIN_PATH)cfm-lint
CONDA := conda
CONDA_SKELETON := $(BM_BIN_PATH)cfm-conda-skeleton
COVERAGE = coverage
FLAKE8 = ${BM_BIN_PATH}flake8
MTRCINFO = ${BM_BIN_PATH}mtrcinfo
MAKE = make -s
MAKE_IN_ENV := $(MAKE)
MKDIR = mkdir -p
MYPY = $(BM_BIN_PATH)mypy
PIP = python -m pip
PIP_EXE := $(PIP)
PYLINT = ${BM_BIN_PATH}pylint
PYTEST ?= pytest
PYPROF2CALLTREE = ${BM_BIN_PATH}pyprof2calltree
PYTHON = python
PY_LINT = ${BM_BIN_PATH}pylint
TRIAL = trial
SUBUNIT_1TO2 := subunit-1to2
SUBUNIT2JUNITXML := subunit2junitxml


BM_PYTHON=$(BM_BIN_PATH)python

ifeq ($(ENV_TYPE),virtualenv)
PYTEST := python -m $(PYTEST)
endif

SET_VERSION_EXT :=
PACKAGE_VERSION_EXT :=
ifneq ($(APM_BUILD_TYPE),)
BUILD_ID = $(shell p4 changes -m1 ... 2>/dev/null | cut -f2 -d' ')
PACKAGE_VERSION_EXT := .$(APM_BUILD_TYPE)$(BUILD_ID)
SET_VERSION_EXT := PACKAGE_VERSION_EXT=$(PACKAGE_VERSION_EXT)
endif

ifneq ($(APM_BUILD_TYPE),)
BUILD_ID = $(shell p4 changes -m1 ... 2>/dev/null | cut -f2 -d' ')
PACKAGE_VERSION_EXT := .$(APM_BUILD_TYPE)$(BUILD_ID)
SET_VERSION_EXT := PACKAGE_VERSION_EXT=$(PACKAGE_VERSION_EXT)
endif

# -----------------------------------------------------------------------------
# mtrcinfo
# -----------------------------------------------------------------------------
ENV_DEVTOOLSET := $(shell $(MTRCINFO) show $(ENVIRONMENT_LEVEL) | $(JQ) .devtoolset)

ifeq ($(APM_PYTHON_VERSION),3)
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \< 2201),0)
    _PYTHON_FULL_VERSION = $(shell $(MTRCINFO) show $(ENVIRONMENT_LEVEL) | $(JQ) .default_python_version)
    CONDA_PYTHON_VERSION := $(shell python -c "print('.'.join('$(_PYTHON_FULL_VERSION)'.split('.')[:2]))")
else
    CONDA_PYTHON_VERSION := 3.6
endif
else
CONDA_PYTHON_VERSION := $(APM_PYTHON_VERSION)
endif


# -----------------------------------------------------------------------------
# apply environment sourcing if needed
# -----------------------------------------------------------------------------
ENV_EXEC :=
ifeq ($(ENV_ACTIVATED),no)
ENV_EXEC := bash -c 'source $(shell $(READLINK) $(ENV_ACTIVATE_SCRIPT)) && $(SET_VERSION_EXT) $$0 "$$@"'

APM_CARTOGRAPHY := $(ENV_EXEC) $(APM_CARTOGRAPHY)
CFM_APM := $(ENV_EXEC) $(CFM_APM)
CFM_LINT := $(ENV_EXEC) $(CFM_LINT)
CONDA := $(ENV_EXEC) $(CONDA)
CONDA_SKELETON := $(ENV_EXEC) $(CONDA_SKELETON)
COVERAGE := $(ENV_EXEC) $(COVERAGE)
ifneq ($(DONT_USE_BUILD_MAINTAINER),)
FLAKE8 := $(ENV_EXEC) $(FLAKE8)
endif
MAKE_IN_ENV := $(ENV_EXEC) $(MAKE_IN_ENV)
PIP := $(ENV_EXEC) $(PIP)
PYLINT := $(ENV_EXEC) $(PYLINT)
PYTEST := $(ENV_EXEC) $(PYTEST)
PYTHON := $(ENV_EXEC) $(PYTHON)
PY_LINT := $(ENV_EXEC) $(PY_LINT)
TRIAL := $(ENV_EXEC) $(TRIAL)
SUBUNIT_1TO2 := $(ENV_EXEC) $(SUBUNIT_1TO2)
SUBUNIT2JUNITXML := $(ENV_EXEC) $(SUBUNIT2JUNITXML)
else
ENV_EXEC := $(SET_VERSION_EXT)
endif


# -----------------------------------------------------------------------------
# include apm.mk if available in environment (used for multi env)
# -----------------------------------------------------------------------------
# variables to set in this block
ENV_APM_MK :=
ifneq ($(ENV_INSIDE_CI_BUILD),yes)
ENV_APM_MK := $(ENV_PATH)/apm.mk
ifeq ($(ENV_ACTIVATED),yes)
ifneq ($(wildcard $(ENV_APM_MK)),)
include $(ENV_APM_MK)
endif
endif
endif


# -----------------------------------------------------------------------------
# conda environments: channels information and condarc
# -----------------------------------------------------------------------------
ENV_CFM_CHANNEL :=
ifeq ($(ENV_IS_CONDA),yes)
ifneq ($(ENV_PATH),)
ENV_CONDARC := $(ENV_PATH)/condarc
endif
ENV_CFM_CHANNEL := $(DEFAULT_CHANNEL_ALIAS)/cfm_$(ENVIRONMENT_VERSION)
endif

# -----------------------------------------------------------------------------
# ipykernel: use folder as id
# -----------------------------------------------------------------------------
ENV_PYKERNEL_ID :=
ifneq ($(ENV_PATH),)
ENV_PYKERNEL_ID := $(notdir $(ENV_PATH))
endif

# -----------------------------------------------------------------------------
# ACTIVATION commands
# -----------------------------------------------------------------------------
# variables to set in this block
ENV_ACTIVATE_CMD :=

ifeq ($(ENV_TYPE),$(CST_TYPE_CONDA))
ENV_ACTIVATE_CMD := conda activate $(ENV_NAME)
else ifeq ($(ENV_TYPE),$(CST_TYPE_PREFIX))
ENV_ACTIVATE_CMD := conda activate $(ENV_NAME)
else ifeq ($(ENV_TYPE),$(CST_TYPE_VIRTUALENV))
ENV_ACTIVATE_CMD := source $(ENV_PATH)/bin/activate
endif

# -----------------------------------------------------------------------------
# ENV_AVAILABLE: type is valid
# ENV_CREATED: full environment is created
# -----------------------------------------------------------------------------
ifeq ($(ENV_TYPE),invalid)
ENV_AVAILABLE = env-invalid
else ifeq ($(ENV_TYPE),unknown)
ENV_AVAILABLE = env-not-defined
else
ENV_AVAILABLE =
endif

ENV_CREATION := $(ENV_AVAILABLE) env
ifeq ($(SKIP_ENV),yes)
ENV_CREATION := $(ENV_AVAILABLE)
endif

ifeq ($(TESTS_BEFORE_DEPENDENCIES),)
TESTS_BEFORE_DEPENDENCIES := $(ENV_CREATION)
endif

# -----------------------------------------------------------------------------
# package name, version and team
# -----------------------------------------------------------------------------


ifneq ($(wildcard setup.py),)
ifeq ($(PACKAGE_NAME),)
PACKAGE_NAME := $(strip $(shell $(BM_PYTHON) setup.py --name 2>/dev/null))
endif
ifeq ($(PACKAGE_NAME),)
PACKAGE_NAME := $(strip $(shell grep '^[ ]*name=' setup.py | awk -F "\"|'" '{ print $$2 }'))
endif
ifeq ($(PACKAGE_EGG),)
PACKAGE_EGG := $(strip $(shell echo ${PACKAGE_NAME} | tr - _ )).egg-info
endif
ifeq ($(PACKAGE_TEAM),)
PACKAGE_TEAM := $(strip $(shell $(BM_PYTHON) setup.py --author 2>/dev/null))
endif
ifeq ($(PACKAGE_TEAM),)
PACKAGE_TEAM := $(strip $(shell grep '^[ ]*author=' setup.py | awk -F "\"|'" '{ print $$2 }'))
endif
endif

ifeq ($(SOURCES_DIR),)
SOURCES_DIR := $(shell echo $(PACKAGE_NAME) | sed "s/-/_/g")
endif

ifeq ($(PACKAGE_VERSION),)
PACKAGE_VERSION := $(strip $(shell $(PYTHON) setup.py --version 2>/dev/null))
endif

ifeq ($(PACKAGE_VERSION),)
ifneq ($(wildcard $(SOURCES_DIR)/__init__.py),)
PACKAGE_VERSION := $(strip $(shell grep "^__version__ = " $(strip $(SOURCES_DIR))/__init__.py | awk -F "\"|'" '{ print $$2 }'))
ifneq ($(PACKAGE_VERSION_EXT),)
PACKAGE_VERSION := $(PACKAGE_VERSION)$(PACKAGE_VERSION_EXT)
endif
endif
endif

ifneq ($(APM_MULTI_ENV),)
ifeq ($(PACKAGE_VERSION),)
PACKAGE_VERSION := 0.0.0
endif
endif

ifeq ($(REPOSITORY_USER),)
REPOSITORY_USER := $(PACKAGE_TEAM)
endif
ifeq ($(REPOSITORY_SPACE),)
REPOSITORY_SPACE := $(PACKAGE_TEAM)
endif

ifeq ($(PACKAGE_MODULES),)
PACKAGE_MODULES := $(SOURCES_DIR)
endif


PACKAGE_NAME_VALID := $(shell echo $(PACKAGE_NAME) | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
ifeq ($(DONT_USE_BUILD_MAINTAINER),)
ENV_APM := $(BM_BIN_PATH)apm
else
ENV_APM := $(ENV_PATH)/bin/apm
endif

# -----------------------------------------------------------------------------
# artefacts
# -----------------------------------------------------------------------------

ifneq ($(ENV_PATH),)
ENV_APM_DIRECTORY := $(ENV_PATH)/apm.artefacts
ENV_TMP_DIRECTORY := $(ENV_PATH)/apm.tmp
else
ENV_APM_DIRECTORY := /dev/null
ENV_TMP_DIRECTORY := /dev/null
endif

ENV_PATH_CREATED := $(ENV_APM_DIRECTORY)/env_path_created.artefact
ENV_APM_DIRS_CREATED := $(ENV_APM_DIRECTORY)/env_apm_dirs_created.artefact
ENV_APM_ARTEFACT := $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_apm_installed.artefact
ENV_PACKAGE_INSTALL_ARTEFACT := $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_package_installed.artefact
ENV_REQUIREMENTS_PIP_ARTEFACT := $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_requirements_txt_installed.artefact
ENV_REQUIREMENTS_CONDA_ARTEFACT := $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_conda_requirements_txt_installed.artefact
ENV_BUILD_REQUIREMENTS_ARTEFACT = $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_build_requirements_txt_installed.artefact
ENV_DOCS_REQUIREMENTS_ARTEFACT := $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_docs_requirements_txt_installed.artefact
ENV_BLD_DIRECTORY_ARTEFACT := $(ENV_APM_DIRECTORY)/$(THIS_PROJECT)_bld_directory.artefact

ifneq ($(BUILD_DIR),)
ENV_BLD_DIRECTORY := $(shell $(READLINK) $(BUILD_DIR))
else ifneq ($(ENV_PATH),)
ENV_BLD_DIRECTORY := $(ENV_PATH)/apm.build
else
ENV_BLD_DIRECTORY := $(shell $(READLINK) ./build)
endif


CALLGRINDNAME ?= prof/callgrind.$(PACKAGE_NAME)-$(shell date +"%d.%m.%y-%H.%M.%S")
# -----------------------------------------------------------------------------
# requirements.txt
# conda-requirements.txt
# local-requirements.txt
# -----------------------------------------------------------------------------

ENV_PACKAGE_DEPENDENCIES := $(wildcard setup.py)
PIP_PACKAGE_INSTALL_OPTIONS :=

ENV_REQUIREMENTS_CONDA := $(REQUIREMENTS_CONDA)
ENV_REQUIREMENTS_PIP := $(REQUIREMENTS_PIP)
ENV_DEPLOY_REQUIREMENTS_CONDA := $(DEFAULT_DEPLOY_REQUIREMENTS)

ifeq ($(ENV_REQUIREMENTS_CONDA),)
ENV_REQUIREMENTS_CONDA := $(ENV_REQUIREMENTS_PIP)
endif

# -----------------------------------------------------------------------------
# build-requirements
# docs-requirements
# -----------------------------------------------------------------------------
ENV_TMP_BUILD_REQUIREMENTS_PIP := $(ENV_TMP_DIRECTORY)/build-requirements.pip
ENV_TMP_BUILD_REQUIREMENTS_CONDA := $(ENV_TMP_DIRECTORY)/build-requirements.conda

ENV_TMP_DOCS_REQUIREMENTS_PIP := $(ENV_TMP_DIRECTORY)/docs-requirements.pip
ENV_TMP_DOCS_REQUIREMENTS_CONDA := $(ENV_TMP_DIRECTORY)/docs-requirements.conda

ifeq ($(BUILD_REQUIREMENTS_PIP),)
BUILD_REQUIREMENTS_PIP := $(BUILD_REQUIREMENTS)
endif

ifeq ($(BUILD_REQUIREMENTS_CONDA),)
BUILD_REQUIREMENTS_CONDA := $(BUILD_REQUIREMENTS)
endif

# -----------------------------------------------------------------------------
# cleanup requirements
# -----------------------------------------------------------------------------

ifeq ($(ENV_IS_CONDA),yes)
# conda env
ENV_REQUIREMENTS_PIP :=
ENV_TMP_BUILD_REQUIREMENTS_PIP :=
ENV_TMP_DOCS_REQUIREMENTS_PIP :=
APM_INSTALL_OPTIONS := $(APM_INSTALL_OPTIONS) --no-pip
else
# virtualenv
ENV_REQUIREMENTS_CONDA :=
ENV_TMP_BUILD_REQUIREMENTS_CONDA :=
ENV_TMP_DOCS_REQUIREMENTS_CONDA :=
APM_INSTALL_OPTIONS := $(APM_INSTALL_OPTIONS) --no-conda
endif


CONDA_SKELETON_OPTIONS :=
ifeq ($(ENV_IS_CONDA),yes)
ifeq ($(APM_CONDA_PLATFORM),noarch)
CONDA_SKELETON_OPTIONS := --noarch
endif
ifneq ($(ENV_REQUIREMENTS_CONDA),)
PIP_PACKAGE_INSTALL_OPTIONS = --no-deps
CONDA_SKELETON_OPTIONS := $(CONDA_SKELETON_OPTIONS) -c $(ENV_REQUIREMENTS_CONDA) $(CONDA_SKELETON_EXTRA_OPTIONS)
ENV_PACKAGE_DEPENDENCIES := $(ENV_PACKAGE_DEPENDENCIES) $(ENV_REQUIREMENTS_CONDA_ARTEFACT)
endif
endif

ifneq ($(ENV_REQUIREMENTS_PIP),)
PIP_PACKAGE_INSTALL_OPTIONS := --no-deps
ENV_PACKAGE_DEPENDENCIES := $(ENV_PACKAGE_DEPENDENCIES) $(ENV_REQUIREMENTS_PIP_ARTEFACT)
endif

ifneq ($(APM_MULTI_ENV),)
ENV_PACKAGE_DEPENDENCIES :=
ENV_REQUIREMENTS_PIP_ARTEFACT :=
ENV_REQUIREMENTS_CONDA_ARTEFACT :=
ENV_PROJECTS_DIRS := $(APM_MULTI_ENV)
ENV_TESTS_DIRS := $(ENV_PROJECTS_DIRS)
SKIP_ENV := yes
else
ENV_PROJECTS_DIRS :=
ENV_TESTS_DIRS :=
endif

# -----------------------------------------------------------------------------
#
# testing and coverage
# -----------------------------------------------------------------------------

TESTS_MODULES := $(foreach f,$(TESTS_DIR),$(wildcard $(f)))
TESTS_MODULES := $(strip $(TESTS_MODULES))
TESTS_PYLINT_MODULES := $(strip $(PACKAGE_MODULES))
TESTS_TOOL_NAME := $(strip $(TESTS_TOOL))
TESTS_DEPENDENCIES := $(strip $(TESTS_EXTRA_DEPENDENCIES))
TESTS_PYLINT_OPTIONS := $(strip $(PYLINT_OPTIONS))

ifneq ($(APM_MULTI_ENV),)
TEST_PYTEST_ID_NAMES =
TEST_PYTEST_ID_MODULES = $(strip $(foreach t,$(TESTS_FILTER),$(word 1,$(subst :, ,$(t)))))
ifneq ($(TEST_PYTEST_ID_MODULES),)
ENV_TESTS_DIRS := $(TEST_PYTEST_ID_MODULES)
endif
else
TEST_PYTEST_ID_NAMES = $(TESTS_FILTER)
TEST_PYTEST_ID_MODULES =
endif

ifeq ($(ENV_INSIDE_CI_BUILD),yes)
PYTEST_OPTIONS := $(filter-out -s, $(strip $(PYTEST_OPTIONS)))
endif

TESTS_PYTEST_OPTIONS := $(strip $(PYTEST_PLUGINS)) $(strip $(PYTEST_OPTIONS)) $(strip $(ADD_TESTS_OPTS))

ifneq ($(NEW_PYTEST),yes)
TESTS_PYTEST_OPTIONS := $(TESTS_PYTEST_OPTIONS) --cache-clear
endif

ifneq (${PYTEST_MARKERS},)
TESTS_PYTEST_MARKERS := $(PYTEST_MARKERS)
endif # ... or else the value will be set below, depending on the target
# Ensure ignore black as a default. We enable it on purpose.
BLACK_CONFIG_FILE := $(ENV_BLD_DIRECTORY)/black.toml
TESTS_FLAKE8_OPTIONS := $(strip $(FLAKE8_OPTIONS))
TESTS_COVERAGE_RC := $(ENV_BLD_DIRECTORY)/.coveragerc
TESTS_COV_MODULES := $(shell echo "$(strip $(PACKAGE_MODULES))" | sed 's/\(^\| \)/ --cov=/g')
TESTS_JUNITS_XML := $(ENV_BLD_DIRECTORY)/junit.xml
TESTS_COVERAGE_XML := $(ENV_BLD_DIRECTORY)/coverage.xml
TESTS_COVERAGE_LOCATION := $(ENV_BLD_DIRECTORY)/coverage

TESTS_COVERAGE_INCLUDE := $(COVERAGE_INCLUDE)
ifeq ($(TESTS_TOOL_NAME),trial)
TESTS_COVERAGE_INCLUDE :=  $(SOURCES_DIR)/* $(TESTS_COVERAGE_INCLUDE)
endif
TESTS_COVERAGE_INCLUDE := $(strip $(TESTS_COVERAGE_INCLUDE))
TESTS_COVERAGE_INCLUDE := $(subst $(CST_SPACE),$(CST_COMMA),$(TESTS_COVERAGE_INCLUDE))

TESTS_COVERAGE_OMIT := $(COVERAGE_OMIT)
ifeq ($(TESTS_TOOL_NAME),trial)
TESTS_COVERAGE_OMIT :=  $(TESTS_DIR)/* $(TESTS_COVERAGE_OMIT)
TESTS_COVERAGE_OMIT :=  $(TESTS_DIR)/* $(TESTS_COVERAGE_OMIT)
endif
TESTS_COVERAGE_OMIT := $(strip $(TESTS_COVERAGE_OMIT))
TESTS_COVERAGE_OMIT := $(subst $(CST_SPACE),$(CST_COMMA),$(TESTS_COVERAGE_OMIT))

ifeq ($(MYPY_PACKAGES),)
MYPY_PACKAGES := $(foreach d,$(SOURCES_DIR), --package $(d))
else
MYPY_PACKAGES := $(foreach d,$(MYPY_PACKAGES), --package $(d))
endif
PEP8_MODULES := $(strip $(FLAKE8_MODULES))
ifeq ($(PEP8_MODULES),)
PEP8_MODULES := setup.py $(PACKAGE_MODULES) $(TESTS_MODULES)
endif



# -----------------------------------------------------------------------------
# sphinx documentation
# -----------------------------------------------------------------------------
DOCS_LOCATION := $(wildcard $(DOCS_DIR))
DOCS_SOURCES := $(or $(wildcard $(DOCS_LOCATION)/source),$(wildcard $(DOCS_LOCATION)))

BLD_DOCS_DIRECTORY := $(APM_DOCS_OUTPUT)/$(PACKAGE_NAME)
ifeq ($(APM_DOCS_OUTPUT),)
BLD_DOCS_DIRECTORY := $(ENV_BLD_DIRECTORY)/docs
endif

ENV_SPHINX_BUILDDIR := $(ENV_TMP_DIRECTORY)/$(THIS_PROJECT)/_build

# -----------------------------------------------------------------------------
#  packaging with setuptools or conda
# -----------------------------------------------------------------------------

APM_PARAMS :=
ifeq ($(VERBOSE),yes)
APM_PARAMS += -v
endif

APM_PARAMS += -x
APM_PARAMS += apm.makefile.version=$(APM_MAKEFILE_VERSION)
APM_PARAMS += env.type=$(ENV_TYPE)
APM_PARAMS += env.name=$(ENV_NAME)
APM_PARAMS += env.path=$(ENV_PATH)
APM_PARAMS += project.name=$(PACKAGE_NAME)
APM_PARAMS += project.team=$(PACKAGE_TEAM)
APM_PARAMS += project.version=$(PACKAGE_VERSION)

# -----------------------------------------------------------------------------
# repository setup
# -----------------------------------------------------------------------------
REPOSITORY_SPACE_URL := $(REPOSITORY_URL)/$(REPOSITORY_SPACE)
ifneq ($(APM_BUILD_TYPE),)
ifeq ($(APM_USE_PRE_CHANNEL),yes)
REPOSITORY_SPACE_URL := $(REPOSITORY_SPACE_URL)/$(APM_BUILD_TYPE)
endif
endif
REPOSITORY_SDIST_URL := $(REPOSITORY_SPACE_URL)/python/$(strip $(PACKAGE_NAME))
REPOSITORY_CONDA_URL := $(REPOSITORY_SPACE_URL)/conda/$(APM_CONDA_PLATFORM)
REPOSITORY_CONDA_DEPLOY_URL := $(REPOSITORY_SPACE_URL)/deployment
REPOSITORY_DOCS_URL := $(REPOSITORY_SPACE_URL)/docs
REPOSITORY_DOCS_VERSION := $(strip $(PACKAGE_VERSION))
REPOSITORY_DOCS_LATEST := $(strip $(REPOSITORY_CURRENT_DOC))
REPOSITORY_DOCS_VERSION_URL := $(REPOSITORY_DOCS_URL)/$(strip $(PACKAGE_NAME))/$(REPOSITORY_DOCS_VERSION)

REPOSITORY_CREDENTIALS ?= -u $(strip $(REPOSITORY_USER)):'$(strip $(REPOSITORY_PASSWORD))'
REPOSITORY_MAKEFILE_URL := $(strip $(REPOSITORY_URL))/it-core/tools/python/Makefile
REPOSITORY_FORCE_UPLOAD := $(strip $(FORCE_UPLOAD))

ifeq ($(REPOSITORY_USER),)
REPOSITORY_CREDENTIALS :=
endif


# -----------------------------------------------------------------------------
#  packaging with setuptools or conda
# -----------------------------------------------------------------------------

PKG_CONDA_SPEC := $(PACKAGE_NAME)=^$(PACKAGE_VERSION)$$
ifeq ($(APM_CONDA_PLATFORM),noarch)
PKG_CONDA_SPEC := $(PKG_CONDA_SPEC)=*
else ifeq ($(APM_PYTHON_VERSION),3)
PKG_CONDA_SPEC := $(PKG_CONDA_SPEC)=py3*
else
PKG_CONDA_SPEC := $(PKG_CONDA_SPEC)=py2*
endif


PKG_SDIST_LOCATION := $(ENV_BLD_DIRECTORY)/dist
PKG_SDIST_FILE := $(strip $(PACKAGE_NAME))-$(strip $(PACKAGE_VERSION)).tar.gz
PKG_SDIST_FILE_LOCATION := $(PKG_SDIST_LOCATION)/$(PKG_SDIST_FILE)
PKG_SDIST_FILE_URL := $(REPOSITORY_SDIST_URL)/$(PKG_SDIST_FILE)
DIST_CONFIG_MK := $(ENV_BLD_DIRECTORY)/config.mk
DIST_PROPERTIES := $(ENV_BLD_DIRECTORY)/dist.properties

PKG_SDIST_APM_PARAMS := $(APM_PARAMS)
ifneq ($(REPOSITORY_SDIST_URL),)
PKG_SDIST_APM_PARAMS += repo.sdist.url=$(REPOSITORY_SDIST_URL)
PKG_SDIST_APM_PARAMS += repo.sdist.file=$(notdir $(PKG_SDIST_FILE_LOCATION))
PKG_SDIST_APM_PARAMS += repo.sdist.md5=$(notdir $(PKG_SDIST_FILE_LOCATION) 2>/dev/null | cut -d' ' -f 1)
endif

PKG_CONDA_SOURCES := $(PKG_SDIST_FILE_LOCATION)
PKG_CONDA_RECIPE_LOCATION := $(ENV_BLD_DIRECTORY)/conda-recipe

PKG_CONDA_LOCATION := $(ENV_BLD_DIRECTORY)/conda
PKG_CONDA_FILE_PATTERN := $(subst _,?,$(PACKAGE_NAME))-$(PACKAGE_VERSION)-*.tar.bz2
PKG_CONDA_FILE_PATTERN := $(PKG_CONDA_LOCATION)/$(APM_CONDA_PLATFORM)/$(PKG_CONDA_FILE_PATTERN)
PKG_CONDA_FILE_PATH = $(wildcard $(PKG_CONDA_FILE_PATTERN))
PKG_CONDA_PACKAGES =
ifneq ($(wildcard $(PKG_CONDA_LOCATION)),)
PKG_CONDA_PACKAGES = $(shell find $(PKG_CONDA_LOCATION) -name *.tar.bz2)
endif

PKG_CONDA_DEPLOY_ENV := $(ENV_PATH)/_conda_deploy

ifneq ($(APM_MULTI_ENV),)
PKG_CONDA_MANIFEST := $(or $(strip $(PACKAGE_NAME)),manifest)-$(or $(strip $(PACKAGE_VERSION)),latest)-py$(APM_PYTHON_VERSION)_$(strip $(APM_BUILD_NUMBER)).deploy.txt
else ifneq ($(PKG_CONDA_FILE_PATH),)
PKG_CONDA_MANIFEST := $(subst .tar.bz2,.deploy.txt,$(PKG_CONDA_FILE_PATH))
PKG_CONDA_FILE_URL := $(REPOSITORY_CONDA_URL)/$(notdir $(PKG_CONDA_FILE_PATH))
else
PKG_CONDA_MANIFEST :=
PKG_CONDA_FILE_URL :=
endif

APM_CONDA_MANIFEST_DETACHED ?=
ifeq ($(APM_CONDA_MANIFEST_DETACHED),yes)
PKG_CONDA_MANIFEST := $(dir $(PKG_CONDA_MANIFEST))/$(PACKAGE_NAME)-$(PACKAGE_VERSION)-py$(APM_PYTHON_VERSION).deploy.txt
PKG_CONDA_FILE_URL := $(REPOSITORY_CONDA_URL)/$(notdir $(PKG_CONDA_FILE_PATH))
endif

ifneq ($(PKG_CONDA_FILE_PATH),)
PKG_CONDA_APM_PARAMS := $(APM_PARAMS)
PKG_CONDA_APM_PARAMS += repo.conda.url=$(REPOSITORY_CONDA_URL)
PKG_CONDA_APM_PARAMS += repo.conda.file=$(notdir $(PKG_CONDA_FILE_PATH))
PKG_CONDA_APM_PARAMS += repo.conda.md5=$(shell md5sum $(PKG_CONDA_FILE_PATH) 2>/dev/null | cut -d' ' -f 1)
endif


# -----------------------------------------------------------------------------
# sonar preview and upload
# -----------------------------------------------------------------------------
SONAR_KEY = $(PACKAGE_TEAM).$(PACKAGE_NAME_VALID)
SONAR_SOURCES := $(shell for DIRECTORY in $(strip $(PACKAGE_MODULES)); \
                              do \
                                  if [ -d $$DIRECTORY ] ; then \
                                  echo $$DIRECTORY; \
                              fi; \
                          done | sed "s/ /,/g")
SONAR_TESTS ?= $(shell echo $(TESTS_MODULES) | sed "s/ /,/g")

# shared arguments
SONAR_ARGUMENTS += -Dsonar.projectKey=$(SONAR_KEY)
SONAR_ARGUMENTS += -Dsonar.projectName=$(SONAR_KEY)
SONAR_ARGUMENTS += -Dsonar.projectVersion=$(PACKAGE_VERSION)
SONAR_ARGUMENTS += -Dsonar.sourceEncoding=UTF-8
SONAR_ARGUMENTS += -Dsonar.language=py
ifneq ($(CONDA_PYTHON_VERSION),)
SONAR_ARGUMENTS += -Dsonar.python.version=$(CONDA_PYTHON_VERSION)
endif
SONAR_ARGUMENTS += -Dsonar.working.directory=$(ENV_BLD_DIRECTORY)/.sonar
SONAR_ARGUMENTS += -Dsonar.report.export.path=../sonar.json
ifneq ($(SONAR_URL),)
SONAR_ARGUMENTS += -Dsonar.host.url=$(SONAR_URL)
endif
SONAR_ARGUMENTS += -Dsonar.sources=$(SONAR_SOURCES)



ifneq ($(SONAR_TOKEN),)
SONAR_ARGUMENTS += -Dsonar.login=$(SONAR_TOKEN)
endif

SONAR_PREVIEW_ARGUMENTS :=  $(SONAR_ARGUMENTS) -Dsonar.analysis.mode=preview
SONAR_PREVIEW_ARGUMENTS += -Dsonar.issuesReport.html.location=../sonar
SONAR_PREVIEW_ARGUMENTS += -Dsonar.issuesReport.html.enable=true

SONAR_ISSUES_ARGUMENTS := $(SONAR_ARGUMENTS) -Dsonar.analysis.mode=issues

SONAR_PUBLISH_ARGUMENTS := $(SONAR_ARGUMENTS) -Dsonar.analysis.mode=publish
ifneq ($(wildcard $(TESTS_COVERAGE_XML)),)
SONAR_PUBLISH_ARGUMENTS += -Dsonar.python.coverage.reportPaths=$(TESTS_COVERAGE_XML)
endif
ifneq ($(wildcard $(TESTS_JUNITS_XML)),)
SONAR_PUBLISH_ARGUMENTS += -Dsonar.python.xunit.reportPath=$(TESTS_JUNITS_XML)
endif

ifneq ($(SONAR_EXCLUSIONS),)
SONAR_PUBLISH_ARGUMENTS += -Dsonar.exclusions=$(SONAR_EXCLUSIONS)
endif

ifneq ($(TESTS_MODULES),)
SONAR_PUBLISH_ARGUMENTS += -Dsonar.tests=$(SONAR_TESTS)
endif

ifneq ($(APM_BRANCH_NAME),)
SONAR_PUBLISH_ARGUMENTS += -Dsonar.branch.name=$(APM_BRANCH_NAME)
endif

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------

APM_MAKEFILE_VERSION_LAST := $(shell $(CURL) $(DEFAULT_MAKEFILE_VERSION_URL) || true)
APM_VERSION := $(shell $(ENV_APM) --version 2>&1 | egrep "^apm .*" | cut -d ' ' -f 2  || true)

ifneq ($(strip $(APM_VERSION)),)
APM_VERSION_HEADER := $(APM_VERSION) / $(APM_MAKEFILE_VERSION)
else
APM_VERSION_HEADER := $(APM_MAKEFILE_VERSION)
endif

MAKEFILE_HEADER := echo -e "---------------------------------------------------------------------------";
MAKEFILE_HEADER += echo -e "\033[1mAPM /  Makefile \033[0m ($(APM_VERSION_HEADER))\033[0m - [$(MAKECMDGOALS)]";
ifneq ($(APM_MAKEFILE_VERSION_LAST),)
ifneq ($(APM_MAKEFILE_VERSION), $(APM_MAKEFILE_VERSION_LAST))
MAKEFILE_HEADER += echo -e "\033[0;31mMakefile released $(APM_MAKEFILE_VERSION_LAST)\033[0m (please make upgrade-me)";
endif
endif
MAKEFILE_HEADER += echo -e "---------------------------------------------------------------------------";
MAKEFILE_HEADER += echo -e "\033[1mUsing conda version $(APM_CONDA_VERSION)\033[0m"

ifneq ($(MAKELEVEL),0)
MAKEFILE_HEADER :=
endif

ifneq ($(ENV_ACTIVATE_SCRIPT),)
ifneq ($(ENV_ACTIVATED),yes)
ENV_ACTIVATE_SCRIPT_MESSAGE := $(call print_success,"source $(ENV_ACTIVATE_SCRIPT)")
endif
endif


CONDA_RAW := $(CONDA)

# -----------------------------------------------------------------------------
# mask commands
# -----------------------------------------------------------------------------
CONDA_OPTIONS :=
DEV_NULL :=
FULL_DEV_NULL :=

EXEC_CURL := $(CURL)


ifneq ($(VERBOSE),yes)

CD := @$(CD)
CHMOD := @$(CHMOD)
EXEC_CURL := @$(EXEC_CURL)
CP := @$(CP)
LN := @$(LN)
MKDIR := @$(MKDIR)
MV := @$(MV)
FIND := @$(FIND)
RM := @$(RM)
TOUCH := @$(TOUCH)
WGET := @$(WGET)
COVERAGE := @$(COVERAGE)
DEV_NULL := 1>/dev/null
FULL_DEV_NULL := &>/dev/null

APM_CARTOGRAPHY := @$(APM_CARTOGRAPHY)
CFM_LINT := @$(CFM_LINT)
CONDA := @$(CONDA)
CONDA_EXE := @$(CONDA_EXE)
CONDA_SKELETON := @$(CONDA_SKELETON)
CONDA_OPTIONS := $(CONDA_OPTIONS) -q

FLAKE8 := @$(FLAKE8)
MYPY := @$(MYPY)
BLACK := @$(BLACK)
PIP := @$(PIP)
PIP_OPTIONS := -q $(PIP_OPTIONS)
PYLINT := @$(PYLINT)
PYTEST := @$(PYTEST)
PYPROF2CALLTREE := @$(PYPROF2CALLTREE)
PYTHON := @$(PYTHON)
PY_LINT := @$(PY_LINT)
SONAR_RUNNER_EXE := @$(SONAR_RUNNER_EXE)
TRIAL := @$(TRIAL)
VIRTUALENV_EXE := @$(VIRTUALENV_EXE)
endif

# -----------------------------------------------------------------------------
# generate goals commands
# -----------------------------------------------------------------------------
CREATE_ENV_APM_DIRS := $(MKDIR) $(ENV_APM_DIRECTORY) $(ENV_TMP_DIRECTORY)
CREATE_ENV_APM_DIRS_ARTEFACT := $(TOUCH) $(ENV_APM_DIRS_CREATED) $(ENV_PATH_CREATED)
CREATE_BLD_DIRECTORY := $(MKDIR) $(ENV_BLD_DIRECTORY)

CLEAR_ENV_ACTIVATE_SCRIPT := $(RM) $(ENV_ACTIVATE_SCRIPT)
CLEAR_ENV_APM_DIRS := $(RM) $(ENV_APM_DIRECTORY) $(ENV_TMP_DIRECTORY)
CLEAR_ENV_APM_DIRS_ARTEFACT := $(RM) $(ENV_APM_DIRS_CREATED)
CLEAR_PACKAGE_INSTALL_ARTEFACT := $(RM) $(ENV_PACKAGE_INSTALL_ARTEFACT)
CLEAR_REQUIREMENTS_CONDA_ARTEFACT := $(RM) $(ENV_REQUIREMENTS_CONDA_ARTEFACT)
CLEAR_REQUIREMENTS_PIP_ARTEFACT := $(RM) $(ENV_REQUIREMENTS_PIP_ARTEFACT)
CLEAR_DOCS_REQUIREMENTS_ARTEFACT := $(RM) $(ENV_DOCS_REQUIREMENTS_ARTEFACT)
CLEAR_BUILD_REQUIREMENTS_ARTEFACT := $(RM) $(ENV_BUILD_REQUIREMENTS_ARTEFACT)
CLEAR_BLD_DIRECTORY_ARTEFACT := $(RM) $(ENV_BLD_DIRECTORY_ARTEFACT)
CLEAR_BLD_DIRECTORY := $(RM) $(ENV_BLD_DIRECTORY) $(ENV_BLD_DIRECTORY_ARTEFACT)

TMP_CONDA_CHANNELS := $(APM_EXTRA_CONDA_CHANNELS)
ifneq ($(APM_CONDA_CHANNELS),)
TMP_CONDA_CHANNELS += $(patsubst %,$(DEFAULT_CHANNEL_ALIAS)/%,$(APM_CONDA_CHANNELS))
endif
TMP_CONDA_CHANNELS += $(ENV_CFM_CHANNEL)

CONDA_CHANNELS_OPTIONS := $(patsubst %,-c %,$(TMP_CONDA_CHANNELS))
ifeq ($(ENV_INSIDE_CI_BUILD),yes)
CONDA_CREATE_OPTIONS := -q -y $(CONDA_OPTIONS) $(CONDA_CHANNELS_OPTIONS)
CONDA_INSTALL_OPTIONS := -q -y $(CONDA_OPTIONS) $(CONDA_CHANNELS_OPTIONS)
else
CONDA_CREATE_OPTIONS := -y $(CONDA_OPTIONS) $(CONDA_CHANNELS_OPTIONS)
CONDA_INSTALL_OPTIONS := -y $(CONDA_OPTIONS) $(CONDA_CHANNELS_OPTIONS)
endif

ENV_APM_INSTALL_CONDA_CMD := $(CONDA) install -c $(DEFAULT_CHANNEL_APM) $(CONDA_INSTALL_OPTIONS) $(APM_PACKAGE) $(DEV_NULL)
ENV_APM_INSTALL_PIP_CMD := $(PIP) install $(PIP_OPTIONS_APM) $(APM_PACKAGE) --upgrade --upgrade-strategy only-if-needed $(DEV_NULL)

ENV_CREATE_CMD := @false
ENV_APM_INSTALL_CMD := @false
ENV_REMOVE_CMD := @true


ifeq ($(ENV_TYPE),$(CST_TYPE_VIRTUALENV))
ifneq ($(ENV_PATH),)
ENV_CREATE_CMD := $(VIRTUALENV_EXE) $(ENV_PATH) $(TMP_VIRTUALENV_OPTIONS) $(DEV_NULL)
ENV_REMOVE_CMD := $(RM) $(ENV_PATH) $(DEV_NULL)
ENV_APM_INSTALL_CMD := $(ENV_APM_INSTALL_PIP_CMD)
endif
else ifeq ($(ENV_TYPE),$(CST_TYPE_CONDA))
ifneq ($(ENV_NAME),)
ENV_CREATE_CMD := $(CONDA_EXE) create $(CONDA_CREATE_OPTIONS) -n $(ENV_NAME) python=$(APM_PYTHON_VERSION) $(DEV_NULL)
ENV_REMOVE_CMD := $(RM) $(ENV_PATH) $(DEV_NULL)
ENV_APM_INSTALL_CMD := $(ENV_APM_INSTALL_CONDA_CMD)
endif
else ifeq ($(ENV_TYPE),$(CST_TYPE_PREFIX))
ifneq ($(ENV_PATH),)
ENV_CREATE_CMD := $(CONDA_EXE) create $(CONDA_CREATE_OPTIONS) -p $(ENV_NAME) python=$(APM_PYTHON_VERSION) $(DEV_NULL)
ENV_REMOVE_CMD := $(RM) $(ENV_PATH) $(DEV_NULL)
ENV_APM_INSTALL_CMD := $(ENV_APM_INSTALL_CONDA_CMD)
endif
endif

ifeq ($(PACKAGE_NAME),apm)
# hardcoded apm - do not install if apm development (waiting for build maintainer)
ENV_APM_INSTALL_CMD := @true
endif

ifneq ($(ENV_ACTIVATED),yes)
ENV_IS_ACTIVATED_CMD := $(call print_error,"please activate environment first") && $(ENV_ACTIVATE_SCRIPT_MESSAGE) && false
else
ENV_IS_ACTIVATED_CMD := true
endif

# determine project install in development mode
ENV_PKG_INSTALL_CMD_PIP := $(PIP) install -e . $(PIP_PACKAGE_INSTALL_OPTIONS) $(PIP_OPTIONS) --no-cache-dir
ENV_PKG_UNINSTALL_CMD_PIP := $(PIP) uninstall . --no-cache-dir
ENV_PKG_INSTALL_CMD_SETUP := $(PYTHON) setup.py develop --no-deps $(DEV_NULL)
ENV_PKG_UNINSTALL_CMD_SETUP := $(PYTHON) setup.py develop -u $(DEV_NULL)

ENV_PKG_INSTALL_CMD :=
ifeq ($(ENV_TYPE),virtualenv)
ENV_PKG_INSTALL_CMD := $(ENV_PKG_INSTALL_CMD_PIP)
ENV_PKG_UNINSTALL_CMD := $(ENV_PKG_UNINSTALL_CMD_PIP)
else
ENV_PKG_INSTALL_CMD := $(ENV_PKG_INSTALL_CMD_SETUP)
ENV_PKG_UNINSTALL_CMD := $(ENV_PKG_UNINSTALL_CMD_SETUP)
endif
ifneq ($(APM_MULTI_ENV),)
ENV_PKG_PIP_CMD := $(ENV_PATH)/bin/$(PIP_EXE) install $(PIP_PACKAGE_INSTALL_OPTIONS) $(PIP_OPTIONS) --no-cache-dir
ENV_PKG_INSTALL_CMD := @PIP_CMD="$(ENV_PKG_PIP_CMD)" $(CFM_APM) -vv --no-header install $(APM_INSTALL_OPTIONS) $(APM_MULTI_ENV)
ENV_PKG_UNINSTALL_CMD := true
endif

# -----------------------------------------------------------------------------
# Performance monitoring
# -----------------------------------------------------------------------------
ifeq ($(PYTEST_MONITOR),yes)
PYTEST_MONITOR_DISABLE=--no-monitor
ifeq ($(ENV_TYPE),$(CST_TYPE_PREFIX))
ifeq ($(shell $(CONDA) list -p $(ENV_NAME) | grep pytest-monitor),)
PYTEST_MONITOR_DISABLE=
endif
else
ifeq ($(ENV_TYPE),$(CST_TYPE_VIRTUALENV))
ifeq ($(shell $(PIP_EXE) freeze | grep pytest-monitor),)
PYTEST_MONITOR_DISABLE=
endif
endif
endif
else
PYTEST_MONITOR_DISABLE=
endif

PYTEST_MONITOR_COMPONENT ?= $(PACKAGE_NAME)
PYTEST_MONITOR_OPTIONS=--remote-server $(PYTEST_MONITOR_SERVER) --tag cfm=$(ENVIRONMENT_VERSION) --tag python=$(APM_PYTHON_VERSION) --tag version=$(PACKAGE_VERSION)
ifneq ($(PYTEST_MONITOR_COMPONENT),)
PYTEST_MONITOR_OPTIONS := $(PYTEST_MONITOR_OPTIONS) --component-prefix $(PYTEST_MONITOR_COMPONENT)
endif # ifneq ($(PYTEST_MONITOR_COMPONENT),)


ifneq ($(APM_MULTI_ENV),)
SINGLE_OR_MULTI = multi
else
SINGLE_OR_MULTI = single
endif

# -----------------------------------------------------------------------------
# more debug
# -----------------------------------------------------------------------------

ENV_ERROR := $(strip $(ENV_ERROR))
ENV_WARNINGS := $(strip $(ENV_WARNINGS))

# extra variables to display in make debug
APM_DEBUG_VARS :=

APM_DEBUG_VARS += TEST_PYTEST_ID_NAMES
APM_DEBUG_VARS += TEST_PYTEST_ID_MODULES
APM_DEBUG_VARS += ENV_ACTIVATED
APM_DEBUG_VARS += TMP_ENV_TYPE
APM_DEBUG_VARS += TMP_AUTO_ENVNAME
APM_DEBUG_VARS += TMP_ENV_LOCATION
APM_DEBUG_VARS += TMP_ENV_SUBFOLDER
APM_DEBUG_VARS += ENV_ACTIVATE_SCRIPT
APM_DEBUG_VARS += ENV_EXEC_MAINTAINER
APM_DEBUG_VARS += ENV_ACTIVATED
APM_DEBUG_VARS += ENV_ACTIVATED
APM_DEBUG_VARS += ENV_ACTIVATED
APM_DEBUG_VARS += ENV_APM_INSTALL_CMD
APM_DEBUG_VARS += ENV_CFM_CHANNEL
APM_DEBUG_VARS += ENV_CREATE_CMD
APM_DEBUG_VARS += ENV_CONDARC
APM_DEBUG_VARS += ENV_ERROR
APM_DEBUG_VARS += ENV_INSIDE_CI_BUILD
APM_DEBUG_VARS += ENV_NAME
APM_DEBUG_VARS += ENV_REMOVE_CMD
APM_DEBUG_VARS += ENV_TYPE
APM_DEBUG_VARS += ENV_IS_CONDA
APM_DEBUG_VARS += ENV_CONDAENV
APM_DEBUG_VARS += ENV_CONDAPREFIX
APM_DEBUG_VARS += ENV_VIRTUALENV
APM_DEBUG_VARS += ENV_PATH
APM_DEBUG_VARS += ENV_BLD_DIRECTORY
APM_DEBUG_VARS += FRONT_MAINTAINER
APM_DEBUG_VARS += RESEARCH_MAINTAINER
APM_DEBUG_VARS += MAINTAINER_ENVIRONMENT
APM_DEBUG_VARS += SONAR_RUNNER_EXE
APM_DEBUG_VARS += ENV_APM_MK
APM_DEBUG_VARS += ENV_PROJECTS_DIRS
APM_DEBUG_VARS += VIRTUALENV_EXE
APM_DEBUG_VARS += PIP_OPTIONS_APM
APM_DEBUG_VARS += PKG_CONDA_FILE_PATH
APM_DEBUG_VARS += PKG_CONDA_MANIFEST
APM_DEBUG_VARS += TESTS_COVERAGE_RC
APM_DEBUG_VARS += TESTS_JUNITS_XML
APM_DEBUG_VARS += ENV_APM_DIRS_CREATED
APM_DEBUG_VARS += ENV_APM_ARTEFACT
APM_DEBUG_VARS += THIS_PROJECT
APM_DEBUG_VARS += THIS_MAKEFILE
APM_DEBUG_VARS += ENV_REQUIREMENTS_CONDA
APM_DEBUG_VARS += CONDA_SKELETON_OPTIONS
APM_DEBUG_VARS += ENV_DEVTOOLSET
APM_DEBUG_VARS += PKG_CONDA_PACKAGES
APM_DEBUG_VARS += PKG_CONDA_LOCATION
# -----------------------------------------------------------------------------
# help goals
# -----------------------------------------------------------------------------
help:
	@$(call print_header)
	@$(call print_help_comment,T.HLP)
	@$(call print_help_comment,C.HLP)

help-config:
	@$(call print_header)
	@$(call print_info,"all makefile customization variables:")
	@$(call print_help_comment,C.)

help-goals:
	@$(call print_header)
	@$(call print_info,"all available makefile goals:")
	@$(call print_help_comment,T.)

help-env:
	@$(call print_header)
	@$(call print_info,"environment related goals:")
	@$(call print_help_comment,T.ENV)
	@$(call print_param,"  activated","$(ENV_ACTIVATED)")
	@$(call print_param,"  type","$(ENV_TYPE)")
	@$(call print_param,"  name","$(ENV_NAME)")
	@$(call print_param,"  directory","$(ENV_PATH)")
	@$(call print_param,"  build artefacts","$(ENV_BLD_DIRECTORY)")
	@$(call print_param,"  activation","$(ENV_ACTIVATE_CMD)")
	@$(call print_param,"  multiple", "$(APM_MULTI_ENV)")
	@$(call print_param,"  activation","source $(ENV_ACTIVATE_SCRIPT)")
	@$(call print_info,"environment customization arguments:")
	@$(call print_help_comment,C.ENV)
	@$(call print_info,"information")
	@$(call print_param,"type","$(ENV_TYPE)")
	@$(call print_param,"error","$(ENV_ERROR)")
	@$(call print_param,"activated","$(ENV_ACTIVATED)")
	@$(call print_param,"location","$(ENV_PATH)")

help-tests:
	@$(call print_header)
	@$(call print_info,"tests related goals:")
	@$(call print_help_comment,T.TST)
	@$(call print_info,"tests information:")
	@$(call print_param,"  build artefacts","$(ENV_BLD_DIRECTORY)")
	@$(call print_param,"  tests tool","$(TESTS_TOOL_NAME)")
	@$(call print_param,"  options","$(PYTEST_OPTIONS)")
	@$(call print_param,"  searching tests", "$(TESTS_MODULES)")
	@$(call print_info,"tests customization variables:")
	@$(call print_help_comment,C.TST)

help-package:
	@$(call print_header)
	@$(call print_info,"packaging related goals:")
	@$(call print_help_comment,T.PKG)
	@$(call print_info,"packaging customization variables:")
	@$(call print_help_comment,C.PKG)
	@$(call print_info,"packaging information:")
	@$(call print_param,"pip repository","$(REPOSITORY_SDIST_URL)")
	@$(call print_param,"conda repository","$(REPOSITORY_CONDA_URL)")

help-docs:
	@$(call print_header)
	@$(call print_info,"packaging related goals:")
	@$(call print_help_comment,T.DOC)
	@$(call print_info,"packaging customization variables:")
	@$(call print_help_comment,C.DOC)

info:
	@$(call print_header)
	@$(call print_info,"project:")
	@$(call print_param,"  name","$(PACKAGE_NAME)")
	@$(call print_param,"  team","$(PACKAGE_TEAM)")
	@$(call print_param,"  version","$(PACKAGE_VERSION)")
	@$(call print_param,"  sources","$(SOURCES_DIR)")
	@$(call print_info,"environment:")
	@$(call print_param,"  activated","$(ENV_ACTIVATED)")
	@$(call print_param,"  type","$(ENV_TYPE)")
	@$(call print_param,"  name","$(ENV_NAME)")
	@$(call print_param,"  directory","$(ENV_PATH)")
	@$(call print_param,"  python","$(ENV_PATH)/bin/python")
	@$(call print_param,"  builds","$(ENV_BLD_DIRECTORY)")
	@$(call print_param,"  activation","source $(ENV_ACTIVATE_SCRIPT)")
	@$(call print_info,"packaging:")
	@$(call print_param,"  sdist","$(PKG_SDIST_FILE_LOCATION)")
	@$(call print_param,"  sdist upload url","$(REPOSITORY_SDIST_URL)")
	@$(call print_param,"  conda upload  url","$(REPOSITORY_CONDA_URL)")


debug1:
	@$(foreach v, $(sort $(APM_OK_VARS)), printf '\033[36m%-25s\033[0m %s\n' '$(v)' '`$($(v))`'; )

debug:
	@$(call print_header)
	@$(call print_info,"makefile parameters:")
	@$(foreach v, $(sort $(APM_OK_VARS)),printf '\033[36m%-25s\033[0m %s\n' '$(v)' '`$(subst ', ,$(subst ", ,$($(v))))`';)
	@$(call print_info,"deprecated parameters:")
	@$(foreach v, $(sort $(APM_DEPREC_VARS)),printf '\033[34m%-25s\033[0m %s\n' '$(v)' '`$(subst ', ,$(subst ", ,$($(v))))`';)
	@$(call print_info,"internal variables:")
	@$(foreach v, $(sort $(APM_DEBUG_VARS)),printf '\033[35m%-25s\033[0m %s\n' '$(v)' '`$(subst ', ,$(subst ", ,$($(v))))`';)

cfm.yaml:
	@$(CFM_APM) quickstart info -q -f project.name=$(PACKAGE_NAME) project.version=$(PACKAGE_VERSION) \
		project.team=$(PACKAGE_TEAM) \
		project.language=python project.type=package \
		python.package=$(SOURCES_DIR) \
		repository.user=$(REPOSITORY_USER) repository.space=$(REPOSITORY_SPACE) \
		tests.tool=$(TESTS_TOOL) \
		sonar.key=$(SONAR_KEY) sonar.name=$(SONAR_KEY)


# -----------------------------------------------------------------------------
# cleaning goals
# -----------------------------------------------------------------------------

clean-package-egg:
	$(RM) $(PACKAGE_EGG)


clean-pyc:
	@$(call print_action,"cleaning pyc")
	$(FIND) . \( -name '__pycache__' -o -name '*.pyc' \) -not -path '$(ENV_PATH)/*' -delete || true

clean-docs:
ifneq ($(wildcard $(BLD_DOCS_DIRECTORY)),)
	@$(call print_action,"cleaning sphinx for documentation")
	$(RM) $(BLD_DOCS_DIRECTORY)
endif


clean-coverage:
	@$(call print_action,"cleaning coverage data")
	$(RM) $(TESTS_COVERAGE_LOCATION) $(TESTS_COVERAGE_RC) $(TESTS_COVERAGE_XML) .coverage


clean-tests:
	@$(call print_action,"cleaning test artefacts")
	$(RM) $(TESTS_JUNITS_XML) .cache .pytest_cache .sonar

clean-package:
	@$(call print_action,"cleaning packaging artefacts")
	$(RM) .apm $(PKG_SDIST_LOCATION)  $(PKG_CONDA_RECIPE_LOCATION) $(PKG_CONDA_LOCATION) $(PKG_CONDA_MANIFEST)

clean-artefacts:
	@$(call print_action,"cleaning artefacts")
	$(CLEAR_BLD_DIRECTORY)
	$(CLEAR_BLD_DIRECTORY_ARTEFACT)

clean-env-artefacts:
	$(CLEAR_ENV_APM_DIRS)

env-clean:
	@$(call print_action,"remove environment $(ENV_PATH)")
ifeq ($(ENV_ACTIVATED),yes)
	$(error Please, deactivate your environment first!)
else
	@$(ENV_PKG_UNINSTALL_CMD) || true
	$(ENV_REMOVE_CMD)
	$(CLEAR_ENV_ACTIVATE_SCRIPT)
endif

single-clean: clean-pyc clean-tests clean-coverage clean-package clean-docs

distclean: clean clean-artefacts clean-env-artefacts clean-package-egg env-clean


# -----------------------------------------------------------------------------
# environment goals
# -----------------------------------------------------------------------------
env-build: $(ENV_AVAILABLE) $(ENV_BLD_DIRECTORY_ARTEFACT) $(ENV_BUILD_REQUIREMENTS_ARTEFACT)
env-docs: $(ENV_AVAILABLE) $(ENV_BLD_DIRECTORY_ARTEFACT) $(ENV_DOCS_REQUIREMENTS_ARTEFACT)
env-install: $(ENV_AVAILABLE) $(ENV_PACKAGE_INSTALL_ARTEFACT) $(ENV_PACKAGE_DEPENDENCIES)

env: env-create env-build env-install env-docs
	@$(call print_header)
	@$(ENV_ACTIVATE_SCRIPT_MESSAGE)

$(ENV_PATH): $(ENV_AVAILABLE)
	@$(call print_action,"create $(ENV_TYPE) in $(ENV_PATH)")
	$(ENV_CREATE_CMD)
	$(CREATE_ENV_APM_DIRS)
	$(CREATE_ENV_APM_DIRS_ARTEFACT)

$(ENV_APM_DIRS_CREATED):
	$(CREATE_ENV_APM_DIRS)
	$(CREATE_ENV_APM_DIRS_ARTEFACT)

env-invalid:
	@$(call print_header)
	@$(call print_error,"$(ENV_ERROR)")
	@false

# -----------------------------------------------------------------------------
# build artefacts directory
# -----------------------------------------------------------------------------
$(ENV_BLD_DIRECTORY_ARTEFACT): $(ENV_APM_DIRS_CREATED)
	@$(call print_action,"create artefacts directory $(ENV_BLD_DIRECTORY)")
	$(CREATE_BLD_DIRECTORY)
	$(TOUCH) $(ENV_BLD_DIRECTORY_ARTEFACT)

# -----------------------------------------------------------------------------
# environment creation
# -----------------------------------------------------------------------------
$(ENV_ACTIVATE_SCRIPT): $(ENV_APM_DIRS_CREATED)
	@$(call print_action,"create launcher $(ENV_ACTIVATE_SCRIPT)")
	@echo "# ------------------------------" > $@
	@echo "# generated by Makefile $(APM_MAKEFILE_VERSION)" >> $@
	@echo "# ------------------------------" >> $@

ifneq ($(ENV_SCRIPT_MAINTAINER),)
	@echo "# source maintainer" >> $@
	@echo "$(ENV_SCRIPT_MAINTAINER)" >> $@
endif

ifeq ($(ENV_IS_CONDA),yes)
	@echo "# source conda-maintainer" >> $@
	@echo 'source /opt/conda-maintainer/$(APM_CONDA_VERSION)/enable' >> $@
	@echo 'if [[ -z $${ORACLE_HOME} ]]; then source /opt/sgbd-maintainer/oracle/client/sgbd-profile.sh; fi' >> $@
	@echo 'if [[ ! $$X_SCLS = *devtoolset* ]]; then source scl_source enable devtoolset-$(ENV_DEVTOOLSET); fi' >> $@
endif

	@echo "# activate environment" >> $@
	@echo "$(ENV_ACTIVATE_CMD)" >> $@
	@echo "# fix some parameters at creation" >> $@

$(ENV_APM_MK): $(ENV_APM_DIRS_CREATED)
	@$(call print_action,"create $(ENV_APM_MK)")
	@echo "# ------------------------------" >> $@
	@echo "# generated by Makefile $(APM_MAKEFILE_VERSION)" >> $@
	@echo "# from: $(THIS_DIRECTORY)" >> $@
	@echo "# ------------------------------" >> $@
	@echo "SKIP_ENV := $(SKIP_ENV)" >> $@
	@echo "ENVIRONMENT_VERSION := $(ENVIRONMENT_VERSION)" >> $@
	@echo "BUILD_DIR := $(ENV_BLD_DIRECTORY)" >> $@
ifneq ($(APM_MULTI_ENV),)
	@echo "TESTS_BEFORE_DEPENDENCIES :=" >> $@
endif
	@echo "SOURCE := $(THIS_DIRECTORY)" >> $@

$(ENV_CONDARC): $(ENV_APM_DIRS_CREATED)
	@$(call print_action,"create $(ENV_CONDARC)")
	@echo "channels:" > $@
	@echo -n " " >> $@
	@echo -e $(foreach v, $(TMP_CONDA_CHANNELS),  - $(v)\\n) >> $@

$(ENV_APM_ARTEFACT): $(ENV_APM_DIRS_CREATED)
ifneq ($(DONT_USE_BUILD_MAINTAINER),)
	@$(call print_action,"install latest version of apm")
	$(ENV_APM_INSTALL_CMD)
else
	@$(call print_info,"using apm from build-maintainer $(BUILD_MAINTAINER)")
endif
	$(TOUCH) $(ENV_APM_ARTEFACT)

env-create: $(ENV_AVAILABLE) $(ENV_PATH) $(ENV_CONDARC) $(ENV_APM_MK) $(ENV_ACTIVATE_SCRIPT) $(ENV_APM_ARTEFACT)

# -----------------------------------------------------------------------------
# build requirements
# -----------------------------------------------------------------------------
$(ENV_TMP_BUILD_REQUIREMENTS_PIP): $(ENV_APM_DIRS_CREATED)
	@$(call print_action,"create $@")
	@echo "# generated by Makefile" > $@
ifneq ($(BUILD_REQUIREMENTS_PIP),)
	@cat $(BUILD_REQUIREMENTS_PIP) >> $@
endif

$(ENV_TMP_BUILD_REQUIREMENTS_CONDA): $(ENV_APM_DIRS_CREATED)
	@$(call print_action,"create $@")
	@echo mock > $@
	@echo coverage >> $@
ifneq ($(DONT_USE_BUILD_MAINTAINER),)
	@echo flake8 >> $@
	@echo pylint >> $@
endif

ifeq ($(TESTS_TOOL_NAME),pytest)
	@echo pytest >> $@
	@echo pytest-cov >> $@
ifeq ($(PYTEST_MONITOR),yes)
	@echo pytest-monitor >> $@
endif
ifneq ($(NEW_PYTEST),yes)
	@echo pytest-capturelog >> $@
endif
	@echo pytest-profiling >> $@
	@echo pytest-mock >> $@
endif
ifeq ($(TESTS_TOOL_NAME),trial)
	@echo python-subunit >> $@
	@echo junitxml >> $@
endif
ifneq ($(BUILD_REQUIREMENTS_CONDA),)
	@cat $(BUILD_REQUIREMENTS_CONDA) >> $@
endif

$(ENV_BUILD_REQUIREMENTS_ARTEFACT): $(ENV_APM_DIRS_CREATED) $(ENV_TMP_BUILD_REQUIREMENTS_PIP) $(ENV_TMP_BUILD_REQUIREMENTS_CONDA)
ifneq ($(ENV_TMP_BUILD_REQUIREMENTS_CONDA),)
	@$(call print_action,"install $(ENV_TMP_BUILD_REQUIREMENTS_CONDA)")
	$(CONDA) install $(CONDA_INSTALL_OPTIONS) --file $(ENV_TMP_BUILD_REQUIREMENTS_CONDA) $(DEV_NULL)
	$(TOUCH) $(ENV_BUILD_REQUIREMENTS_ARTEFACT)
endif
ifneq ($(ENV_TMP_BUILD_REQUIREMENTS_PIP),)
	@$(call print_action,"install $(ENV_TMP_BUILD_REQUIREMENTS_PIP)")
	$(PIP) install $(PIP_OPTIONS) -r $(ENV_TMP_BUILD_REQUIREMENTS_PIP) $(DEV_NULL)
	$(TOUCH) $(ENV_BUILD_REQUIREMENTS_ARTEFACT)
endif

# -----------------------------------------------------------------------------
# docs-requirements installation
# -----------------------------------------------------------------------------
$(ENV_TMP_DOCS_REQUIREMENTS_PIP): $(ENV_BLD_DIRECTORY_ARTEFACT) $(DOCS_REQUIREMENTS)
	@$(call print_action,"create $@")
	@echo "# generated by Makefile" > $@
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \< 1901),1)
	@echo sphinx==1.4.4 >> $@
	@echo releases >> $@
else
	@echo sphinx >> $@
ifeq ($(ENV_IS_CONDA),no)
	@echo releases >> $@
else
	@echo sphinx-releases >> $@
endif
endif
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \> 1901),1)
	@echo sphinx_rtd_theme >> $@
endif
	@echo sphinxcontrib-httpdomain >> $@
ifneq ($(DOCS_REQUIREMENTS),)
	@cat $(DOCS_REQUIREMENTS) >> $@
endif

$(ENV_TMP_DOCS_REQUIREMENTS_CONDA): $(ENV_BLD_DIRECTORY_ARTEFACT) $(DOCS_REQUIREMENTS)
	@$(call print_action,"create $@")
	@echo sphinx > $@
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \> 1901),1)
	@echo sphinx_rtd_theme >> $@
endif
ifeq ($(shell expr $(ENVIRONMENT_LEVEL) \< 1901),1)
	@echo releases >> $@
else
ifeq ($(ENV_IS_CONDA),no)
	@echo releases >> $@
else
	@echo sphinx-releases >> $@
endif
endif
	@echo sphinxcontrib-httpdomain >> $@
	@echo sphinxcontrib-programoutput >> $@
ifneq ($(DOCS_REQUIREMENTS),)
	@cat $(DOCS_REQUIREMENTS) >> $@
endif

$(ENV_DOCS_REQUIREMENTS_ARTEFACT): $(ENV_TMP_DOCS_REQUIREMENTS_PIP) $(ENV_TMP_DOCS_REQUIREMENTS_CONDA)
ifneq ($(ENV_TYPE),virtualenv)
ifneq ($(ENV_TMP_DOCS_REQUIREMENTS_CONDA),)
	@$(call print_action,"install $(ENV_TMP_DOCS_REQUIREMENTS_CONDA)")
	$(CONDA) install -y $(CONDA_INSTALL_OPTIONS) --file $(ENV_TMP_DOCS_REQUIREMENTS_CONDA) $(DEV_NULL)
	$(TOUCH) $(ENV_DOCS_REQUIREMENTS_ARTEFACT)
endif
endif

ifneq ($(ENV_TMP_DOCS_REQUIREMENTS_PIP),)
	@$(call print_action,"install $(ENV_TMP_DOCS_REQUIREMENTS_PIP)")
	$(PIP) install $(PIP_OPTIONS) -r $(ENV_TMP_DOCS_REQUIREMENTS_PIP) $(DEV_NULL)
	$(TOUCH) $(ENV_DOCS_REQUIREMENTS_ARTEFACT)
endif

# -----------------------------------------------------------------------------
# installs requirements.txt if exists
# -----------------------------------------------------------------------------
$(ENV_REQUIREMENTS_PIP_ARTEFACT): $(ENV_APM_DIRS_CREATED) $(ENV_REQUIREMENTS_PIP)
ifneq ($(ENV_REQUIREMENTS_PIP),)
	@$(call print_action,"install $(PACKAGE_NAME) requirements.txt")
	$(PIP) install $(PIP_OPTIONS) -r $(ENV_REQUIREMENTS_PIP) $(DEV_NULL)
	$(TOUCH) $(ENV_REQUIREMENTS_PIP_ARTEFACT)
endif

# -----------------------------------------------------------------------------
# installs conda-requirements.txt if exists
# -----------------------------------------------------------------------------
$(ENV_REQUIREMENTS_CONDA_ARTEFACT): $(ENV_REQUIREMENTS_CONDA)
ifneq ($(ENV_REQUIREMENTS_CONDA),)
	@$(call print_action,"install $(PACKAGE_NAME) $(ENV_REQUIREMENTS_CONDA)")
	$(CONDA) install $(CONDA_INSTALL_OPTIONS) --file $(ENV_REQUIREMENTS_CONDA) $(DEV_NULL)
	$(TOUCH) $(ENV_REQUIREMENTS_CONDA_ARTEFACT)
endif

# -----------------------------------------------------------------------------
# install package in development mode
# -----------------------------------------------------------------------------
$(ENV_PACKAGE_INSTALL_ARTEFACT): $(ENV_APM_DIRS_CREATED) $(ENV_APM_ARTEFACT) $(ENV_PACKAGE_DEPENDENCIES)
	@$(call print_action,"install $(PACKAGE_NAME) in development mode")
	$(ENV_PKG_INSTALL_CMD)
	$(TOUCH) $(ENV_PACKAGE_INSTALL_ARTEFACT)

# -----------------------------------------------------------------------------
# pylint checks
# -----------------------------------------------------------------------------
single-pylint: $(ENV_CREATION)
	@$(call print_action,"pylint execution")
	$(PYLINT) $(TESTS_PYLINT_OPTIONS) $(TESTS_PYLINT_MODULES)

# -----------------------------------------------------------------------------
# pep8 checks
# -----------------------------------------------------------------------------

single-pep8: $(ENV_CREATION)
	@$(call print_action,"flake8 execution on $(PEP8_MODULES)")
	$(FLAKE8) $(TESTS_FLAKE8_OPTIONS) $(PEP8_MODULES) || ($(call print_error,"PEP8 errors detected!"); exit 1)

# -----------------------------------------------------------------------------
# black checks
# -----------------------------------------------------------------------------
single-black:
	@$(call print_action,"black check on $(PEP8_MODULES) $(BLACK_CONFIG_FILE)")
ifeq ("$(USE_PYPROJECT_TOML)","yes")
	@cat pyproject.toml > $(BLACK_CONFIG_FILE)
else
	@printf "[tool.black]\nline-length = $(BLACK_LINE_LENGTH)\n" > $(BLACK_CONFIG_FILE)
endif
	$(FLAKE8) $(TESTS_FLAKE8_OPTIONS) $(PEP8_MODULES) --black-config=$(BLACK_CONFIG_FILE) --select=BLK --black-report=$(ENV_BLD_DIRECTORY)/$(PACKAGE_NAME).blackreport.txt || ($(call print_error,"BLACK errors detected!"); exit 1)

black-reformat:
	@$(call print_action,"black formatting $(PEP8_MODULES)")
ifeq ("$(USE_PYPROJECT_TOML)","yes")
	@cat pyproject.toml > $(BLACK_CONFIG_FILE)
else
	@printf "[tool.black]\nline-length = $(BLACK_LINE_LENGTH)\n" > $(BLACK_CONFIG_FILE)
endif
	$(BLACK) --config=$(BLACK_CONFIG_FILE) $(PEP8_MODULES)

# ----------------------------------------------------------------------------
# style checks
# ----------------------------------------------------------------------------
single-style: $(patsubst %,single-%,$(APM_STYLE_CHECK))

# ----------------------------------------------------------------------------
#  Mypy checks
# ----------------------------------------------------------------------------
single-mypy: $(ENV_CREATION)
	@$(call print_action,"mypy execution")
	$(MYPY) $(MYPY_OPTIONS) $(MYPY_PACKAGES)

# -----------------------------------------------------------------------------
# cfm-lint: compliance to cfm standard
# -----------------------------------------------------------------------------
cfm-lint: $(ENV_CREATION)
	@$(call print_action,"cfm-lint execution")
	$(CFM_LINT)

# -----------------------------------------------------------------------------
# testing
# -----------------------------------------------------------------------------
tests-pytest: TESTS_PYTEST_OPTIONS += $(if $(filter yes, $(PROFILE)), "--profile")
tests-pytest: TESTS_PYTEST_OPTIONS += $(if $(filter yes, $(PYTEST_MONITOR)), -p no:cov $(PYTEST_MONITOR_OPTIONS), $(PYTEST_MONITOR_DISABLE))
tests-pytest: TESTS_PYTEST_OPTIONS += $(patsubst %,-k %,$(TEST_PYTEST_ID_NAMES))

tests-pytest:
ifneq ($(TESTS_MODULES),)
	@$(call print_action,"$(TESTS_TOOL_NAME) execution on $(TESTS_MODULES)")
	$(PYTEST) $(TESTS_PYTEST_OPTIONS) --junitxml=$(TESTS_JUNITS_XML) -m="$(TESTS_PYTEST_MARKERS)" $(TESTS_MODULES)
endif
ifeq ($(PROFILE), yes)
	$(PYPROF2CALLTREE) -i prof/combined.prof -o $(CALLGRINDNAME)
	$(ECHO) "QCachegrind file available in $(CALLGRINDNAME)"
endif

tests-trial:
ifneq ($(TESTS_MODULES),)
	@$(call print_action,"$(TESTS_TOOL_NAME) execution on $(TESTS_MODULES)")
	$(TRIAL) $(TESTS_MODULES)
endif

$(TESTS_JUNITS_XML):
	@$(call print_action,"generate fake junit $(TESTS_JUNITS_XML)")
	$(ECHO) '<?xml version="1.0" encoding="utf-8"?>' > $(TESTS_JUNITS_XML)
	$(ECHO) '<testsuites>' >> $(TESTS_JUNITS_XML)
	$(ECHO) '    <testsuite errors="1" failures="1" name="pytest" skipped="0" tests="1" time="0">' >> $(TESTS_JUNITS_XML)
	$(ECHO) '        <testcase classname="junit" file="missing.fake" line="3" name="$(PACKAGE_NAME)" time="0">' >> $(TESTS_JUNITS_XML)
	$(ECHO) '            <failure message="Test halted on timeout or unexpected Exception"></failure>' >> $(TESTS_JUNITS_XML)
	$(ECHO) '            <system-err> This junit file was generated by it-core makefile</system-err>' >> $(TESTS_JUNITS_XML)
	$(ECHO) '        </testcase>' >> $(TESTS_JUNITS_XML)
	$(ECHO) '    </testsuite>' >> $(TESTS_JUNITS_XML)
	$(ECHO) '</testsuites>' >> $(TESTS_JUNITS_XML)

fake-junit: $(TESTS_JUNITS_XML)
tests_: $(ENV_CREATION) tests-$(TESTS_TOOL_NAME)

single-tests:     TESTS_PYTEST_MARKERS?=$(TESTS_MARKERS_DEFAULT)
single-tests-fast:TESTS_PYTEST_MARKERS?=$(TESTS_MARKERS_FAST)
single-tests-full:TESTS_PYTEST_MARKERS?=$(TESTS_MARKERS_FULL)
single-tests single-tests-fast single-tests-full: $(TESTS_BEFORE_DEPENDENCIES) tests_ $(TESTS_EXTRA_DEPENDENCIES)

# -----------------------------------------------------------------------------
# coverage
# -----------------------------------------------------------------------------
$(TESTS_COVERAGE_RC):
	$(MKDIR) $(ENV_BLD_DIRECTORY)
ifneq ($(TESTS_MODULES),)
	$(ECHO) "[html]" > $@
	$(ECHO) "directory=$(TESTS_COVERAGE_LOCATION)" >> $@
	$(ECHO) "[xml]" >> $@
	$(ECHO) "output=$(TESTS_COVERAGE_XML)" >> $@
	$(ECHO) "[report]" >> $@
ifneq ($(TESTS_COVERAGE_INCLUDE),)
	$(ECHO) "include=$(TESTS_COVERAGE_INCLUDE)" >> $@
endif
ifneq ($(TESTS_COVERAGE_OMIT),)
	$(ECHO) "omit=$(TESTS_COVERAGE_OMIT)" >> $@
endif
	$(ECHO) "" >> $@
endif

coverage-pytest coverage-fast-pytest coverage-full-pytest: $(TESTS_COVERAGE_RC)
ifneq ($(TESTS_MODULES),)
	@$(call print_action,"$(TESTS_TOOL_NAME) execution with coverage")
	$(PYTEST) $(TESTS_COV_MODULES) --cov-config $(TESTS_COVERAGE_RC) --cov-report html --cov-report xml $(PYTEST_MONITOR_DISABLE) --junitxml $(TESTS_JUNITS_XML) $(TESTS_PYTEST_OPTIONS) -m="$(TESTS_PYTEST_MARKERS)" $(TESTS_MODULES)
	$(RM) $(TESTS_COVERAGE_RC) .coverage
	@$(call print_info,"The HTML coverage report can be opened from $(TESTS_COVERAGE_LOCATION)/index.html")
endif

coverage-trial: $(TESTS_COVERAGE_RC)
ifneq ($(TESTS_MODULES),)
	@$(call print_action,"$(TESTS_TOOL_NAME) execution with coverage")
#	Run trial 'inside' coverage
	$(COVERAGE) run $(shell $(ENV_EXEC) which trial) --reporter=subunit $(TESTS_MODULES) | $(SUBUNIT_1TO2) | $(SUBUNIT2JUNITXML) --no-passthrough > $(TESTS_JUNITS_XML)
	$(COVERAGE) html --rcfile $(TESTS_COVERAGE_RC)
	$(COVERAGE) xml --rcfile $(TESTS_COVERAGE_RC)
#	Clean intermediate files
	$(RM) $(TESTS_COVERAGE_RC) .coverage
	@$(call print_info,"The HTML coverage report can be opened from $(TESTS_COVERAGE_LOCATION)/index.html")
endif


coverage_: $(ENV_AVAILABLE) coverage-$(TESTS_TOOL_NAME)
single-coverage:      TESTS_PYTEST_MARKERS?=$(TESTS_MARKERS_DEFAULT)
single-coverage-full: TESTS_PYTEST_MARKERS?=$(TESTS_MARKERS_FULL)
single-coverage-fast: TESTS_PYTEST_MARKERS?=$(TESTS_MARKERS_FAST)
single-coverage single-coverage-fast single-coverage-full: $(TESTS_BEFORE_DEPENDENCIES) coverage_ $(TESTS_EXTRA_DEPENDENCIES)

coverage-check:
	@$(call print_action,"check coverage rate")
	@$(CFM_APM) -s coverage analyze $(TESTS_COVERAGE_XML) --min $(COVERAGE_LIMIT)

# -----------------------------------------------------------------------------
# pip python packaging
# -----------------------------------------------------------------------------
sdist-pkg: $(ENV_CREATION)
	@$(call print_action,"build pip package")
	$(RM) $(PKG_SDIST_LOCATION)
	$(MKDIR) $(PKG_SDIST_LOCATION)
	$(CHMOD) +w setup.cfg &>/dev/null || true
	$(PYTHON) setup.py sdist --dist-dir $(PKG_SDIST_LOCATION) $(DEV_NULL)
	$(ECHO) `find $(PKG_SDIST_LOCATION) -name $(PACKAGE_NAME)-*`

# -----------------------------------------------------------------------------
# conda python packaging
# -----------------------------------------------------------------------------
conda-recipe: $(ENV_CREATION)
ifeq ($(ENV_IS_CONDA),no)
	$(call print_error,"$@ is supported only in conda environment")
else ifeq ($(wildcard $(PKG_CONDA_SOURCES)),)
	@$(call print_error,"source distribution not found! please make-sdist before $@")
	@false
else
	@$(call print_action,"create conda recipe")
	$(CONDA_SKELETON) -f $(PKG_CONDA_SOURCES) -w $(PKG_CONDA_RECIPE_LOCATION) $(CONDA_SKELETON_OPTIONS) $(DEV_NULL)
	$(RM) $(PKG_CONDA_RECIPE_LOCATION)/skeleton
endif


conda-pkg: M_NUMPY_VERSION := $(or $(NUMPY_VERSION),$(shell $(MTRCINFO) show $(ENVIRONMENT_LEVEL) | $(JQ) .numpy_version))
conda-pkg: M_CONDA_PREFIX_LENGTH := $(shell $(MTRCINFO) show $(ENVIRONMENT_LEVEL) | $(JQ) .conda.prefix_length)
conda-pkg: M_CONDA_BUILD_OPTIONS := --numpy=$(M_NUMPY_VERSION) --prefix-length $(M_CONDA_PREFIX_LENGTH) --python $(CONDA_PYTHON_VERSION) $(CONDA_CHANNELS_OPTIONS) $(CONDA_OPTIONS)
conda-pkg: $(ENV_CREATION) conda-recipe
ifeq ($(ENV_IS_CONDA),no)
	@$(call print_error,"$@ is supported only in conda environment")
else
	@$(call print_action,"build conda package ")
	$(MKDIR) $(PKG_CONDA_LOCATION)
	$(RM) $(PKG_CONDA_LOCATION)/$(PACKAGE_NAME)-*
	$(CONDA) build purge-all $(DEV_NULL)
	$(CONDA) build $(M_CONDA_BUILD_OPTIONS) $(PKG_CONDA_RECIPE_LOCATION)  --output-folder $(PKG_CONDA_LOCATION) $(DEV_NULL)
	$(ECHO) `find $(PKG_CONDA_FILE_PATTERN)`
endif

package: sdist-pkg

# -----------------------------------------------------------------------------
# conda manifest
# -----------------------------------------------------------------------------
$(PKG_CONDA_MANIFEST): $(PKG_CONDA_FILE_PATH)
ifeq ($(ENV_IS_CONDA),no)
	@$(call print_error,"$@ is supported only in conda environment")
else
	@$(call print_action,"create conda deployment manifest")
	$(RM) $(PKG_CONDA_DEPLOY_ENV)
ifneq ($(ENV_REQUIREMENTS_CONDA),)
	$(CONDA) create $(CONDA_CREATE_OPTIONS) -p $(PKG_CONDA_DEPLOY_ENV) python=$(APM_PYTHON_VERSION) --file $(ENV_REQUIREMENTS_CONDA) $(DEV_NULL)
else
	@echo "warning: no files found matching 'conda-requirements.txt'"
	$(CONDA) create $(CONDA_CREATE_OPTIONS) -p $(PKG_CONDA_DEPLOY_ENV) python=$(APM_PYTHON_VERSION) $(DEV_NULL)
endif
ifneq ($(ENV_DEPLOY_REQUIREMENTS_CONDA),)
	 $(CONDA) install $(CONDA_INSTALL_OPTIONS) -p $(PKG_CONDA_DEPLOY_ENV) --file $(ENV_DEPLOY_REQUIREMENTS_CONDA) $(DEV_NULL)
endif
	$(CONDA) list -p $(PKG_CONDA_DEPLOY_ENV) --export --explicit > $(PKG_CONDA_MANIFEST)
	$(ECHO) $(PKG_CONDA_FILE_URL) >> $(PKG_CONDA_MANIFEST)
	@sed -i "s/_current\//_$(CURRENT_VERSION)\//" $(PKG_CONDA_MANIFEST)
ifneq ($(OLD_ENVIRONMENT_VERSION),)
	@sed -i "s/_old\//_$(OLD_ENVIRONMENT_VERSION)\//" $(PKG_CONDA_MANIFEST)
endif
ifneq ($(NEXT_ENVIRONMENT_VERSION),)
	@sed -i "s/_rc\//_$(NEXT_ENVIRONMENT_VERSION)\//" $(PKG_CONDA_MANIFEST)
endif
	$(ECHO) "$(PKG_CONDA_MANIFEST)"
endif

conda-manifest: $(PKG_CONDA_MANIFEST)

# -----------------------------------------------------------------------------
# sphinx doc
# -----------------------------------------------------------------------------
single-docs: $(ENV_CREATION) $(ENV_DOCS_REQUIREMENTS_ARTEFACT)
ifneq ($(DOCS_SOURCES),)
	@$(call print_action,"create html in $(BLD_DOCS_DIRECTORY)")
	$(RM) $(BLD_DOCS_DIRECTORY)
	$(MKDIR) $(BLD_DOCS_DIRECTORY)
	$(MKDIR) $(DOCS_SOURCES)/_static
	$(PYTHON) $(shell $(ENV_EXEC) which sphinx-build) -b html $(DOCS_SOURCES) $(BLD_DOCS_DIRECTORY)
endif

# -----------------------------------------------------------------------------
# packages repository
# -----------------------------------------------------------------------------
check-url:
	ifeq ($(CHECK_URL),)
		$(ECHO) "CHECK_URL not defined"
	else ifeq ("$(REPOSITORY_FORCE_UPLOAD)","yes")
		$(ECHO) "upload is forced"
	else ifeq ($(shell $(CURL) -k --output /dev/null --silent --fail -r 0-0 $(CHECK_URL) && echo "yes" || echo "no"), yes)
		$(error check : upload target already exists : $(CHECK_URL))
	else
		$(ECHO) "check : upload target is available."
	endif

sdist-check-upload:
ifeq ("$(REPOSITORY_FORCE_UPLOAD)","yes")
	@$(call print_action,"$(PKG_SDIST_FILE_URL) upload forced")
else
	@$(call print_action,"check pip $(PKG_SDIST_FILE_URL) available on repository")
	@! $(CURL) -k --output /dev/null --silent --fail -r 0-0 $(PKG_SDIST_FILE_URL)
endif

sdist-upload: env-create sdist-check-upload
ifneq ($(strip $(REPOSITORY_SPACE)),)
	@$(call print_action,"upload pip package to $(PKG_SDIST_FILE_URL)")
	$(EXEC_CURL) -k $(REPOSITORY_CREDENTIALS) -X MKCOL $(REPOSITORY_SDIST_URL)/ $(DEV_NULL) || true
	$(EXEC_CURL) -k -f $(REPOSITORY_CREDENTIALS) --upload-file $(PKG_SDIST_FILE_LOCATION) $(REPOSITORY_SDIST_URL)/ $(DEV_NULL)
	$(APM_CARTOGRAPHY) sdist-upload $(PKG_SDIST_APM_PARAMS) || true
else
	$(error invalid value REPOSITORY_SPACE)
endif

conda-check-upload:
ifeq ("$(REPOSITORY_FORCE_UPLOAD)","yes")
	@$(call print_action,"$(PKG_CONDA_SPEC) upload forced")
else
	@$(call print_action,"check conda $(PKG_CONDA_SPEC) available on repository")
	@! $(CONDA_RAW) search -c $(REPOSITORY_SPACE_URL)/conda --spec $(PKG_CONDA_SPEC) --override-channels 2>/dev/null $(FULL_DEV_NULL)
	@echo $(PKG_CONDA_SPEC) available to upload
endif

conda-upload: env-create conda-check-upload
ifeq ($(ENV_IS_CONDA),no)
	@$(call print_error,"$@ is supported only in conda environment")
else ifneq ($(strip $(REPOSITORY_SPACE)),)
ifneq ($(PKG_CONDA_FILE_URL),)
	@$(call print_action,"conda package $(PKG_CONDA_FILE_PATH) to $(REPOSITORY_CONDA_URL)")
	$(EXEC_CURL) -k $(REPOSITORY_CREDENTIALS) -X MKCOL $(REPOSITORY_CONDA_URL)/ &>/dev/null || true
	$(EXEC_CURL) -k $(REPOSITORY_CREDENTIALS) -X MKCOL $(REPOSITORY_CONDA_DEPLOY_URL)/ &>/dev/null || true
	$(EXEC_CURL) -k -f $(REPOSITORY_CREDENTIALS) --upload-file $(PKG_CONDA_FILE_PATH) $(REPOSITORY_CONDA_URL)/
ifneq ($(wildcard $(PKG_CONDA_MANIFEST)),)
	$(EXEC_CURL) -k -f $(REPOSITORY_CREDENTIALS) --upload-file $(PKG_CONDA_MANIFEST) $(REPOSITORY_CONDA_DEPLOY_URL)/
endif
	$(APM_CARTOGRAPHY) conda-upload $(APM_PARAMS) $(PKG_CONDA_APM_PARAMS) || true
else
	@echo no conda package found for upload
	@false
endif
endif

docs-upload-target-%:
ifneq ($(DOCS_LOCATION),)
	@if [[ -d $(DOCS_LOCATION) ]]; \
	then  \
		DOCS_BASE_URL=$(REPOSITORY_DOCS_URL); \
		TARGET_DOCS_URL=$${DOCS_BASE_URL}/$(PACKAGE_NAME)/$*; \
		echo "Uploading doc to $${TARGET_DOCS_URL}" ; \
		$(CURL) -k $(REPOSITORY_CREDENTIALS) --request MKCOL  $${DOCS_BASE_URL}/ --output /dev/null ; \
		$(CURL) -k $(REPOSITORY_CREDENTIALS) --request MKCOL  $${DOCS_BASE_URL}/$(PACKAGE_NAME)/ --output /dev/null ; \
		$(CURL) -k $(REPOSITORY_CREDENTIALS) --request DELETE $${TARGET_DOCS_URL}/ --output /dev/null ; \
		$(CURL) -k $(REPOSITORY_CREDENTIALS) --request MKCOL  $${TARGET_DOCS_URL}/ --output /dev/null ; \
		for FILE in $$(find $(BLD_DOCS_DIRECTORY)) ; \
		do \
			FILE2=$${FILE#"$(BLD_DOCS_DIRECTORY)/"} ; \
			TARGET=$${TARGET_DOCS_URL}/$$FILE2 ; \
			if [[ -d $$FILE ]]; \
			then \
				$(CURL) -k $(REPOSITORY_CREDENTIALS) --request MKCOL $$TARGET --output /dev/null ; \
			else \
				$(CURL) -k -f $(REPOSITORY_CREDENTIALS) --upload-file $$FILE $$TARGET --output /dev/null ; \
			fi \
		done; \
	fi
else
	@echo "No documentation found for upload"
endif

docs-check-upload:
ifeq ("$(REPOSITORY_FORCE_UPLOAD)","yes")
	@$(call print_action,"docs upload forced")
else
	@$(call print_action,"check docs version available on repository")
	@! $(CURL) -k --output /dev/null --silent --fail -r 0-0 $(REPOSITORY_DOCS_VERSION_URL)
endif

docs-upload: env-create docs-check-upload docs-upload-target-$(REPOSITORY_DOCS_VERSION) docs-upload-target-$(REPOSITORY_DOCS_LATEST)
ifneq ($(DOCS_LOCATION),)
ifneq ($(strip $(REPOSITORY_SPACE)),)
	$(APM_CARTOGRAPHY) docs-upload $(APM_PARAMS) repo.docs.url=$(REPOSITORY_DOCS_VERSION_URL) || true
else
	$(error invalid value REPOSITORY_SPACE)
endif
endif

# -----------------------------------------------------------------------------
# sonar
# -----------------------------------------------------------------------------
sonar-preview: $(ENV_CREATION) $(ENV_BLD_DIRECTORY_ARTEFACT)
	@$(call print_action,"sonar analysis in preview mode")
	$(SONAR_RUNNER_EXE) $(SONAR_PREVIEW_ARGUMENTS)
	$(RM) .sonar
	$(RM) $(ENV_BLD_DIRECTORY)/.sonar

sonar-issues: $(ENV_CREATION) $(ENV_BLD_DIRECTORY_ARTEFACT)
	@$(call print_action,"sonar analysis in issues mode")
	$(SONAR_RUNNER_EXE) $(SONAR_ISSUES_ARGUMENTS) $(DEV_NULL)
	@$(CFM_APM) -s sonar analyze $(ENV_BLD_DIRECTORY)/sonar.json $(SONAR_ISSUES_OPTIONS)

sonar-upload: $(ENV_CREATION) $(ENV_BLD_DIRECTORY_ARTEFACT)
ifeq ($(SONAR_SOURCES),)
	@echo -e "\033[0;33mWarning\033[0m : sources directory is either not found or doesn't have standard name."
	@echo -e "You may configure it manually by setting the PACKAGE_MODULES variable, Exemple: PACKAGE_MODULES=DIR1,DIR2,DIR3"
else
	@$(call print_action,"sonar analysis in publish mode")
	$(SONAR_RUNNER_EXE) $(SONAR_PUBLISH_ARGUMENTS)
	@$(call print_action,"send information to application portfolio")
	$(APM_CARTOGRAPHY) sonar-upload $(APM_PARAMS) sonar.key=$(SONAR_KEY) || true
endif

# -----------------------------------------------------------------------------
# cartography
# -----------------------------------------------------------------------------
apm-cartography: env-create
	@$(call print_action,"publishing to application portfolio.")
	$(APM_CARTOGRAPHY) publish  $(APM_PARAMS) $(DEV_NULL)

apm-info: env-create
	@$(call print_action,"display information for application portfolio")
	$(APM_CARTOGRAPHY) info $(APM_PARAMS)

# -----------------------------------------------------------------------------
# distribution post build
# -----------------------------------------------------------------------------
dist: $(ENV_BLD_DIRECTORY_ARTEFACT)
	@$(call print_action,"prepare distribution in $(ENV_BLD_DIRECTORY)")
	$(CP) -f Makefile $(ENV_BLD_DIRECTORY)
	$(ECHO) APM_MAKEFILE_DIST := yes > $(DIST_CONFIG_MK)
	$(ECHO) APM_PYTHON_VERSION := $(APM_PYTHON_VERSION) >> $(DIST_CONFIG_MK)
	$(ECHO) BUILD_DIR := . >> $(DIST_CONFIG_MK)
	$(ECHO) PACKAGE_NAME := $(PACKAGE_NAME) >> $(DIST_CONFIG_MK)
	$(ECHO) PACKAGE_TEAM := $(PACKAGE_TEAM) >> $(DIST_CONFIG_MK)
	$(ECHO) PACKAGE_VERSION := $(PACKAGE_VERSION) >> $(DIST_CONFIG_MK)
	$(ECHO) SOURCES_DIR := $(SOURCES_DIR) >> $(DIST_CONFIG_MK)
	$(ECHO) REPOSITORY_SPACE := $(REPOSITORY_SPACE) >> $(DIST_CONFIG_MK)
	$(ECHO) REPOSITORY_USER := $(REPOSITORY_USER) >> $(DIST_CONFIG_MK)
	$(ECHO) APM_MULTI_ENV := $(APM_MULTI_ENV) >> $(DIST_CONFIG_MK)
ifneq ($(wildcard ${PKG_CONDA_MANIFEST}),)
	${ECHO} DEPLOY_FILE := $(notdir ${PKG_CONDA_MANIFEST}) >> $(DIST_CONFIG_MK)
endif

dist-properties: $(ENV_BLD_DIRECTORY_ARTEFACT)
	@$(call print_action,"writing distribution properties in $(ENV_BLD_DIRECTORY)")
	$(ECHO) ${THIS_PROJECT}_APM_MAKEFILE_DIST=yes > $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_BUILD_DIR=. >> $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_PACKAGE_NAME=$(PACKAGE_NAME) >> $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_PACKAGE_TEAM=$(PACKAGE_TEAM) >> $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_PACKAGE_VERSION=$(PACKAGE_VERSION) >> $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_SOURCES_DIR=$(SOURCES_DIR) >> $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_REPOSITORY_SPACE=$(REPOSITORY_SPACE) >> $(DIST_PROPERTIES)
	$(ECHO) ${THIS_PROJECT}_REPOSITORY_USER=$(REPOSITORY_USER) >> $(DIST_PROPERTIES)
ifneq ($(wildcard ${PKG_CONDA_MANIFEST}),)
	${ECHO} ${THIS_PROJECT}_DEPLOY_FILE=$(notdir ${PKG_CONDA_MANIFEST}) >> $(DIST_PROPERTIES)
endif

# -----------------------------------------------------------------------------
# IPython kernel integration
# -----------------------------------------------------------------------------
ipykernel: $(ENV_CREATION)
ifneq ($(ENV_PYKERNEL_ID),)
	@$(call print_action,"creating ipython kernel")
ifeq ($(ENV_IS_CONDA),yes)
	$(CONDA) install $(CONDA_INSTALL_OPTIONS) ipykernel $(DEV_NULL)
endif
	$(PYTHON) -m ipykernel install --name $(ENV_PYKERNEL_ID) --user
endif

jupyter-lsp: M_LSP_FILE = cfm-makefile.json
jupyter-lsp: M_LSP_SOURCE = /opt/build-maintainer/cfm/current/share/jupyter
jupyter-lsp: M_LSP_DEST = /home/$(USER)/.jupyter/jupyter_server_config.d
jupyter-lsp:
	@$(call print_action,"writing LSP configuration in $(M_LSP_DEST)")
	$(MKDIR) $(M_LSP_DEST)
	$(PYTHON) -c 'print(open("$(M_LSP_SOURCE)/$(M_LSP_FILE)").read(). \
	                    replace("[ENV_PATH]", "$(ENV_PATH)").\
	                    replace("[ENV_NAME]", "$(ENV_NAME)")\
	                    )' > $(M_LSP_DEST)/$(M_LSP_FILE)

jupyter: ipykernel jupyter-lsp


# -----------------------------------------------------------------------------
# this makefile upgrade
# -----------------------------------------------------------------------------
upgrade-me:
	@$(call print_action,"get latest version of Makefile $(APM_MAKEFILE_VERSION_LAST).")
ifneq ($(FORCED),yes)
	@if [[ ! -w Makefile ]]; \
	then \
		echo Makefile is READ ONLY; \
		false; \
	fi
endif
	$(MV) Makefile Makefile.sav
	$(WGET) $(REPOSITORY_MAKEFILE_URL) --no-check-certificate $(DEV_NULL)
	$(RM) Makefile.sav

# ----------------------------
# conda build using APM
# ----------------------------
# conda-bundle : used apm to package all sub projects in one package only
# conda-build : used apm to package one package only (in place of conda-recipe and conda package)

# conda-bundle (using apm)
# ------------------------
ifneq ($(DONT_USE_BUILD_MAINTAINER),)
conda-bundle: M_APM_CONDA_COMMAND = $(ENV_EXEC) apm  --no-header -vvv conda
else
conda-bundle: M_APM_CONDA_COMMAND = $(CFM_APM)  --no-header -vvv conda
endif

conda-bundle: M_NUMPY_VERSION := $(or $(NUMPY_VERSION),$(shell $(MTRCINFO) show $(ENVIRONMENT_LEVEL) | $(JQ) .numpy_version))
conda-bundle: M_BUILD_OPTS = --name $(PACKAGE_NAME) --skeleton --numpy $(M_NUMPY_VERSION) --python $(CONDA_PYTHON_VERSION) --output $(PKG_CONDA_LOCATION) --build-number=$(APM_BUILD_NUMBER)
ifeq ($(APM_CONDA_PLATFORM),noarch)
conda-bundle: M_BUILD_NO_ARCH = --noarch
else
conda-bundle: M_BUILD_NO_ARCH =
endif

conda-bundle:
	@$(call print_action,"create conda bundle")
	$(M_APM_CONDA_COMMAND) $(CONDA_CHANNELS_OPTIONS) build $(M_BUILD_OPTS) $(M_BUILD_NO_ARCH) $(ENV_PROJECTS_DIRS) $(DEV_NULL)


# conda build (using apm)
# -----------------------
ifneq ($(DONT_USE_BUILD_MAINTAINER),)
conda-build: M_APM = $(ENV_EXEC) apm
else
conda-build: M_APM = $(CFM_APM)
endif
conda-build: M_NUMPY_VERSION := $(or $(NUMPY_VERSION),$(shell $(MTRCINFO) show $(ENVIRONMENT_LEVEL) | $(JQ) .numpy_version))
conda-build: M_BUILD_COMMAND = --no-header -vvv conda $(CONDA_CHANNELS_OPTIONS) build
conda-build: M_BUILD_OPTS = --skeleton --numpy $(M_NUMPY_VERSION) --python $(CONDA_PYTHON_VERSION) --output $(PKG_CONDA_LOCATION) --build-number=$(APM_BUILD_NUMBER)
ifeq ($(APM_CONDA_PLATFORM),noarch)
conda-build: M_BUILD_NO_ARCH = --noarch
else
conda-build: M_BUILD_NO_ARCH =
endif
conda-build: $(ENV_CREATION)
	@$(call print_action,"conda-build execution")
	$(M_APM) $(M_BUILD_COMMAND) $(M_BUILD_OPTS) $(M_BUILD_NO_ARCH) . $(DEV_NULL)

# -----------------------------------------------------------------------------
# MULTI ENVIRONMENT
# -----------------------------------------------------------------------------
# to proceed multi-environment commands, we apply templated command using %
# applied on projects (ENV_PROJECTS_DIRS) thru dependencies using pathsubst
# dependency format is <project>.<command>.per_folder

multi-debug: 							 $(patsubst %,%.debug.per_folder,$(ENV_PROJECTS_DIRS))
multi-clean: 							 $(patsubst %,%.clean.per_folder,$(ENV_PROJECTS_DIRS))
multi-info: 			$(ENV_AVAILABLE) $(patsubst %,%.info.per_folder,$(ENV_PROJECTS_DIRS))
multi-pep8: 			$(ENV_AVAILABLE) $(patsubst %,%.pep8.per_folder,$(ENV_TESTS_DIRS))
multi-mypy: 			$(ENV_AVAILABLE) $(patsubst %,%.mypy.per_folder,$(ENV_TESTS_DIRS))
multi-style: 			$(ENV_AVAILABLE) $(patsubst %,%.style.per_folder,$(ENV_TESTS_DIRS))
multi-tests: 			$(ENV_AVAILABLE) $(patsubst %,%.tests.per_folder,$(ENV_TESTS_DIRS))
multi-tests-fast: 		$(ENV_AVAILABLE) $(patsubst %,%.tests-fast.per_folder,$(ENV_TESTS_DIRS))
multi-tests-full: 		$(ENV_AVAILABLE) $(patsubst %,%.tests-full.per_folder,$(ENV_TESTS_DIRS))
multi-fake-junit: 		$(ENV_AVAILABLE) $(patsubst %,%.fake-junit.per_folder,$(ENV_TESTS_DIRS))
multi-coverage: 		$(ENV_AVAILABLE) $(patsubst %,%.coverage.per_folder,$(ENV_TESTS_DIRS))
multi-coverage-fast: 	$(ENV_AVAILABLE) $(patsubst %,%.coverage-fast.per_folder,$(ENV_TESTS_DIRS))
multi-coverage-full: 	$(ENV_AVAILABLE) $(patsubst %,%.coverage-full.per_folder,$(ENV_TESTS_DIRS))
multi-sonar-upload: 	$(ENV_AVAILABLE) $(patsubst %,%.sonar-upload.per_folder,$(ENV_PROJECTS_DIRS))
multi-docs: 			$(ENV_AVAILABLE) $(patsubst %,%.docs.per_folder,$(ENV_PROJECTS_DIRS))
multi-sdist: 			$(ENV_AVAILABLE) $(patsubst %,%.sdist-pkg.per_folder,$(ENV_PROJECTS_DIRS))
multi-sdist-pkg: 		multi-sdist
multi-dist:				dist 			 $(patsubst %,%.dist.per_folder,$(ENV_PROJECTS_DIRS)) dist
multi-dist-properties: 					 $(patsubst %,%.dist-properties.per_folder,$(ENV_PROJECTS_DIRS))
multi-docs-upload: 		$(ENV_AVAILABLE) $(patsubst %,%.docs-upload.per_folder,$(ENV_PROJECTS_DIRS))
multi-sdist-upload: 	$(ENV_AVAILABLE) $(patsubst %,%.sdist-upload.per_folder,$(ENV_PROJECTS_DIRS))
multi-conda-build: 		multi-conda-clean $(patsubst %,%.conda-build.per_folder,$(ENV_PROJECTS_DIRS))



# extra cleaning for multiple projects
multi-clean: clean-docs

multi-conda-clean:
	$(RM) $(PKG_CONDA_LOCATION)/*

# by default detect parameters
%.per_folder: M_PROJECT=$(word 1,$(subst ., ,$@))
%.per_folder: M_TARGET=$(word 2,$(subst ., ,$@))

# by default, pass root configuration variables to make execution per folder
# and ensure environment is activated prior to call make pe folder
%.per_folder: M_MAKE=$(MAKE_IN_ENV)

ifeq ($(DONT_USE_BUILD_MAINTAINER),)
# for style, no need to activate environment if using BM
%.clean.per_folder: M_MAKE=$(MAKE)
%.style.per_folder: M_MAKE=$(MAKE)
endif


%.per_folder: M_TESTS_FILTER=$(strip $(foreach t,$(TESTS_FILTER),$(if $(findstring $(M_PROJECT),$(t)),$(word 2,$(subst :, ,$(t))),)))

%.per_folder: M_MAKE_VARIABLES = BUILD_DIR=$(M_BUILD_DIRECTORY) BLD_DOCS_DIRECTORY=$(M_BUILD_DIRECTORY) \
SKIP_ENV=yes VERBOSE=$(VERBOSE) PROFILE=$(strip $(PROFILE)) PYTEST_MONITOR=$(PYTEST_MONITOR) \
PACKAGE_TEAM=$(PACKAGE_TEAM) REPOSITORY_SPACE=$(REPOSITORY_SPACE) REPOSITORY_USER=$(REPOSITORY_USER) \
ENV_PATH=$(ENV_PATH) TESTS_FILTER="$(M_TESTS_FILTER)"

# by default, build directories are segregated per project in environment
%.per_folder: M_BUILD_DIRECTORY=$(shell $(READLINK) $(ENV_BLD_DIRECTORY)/$(M_PROJECT))

# for multi-conda-build: need to override M_BUILD_DIRECTORY to share conda local channel
%.conda-build.per_folder: M_BUILD_DIRECTORY=$(shell $(READLINK) $(ENV_BLD_DIRECTORY))

# for docs / docs-upload : we override build directory
%.docs.per_folder: M_BUILD_DIRECTORY=$(shell $(READLINK) $(BLD_DOCS_DIRECTORY)/$(M_PROJECT))
%.docs-upload.per_folder: M_BUILD_DIRECTORY=$(shell $(READLINK) $(BLD_DOCS_DIRECTORY)/$(M_PROJECT))

# for clean and debug : avoid automatic environment activation
%.debug.per_folder: M_MAKE=$(MAKE)
%.clean.per_folder: M_MAKE=$(MAKE)

%.per_folder:
	@$(call print_header)
	@$(call print_action,"$(M_TARGET) execution in $(M_PROJECT) folder")
	$(MKDIR) $(M_BUILD_DIRECTORY)
	@+$(M_MAKE) -f $(THIS_MAKEFILE) -C $(M_PROJECT) $(M_TARGET) $(M_MAKE_VARIABLES)

# --------------------------------------------------
# multi manifest: installs all packages built
# --------------------------------------------------
multi-manifest: M_PACKAGES = $(shell find $(PKG_CONDA_LOCATION) -name repodata.json -exec cat {} \; | $(JQ) -r .packages[].name | uniq)
multi-manifest: M_LOCAL_CHANNEL_URL = file://$(PKG_CONDA_LOCATION)
multi-manifest: M_REPO_CHANNEL_URL = $(REPOSITORY_SPACE_URL)/conda
multi-manifest: M_MANIFEST = $(PKG_CONDA_LOCATION)/$(PKG_CONDA_MANIFEST)
multi-manifest:
	@$(call print_action, "multi project manifest $(M_MANIFEST)")
	$(RM) $(PKG_CONDA_DEPLOY_ENV)
	$(CONDA) create -p $(PKG_CONDA_DEPLOY_ENV) $(CONDA_CREATE_OPTIONS) -c $(M_LOCAL_CHANNEL_URL) python=$(APM_PYTHON_VERSION) $(M_PACKAGES)
	$(CONDA) list -p $(PKG_CONDA_DEPLOY_ENV) --export --explicit > $(M_MANIFEST)
	@sed -i 's/$(subst /,\/,$(M_LOCAL_CHANNEL_URL))/$(subst /,\/,$(M_REPO_CHANNEL_URL))/g' $(M_MANIFEST)
	@$(call print_success, "manifest $(M_MANIFEST)")

# --------------------------------------------------
# multi-conda-upload
# --------------------------------------------------
# executes template command %.upload on all packages
# overides M_FILE_PATH and M_TARGET_URL to parametrize generic %upload command

%.upload: M_CURL = $(CURL) -q -k -f $(REPOSITORY_CREDENTIALS) --output /dev/null --upload-file
%.upload: M_FILE = $*
%.upload: M_FILE_PATH = $(PKG_CONDA_LOCATION)/$(M_FILE)
%.upload: M_TARGET_URL = $(REPOSITORY_SPACE_URL)/conda/$(M_FILE)

%.upload:
	$(M_CURL) $(M_FILE_PATH) $(M_TARGET_URL)


multi-conda-run-upload: $(patsubst %,%.upload,$(subst $(PKG_CONDA_LOCATION)/,,$(PKG_CONDA_PACKAGES)))

# the manifest upload is uses same logic
manifest.upload: M_FILE_PATH = $(PKG_CONDA_LOCATION)/$(PKG_CONDA_MANIFEST)
manifest.upload: M_TARGET_URL=$(REPOSITORY_CONDA_DEPLOY_URL)/$(PKG_CONDA_MANIFEST)

ifneq ($(wildcard $(PKG_CONDA_LOCATION)/$(PKG_CONDA_MANIFEST)),)
manifest-run-upload: manifest.upload
else
manifest-run-upload:
	@$(call print_info,"no manifest found")
endif

# to check upload, we override generic %upload to determine TARGET_URL
# and the M_CURL command to
%.check.upload: M_CURL = $(CURL) -q -k $(REPOSITORY_CREDENTIALS) --output /dev/null --silent --fail -r 0-0
%.check.upload:
	@! $(M_CURL) $(M_TARGET_URL)

ifneq ("$(REPOSITORY_FORCE_UPLOAD)","yes")
# apply check-upload to all packages (ex noarch/package-1.0.0.tar.bz2)
multi-conda-check-upload: $(patsubst %,%.check.upload,$(subst $(PKG_CONDA_LOCATION)/,,$(PKG_CONDA_PACKAGES)))
else
# bypass check-upload with an empty target
multi-conda-check-upload:
	@$(call print_info,"upload forced")
endif

# finally complete upload targets is implemented as followed
multi-conda-upload: multi-conda-check-upload multi-conda-run-upload manifest.upload

# -----------------------------------------------------------------------------
# debug goals : custom.mk
# -----------------------------------------------------------------------------
debug-variable:
	@echo $($(DEBUG_VARIABLE))

%.variable.print: M_VAR = $(firstword $(subst ., ,$@))
%.debug.variable.print: M_TYPE = debug
%.deprecated.variable.print: M_TYPE = deprecated
%.used.variable.print: M_TYPE = used

%.variable.print:
	@$(ECHO) $(M_VAR) = "$($(M_VAR))"

debug.variables.info : M_TEXT="debug variables"
deprecated.variables.info : M_TEXT="deprecates variables"
used.variables.info : M_TEXT="used variables"

%.info:
	@$(call print_action,$(M_TEXT))

debug.variables.display: debug.variables.info $(patsubst %,%.debug.variable.print,$(sort $(APM_DEBUG_VARS)))
deprecated.variables.display: deprecated.variables.info $(patsubst %,%.deprecated..variable.print,$(sort $(APM_DEPREC_VARS)))
used.variables.display: used.variables.info $(patsubst %,%.used.variable.print,$(sort $(APM_OK_VARS)))
display-variables: used.variables.display debug.variables.display deprecated.variables.displa

# -----------------------------------------------------------------------------
# final goals : switch between single or multiple project
# -----------------------------------------------------------------------------
header:
	@$(call print_header)

# deprecated targets
pep8-is-deprecated:
	@$(call print_error,"The target pep8 is deprecated: use make style")

black-is-deprecated:
	@$(call print_error,"The target black is deprecated: use make style")

pep8:  header pep8-is-deprecated
black:  black-is-deprecated

clean:          $(SINGLE_OR_MULTI)-clean
mypy:           $(SINGLE_OR_MULTI)-mypy
style:          $(SINGLE_OR_MULTI)-style
pylint:         $(SINGLE_OR_MULTI)-pylint
pep8:           $(SINGLE_OR_MULTI)-pep8
black:          $(SINGLE_OR_MULTI)-black
tests:          $(SINGLE_OR_MULTI)-tests
tests-fast:     $(SINGLE_OR_MULTI)-tests-fast
tests-full:     $(SINGLE_OR_MULTI)-tests-full
coverage:       $(SINGLE_OR_MULTI)-coverage
coverage-fast:  $(SINGLE_OR_MULTI)-coverage-fast
coverage-full:  $(SINGLE_OR_MULTI)-coverage-full
docs:           $(SINGLE_OR_MULTI)-docs

# -----------------------------------------------------------------------------
# docker
# -----------------------------------------------------------------------------
docker-info:
	$(ECHO) "Image: $(DOCKER_IMAGE_NAME)"
	$(ECHO) "Version: $(DOCKER_IMAGE_VERSION)"
	$(ECHO) "Remote: $(DOCKER_REMOTE_CHANNEL)"

docker-build:
	$(DOCKER) build -t $(_DOCKER_IMAGE_TAG) $(_DOCKER_BUILD_FLAGS) .

docker-login:
	$(DOCKER) login -u $(ARTIFACTORY_USER) --password  $(ARTIFACTORY_PASSWORD) $(DOCKER_REGISTRY_URL)

docker-push: M_IMAGE_REMOTE=$(DOCKER_REGISTRY)/$(DOCKER_REMOTE_CHANNEL)/$(_DOCKER_IMAGE_TAG)
docker-push:
	$(DOCKER) tag $(_DOCKER_IMAGE_TAG) $(M_IMAGE_REMOTE)
	$(DOCKER) push $(M_IMAGE_REMOTE)

# -----------------------------------------------------------------------------
# custom goals : custom.mk / custom.mak
# -----------------------------------------------------------------------------
ifneq ($(wildcard custom.mak),)
-include custom.mak
# projects' scope custom targets
endif

ifneq ($(wildcard custom.mk),)
-include custom.mk
# projects' scope custom targets
endif

ifneq ($(wildcard ~/.apm/python/custom.mk),)
-include ~/.apm/python/custom.mk
# extra target enabled per environment
endif
