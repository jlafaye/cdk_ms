# --------------------------------------------------------
# This is a generic makefile for AWS operations
# all project specific configuration is set in config.mk
# --------------------------------------------------------
AWS_MAKEFILE_VERSION = 0.0.1
# --------------------------------------------------------

.PHONY: aws-makefile-check
.PHONY: aws-makefile-upgrade


-include ../docker/config.mk

-include config.mk

BUILD_MAINTAINER=/opt/build-maintainer/cfm/current/bin
ECHO=@echo

CURL = /bin/curl
AWS_MAKEFILE_REPOSITORY := https://repository.development.cfm.fr/it-core/tools/aws
AWS_MAKEFILE_URL := $(AWS_MAKEFILE_REPOSITORY)/Makefile

AWS_MAKEFILE_VERSION_LAST := $(shell $(CURL) --silent $(AWS_MAKEFILE_REPOSITORY)/Makefile.version)

ENVIRONMENT_LOCATION ?= $(TMPDIR)/cdk_env
CONDA ?= /opt/conda-maintainer/current/conda

CONDA_RUN=$(CONDA) run --live-stream -p $(ENVIRONMENT_LOCATION)
CFM_PROXY=http://proxy.fr.cfm.fr:6060
CFM_CDK_BOOSTRAP_OPTIONS ?=

ifneq ($(wildcard $(ENVIRONMENT_LOCATION)),)
	CDK := $(CONDA_RUN) cdk
	AWS := $(CONDA_RUN) aws
	CFM_VAULT := $(CONDA_RUN) cfm-vault
	FLAKE8 :=  $(CONDA_RUN) flake8
else
    CDK := $(BUILD_MAINTAINER)/cdk
    AWS := $(BUILD_MAINTAINER)/aws
    CFM_VAULT := $(BUILD_MAINTAINER)/cfm-vault
    FLAKE8 := $(BUILD_MAINTAINER)/flake8
endif

CDK := AWS_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt HTTPS_PROXY=$(CFM_PROXY) $(CDK)
AWS_NO_PROXY :=  AWS_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt $(AWS)
AWS := AWS_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt HTTPS_PROXY=$(CFM_PROXY) $(AWS)


_CD_CDK_DIR :=
ifneq ($(wildcard ../cdk),)
    _CD_CDK_DIR :=  cd ../cdk &&
endif

CDK := $(_CD_CDK_DIR) $(CDK)

_AWS_ACCOUNT_ID=$(shell $(AWS) sts get-caller-identity --query Account --output text --profile $(CFM_AWS_PROFILE))

# environment for CDK operations
_AWS_CDK_ENV += CDK_DEFAULT_REGION=$(CFM_AWS_REGION)
_AWS_CDK_ENV += CDK_DEFAULT_ACCOUNT=$(_AWS_ACCOUNT_ID)
_AWS_CDK_ENV += CFM_AWS_ENVIRONMENT=$(CFM_AWS_ENVIRONMENT)


aws-env:
	$(CONDA) create -p $(ENVIRONMENT_LOCATION) -q -y python
	$(CONDA) install -p $(ENVIRONMENT_LOCATION) -q -y --channel it_data_lake --channel cfm_2201-aws --channel cfm_common --file build-requirements.txt --file requirements.txt

aws-distclean:
	@rm -rf $(ENVIRONMENT_LOCATION)

aws-info: aws-makefile-check
	$(ECHO) "Makefile     $(AWS_MAKEFILE_VERSION)"

	$(ECHO) "Package"
	$(ECHO) "    name:    $(PACKAGE_NAME)"
	$(ECHO) "    version: $(PACKAGE_VERSION)"
	$(ECHO) ""
	$(ECHO) "AWS"
	$(ECHO) "    Profile: $(CFM_AWS_PROFILE)"
	$(ECHO) "    Account: $(CFM_AWS_ACCOUNT) ($(_AWS_ACCOUNT_ID))"
	$(ECHO) "    Vault:   $(CFM_AWS_VAULT_ID)"
	$(ECHO) "    Region:  $(CFM_AWS_REGION)"
	$(ECHO) ""
	$(ECHO) "DOCKER"
	$(ECHO) "    Image:   $(DOCKER_IMAGE_NAME)"
	$(ECHO) "    Version: $(DOCKER_IMAGE_VERSION)"
	$(ECHO) "    ECR:     $(AWS_ECR_NAME)"
	$(ECHO) ""
	$(ECHO) "APP"
	$(ECHO) "    Source:   $(CFM_APP_SCRIPTS_SOURCE)"
	$(ECHO) "    Dest:     $(CFM_APP_SCRIPTS_DESTINATION)"
	$(ECHO) ""
	$(ECHO) "LAMBDA"
	$(ECHO) "    Source:   $(CFM_LAMBDA_SCRIPTS_SOURCE)"
	$(ECHO) "    Dest:     $(CFM_LAMBDA_SCRIPTS_DESTINATION)"
	$(ECHO) ""

