#### Project Info ####
PROJECT_NAME ?= data-ms-primebrokerage

#### CDK Package Info ####
PACKAGE_NAME ?= data_ms_primebrokerage
PACKAGE_VERSION ?= N/A

#### Target Environment ####
# Overwritten by Jenkins CI
CFM_AWS_ENVIRONMENT ?= dev

#### Team / Account Info ####
CFM_TEAM = financial
CFM_AWS_REGION = eu-west-1
CFM_AWS_ACCOUNT_PREFIX = data-$(CFM_TEAM)

#### AWS / Vault Info ####
CFM_AWS_ACCOUNT=$(CFM_AWS_ACCOUNT_PREFIX)_$(CFM_AWS_ENVIRONMENT)
CFM_AWS_ROLE=cfm_role_ci
CFM_AWS_VAULT_ID=aws_lz_$(CFM_AWS_ACCOUNT)
CFM_VAULT_APP_NAME=aws-$(CFM_AWS_ACCOUNT_PREFIX)-ci
CFM_AWS_PROFILE=aws_$(CFM_AWS_ACCOUNT)

#### CDK Info ####
# CFM_CDK_BOOSTRAP_OPTIONS := --cloudformation-execution-policies "arn:aws:iam::aws:policy/AdministratorAccess" --trust $(CFM_AWS_ACCOUNT)
CFM_CDK_BOOSTRAP_OPTIONS :=

#### Docker Info ####
AWS_ECR_NAME = $(PROJECT_NAME)

#### Deployment Info ####
CFM_S3_BUCKET_ID := $(PROJECT_NAME)-$(CFM_AWS_ENVIRONMENT)
CFM_S3_SUB_FOLDER:=$(or $(PACKAGE_VERSION),user-$(USER))

CFM_APP_SCRIPTS_SOURCE = ../$(PACKAGE_NAME)/app
CFM_APP_SCRIPTS_DESTINATION = s3://$(CFM_S3_BUCKET_ID)/$(CFM_S3_SUB_FOLDER)
