SHELL         := /usr/bin/bash
.ONESHELL:

e4434b19ac2c_THIS_PATH                                 := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
e4434b19ac2c_THIS_FILE_NAME                            := $(shell basename $(e4434b19ac2c_THIS_PATH))
e4434b19ac2c_THIS_DIR_PATH                             := $(shell dirname $(e4434b19ac2c_THIS_PATH))
e4434b19ac2c_THIS_PROJECT_PATH                         := $(shell PROJECT_PATH=.;until [[ `ls -d -1 */ | grep -c ^cdk/$$` == 1 ]] || [[ "`pwd`" == '/' ]]; do PROJECT_PATH=../$${PROJECT_PATH}; cd ..; done; echo $${PROJECT_PATH})


define print_action
	@$(call print_header)
	printf "\033[36m%s\033[0m\n" $1
endef

define print_error
	printf "\033[0;31m%s\033[0m\n" $1
endef

SRC_DIR                                                := $(abspath $(e4434b19ac2c_THIS_PROJECT_PATH))
CDK_DIR                                                := $(abspath $(e4434b19ac2c_THIS_DIR_PATH))

BUILD_DIR                                              := $(CDK_DIR)/build

PIP := $(ENVIRONMENT_LOCATION)/bin/pip
NPM := $(ENVIRONMENT_LOCATION)/bin/npm
ISORT := $(ENVIRONMENT_LOCATION)/bin/isort
BLACK := $(ENVIRONMENT_LOCATION)/bin/black
FLAKE8 := $(ENVIRONMENT_LOCATION)/bin/flake8
PYTEST := $(ENVIRONMENT_LOCATION)/bin/pytest

ISORT_OPTIONS=--recursive --quiet --settings-path .isort.cfg
PYPROJECT_FILE=pyproject.toml

SRC_MODULES=src
TESTS_MODULES=tests
FLAKE8_MODULES=$(SRC_MODULES) $(TESTS_MODULES)

isort/format:
	@$(call print_action,"isort format on '$(FLAKE8_MODULES)'")
	@$(ISORT) --apply $(ISORT_OPTIONS) $(FLAKE8_MODULES)

isort/check:
	@$(call print_action,"isort execution on '$(FLAKE8_MODULES)'")
	@$(ISORT) --check-only $(ISORT_OPTIONS) $(FLAKE8_MODULES) || ($(call print_error,"ISORT errors detected!"); exit 1)

black/format:
	@$(call print_action,"black format on '$(FLAKE8_MODULES)'")
	@$(BLACK) --config $(PYPROJECT_FILE) $(FLAKE8_MODULES)

black/check:
	@$(call print_action,"black execution on '$(FLAKE8_MODULES)'")
	@$(BLACK) --check --config $(PYPROJECT_FILE) $(FLAKE8_MODULES) || ($(call print_error,"BLACK errors detected!"); exit 1)

pep8/check:
	@$(call print_action,"pep8 execution on '$(FLAKE8_MODULES)'")
	$(FLAKE8) --config $(PYPROJECT_FILE) $(FLAKE8_MODULES)

tests/clean:
	@$(call print_action,"cleaning test artefacts")
	@rm -rf .cache .pytest_cache .sonar build/report build/coverage

style: isort/check black/check pep8/check

format: isort/format black/format style

coverage: tests/clean
	@export PATH=${ENVIRONMENT_LOCATION}/bin:${PATH}
	@$(PYTEST) -c $(PYPROJECT_FILE) $(TESTS_MODULES)

tests: coverage

app/clean:
	@rm -rf $(BUILD_DIR)

app/package/%:
	@echo "Install PIP requirements in $(LIBS_DIR)"
	@mkdir -p $(PKG_BUILD_DIR) $(LIBS_DIR)
	@cd $(PKG_BUILD_DIR)
	@cat $(SRC_DIR)/requirements.txt | sed -n -e '/^[[:space:]]*$$/d' \
                                              -e '/^### <!-- BEGIN $(DEPENDENCIES_TYPE)_DEPENDENCIES --!> ###$$/,/^### <!-- END $(DEPENDENCIES_TYPE)_DEPENDENCIES --!> ###$$/p' \
                                              -e '/^### <!-- BEGIN .* --!> ###$$/,/^### <!-- END .* --!> ###$$/d' \
                                              -e 'p' > requirements.txt
	@$(PIP) install -r requirements.txt --target $(LIBS_DIR)
	@cp -R $(SRC_DIR)/$(PACKAGE_NAME) $(LIBS_DIR)/

app/lambda: PKG_BUILD_DIR=$(BUILD_DIR)/lambda
app/lambda: OUTPUT_DIR=$(PKG_BUILD_DIR)/output
app/lambda: LIBS_DIR=$(OUTPUT_DIR)/python/lib/python3.8/site-packages
app/lambda: DEPENDENCIES_TYPE=LAMBDA
app/lambda: app/package/lambda
	@echo "Packaging Lambdas done"

app/spark: PKG_BUILD_DIR=$(BUILD_DIR)/spark
app/spark: OUTPUT_DIR=$(PKG_BUILD_DIR)/output
app/spark: LIBS_DIR=$(PKG_BUILD_DIR)/libs
app/spark: DEPENDENCIES_TYPE=SPARK
app/spark: app/package/spark
	@mkdir -p $(OUTPUT_DIR)
	@cp $(CDK_DIR)/src/spark/main.py $(OUTPUT_DIR)/
	@cd $(LIBS_DIR)
	@zip -r9 $(OUTPUT_DIR)/libs.zip . -x "*__pycache__*" -x "pyspark*" -x "bin*" -x "*.dist-info*"
	@echo "Packaging Spark done"

app/update_env: PIP_REQ_PATH=$(e4434b19ac2c_THIS_DIR_PATH)/dev-requirements.txt
app/update_env:
	@echo "Update environment aws / cdk with '$(PIP_REQ_PATH)'"
	@export PATH=${ENVIRONMENT_LOCATION}/bin:${PATH}
	@$(PIP) install -r $(PIP_REQ_PATH)
	@AWS_CDK_VERSION=$$(awk '/aws-cdk-lib/{gsub(/aws-cdk-lib==/, ""); print}' $(PIP_REQ_PATH))
	@$(NPM) install --global --force aws-cdk@$${AWS_CDK_VERSION}
	@$(AWS) --version
	@$(CDK) --version

s3/sync_bucket: S3_VPC_ENDPOINT=https://bucket.vpce-019e43681c320618e-qdtbqsna.s3.eu-west-1.vpce.amazonaws.com
s3/sync_bucket:
	@echo "Sync $(S3_SRC_BUCKET) to $(S3_DST_BUCKET) for key $(S3_KEY)"
	@aws s3 sync --delete "s3://$(S3_SRC_BUCKET)/$(S3_KEY)" "s3://$(S3_DST_BUCKET)/$(S3_KEY)" --endpoint-url $(S3_VPC_ENDPOINT)