aws-cdk-style: style

aws-connect:
	$(CFM_VAULT) aws dump -s $(CFM_AWS_VAULT_ID) -r $(CFM_AWS_ROLE) -p $(CFM_AWS_PROFILE)

aws-connect-ci:
	$(CFM_VAULT) -a $(CFM_VAULT_APP_NAME) aws dump -s $(CFM_AWS_VAULT_ID) -r $(CFM_AWS_ROLE) -p $(CFM_AWS_PROFILE)

aws-cdk-check-bootstrap:
	CDK_DEFAULT_REGION=$(CFM_AWS_REGION) CDK_DEFAULT_ACCOUNT=$(M_ACCOUNT_ID) \
	$(_CDK_ENV) $(CDK) bootstrap $(CFM_CDK_BOOSTRAP_OPTIONS) \
	    --no-execute $(_AWS_ACCOUNT_ID)/$(CFM_AWS_REGION) --profile $(CFM_AWS_PROFILE)

aws-cdk-bootstrap:
	$(_CDK_ENV) $(CDK) bootstrap $(CFM_CDK_BOOSTRAP_OPTIONS) \
	    $(_AWS_ACCOUNT_ID)/$(CFM_AWS_REGION) --profile $(CFM_AWS_PROFILE)

aws-cdk-diff:
	$(_CDK_ENV) $(CDK) diff --all --profile $(CFM_AWS_PROFILE)

aws-cdk-deploy:
	$(_CDK_ENV) $(CDK) deploy --require-approval never --all --profile $(CFM_AWS_PROFILE)


# --------------------------------------------------
# docker
# --------------------------------------------------
aws-docker-build: M_DOCKER_TAG=$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)
aws-docker-build:
	cd ../docker && chmod +x ./build.sh && ./build.sh $(M_DOCKER_TAG)

aws-docker-push: M_AWS_IMAGE=$(_AWS_ACCOUNT_ID).dkr.ecr.$(CFM_AWS_REGION).amazonaws.com/$(AWS_ECR_NAME):$(DOCKER_IMAGE_NAME)
aws-docker-push: M_AWS_API_ECR_ENDPOINT=https://vpce-0347c5e7821bae25d-4r2qwh6s.api.ecr.eu-west-1.vpce.amazonaws.com
aws-docker-push:
	eval $$($(AWS_NO_PROXY) ecr get-login --region $(CFM_AWS_REGION) --endpoint-url=$(M_AWS_API_ECR_ENDPOINT) --no-include-email --profile $(CFM_AWS_PROFILE)) \
	    && docker tag $(DOCKER_IMAGE_NAME) $(M_AWS_IMAGE) \
	    && docker push $(M_AWS_IMAGE)

# --------------------------------------------------
# deploy LAMBDA
# --------------------------------------------------
aws-lambda-deploy:
	$(ECHO) "not implemented"

# --------------------------------------------------
# deploy APP
# --------------------------------------------------²
%.app.deploy:M_FILE=$(subst .app.deploy,,$(subst $(CFM_APP_SCRIPTS_SOURCE)/,,$@))
%.app.deploy:M_SUB_FOLDER=app
%.app.deploy:
	$(AWS) s3 cp $(CFM_APP_SCRIPTS_SOURCE)/$(M_FILE) $(CFM_APP_SCRIPTS_DESTINATION)/$(M_SUB_FOLDER)/$(M_FILE) --profile $(CFM_AWS_PROFILE)

aws-app-deploy: _SCRIPTS_TO_DEPLOY=$(shell find $(CFM_APP_SCRIPTS_SOURCE) -name *py -type f | grep -v __init__.py)
aws-app-deploy: $(patsubst %,%.app.deploy,$(_SCRIPTS_TO_DEPLOY))

# --------------------------------------------------
# upgrade-me
# --------------------------------------------------

aws-makefile-check:
ifneq ($(AWS_MAKEFILE_VERSION_LAST),)
ifneq ($(AWS_MAKEFILE_VERSION), $(AWS_MAKEFILE_VERSION_LAST))
	$(ECHO)  -e "\033[0;31mMakefile released $(AWS_MAKEFILE_VERSION_LAST)\033[0m (please make aws-upgrade-makefile)";
else
	$(ECHO)  -e "Makefile is up-to-date  $(AWS_MAKEFILE_VERSION_LAST)";
endif
else
	$(ECHO) warning
endif


aws-makefile-upgrade:
	$(MV) Makefile Makefile.sav
	$(WGET) $(AWS_MAKEFILE_URL) --no-check-certificate &> /dev/null
	$(RM) Makefile.sav


-include custom.mk
