from pathlib import Path
from typing import List

import aws_cdk.aws_logs_destinations as destinations
from aws_cdk import (
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_lambda as aws_lambda,
    aws_logs as logs,
    Duration,
    RemovalPolicy,
)
from aws_cdk.aws_events import (
    Rule,
    Schedule,
)
from aws_cdk.aws_events_targets import LambdaFunction
from aws_cdk.aws_logs import (
    FilterPattern,
    RetentionDays,
)
from aws_dl_utils.models.cdk_config import CdkAppConfig
from aws_dl_utils.models.cdk_output import (
    BucketOutput,
    KmsKeyOutput,
)
from constructs import Construct


class LambdasComponent(Construct):
    def __init__(
        self,
        scope: Construct,
        id_: str,
        *,
        app_config: CdkAppConfig,
        vpc: ec2.IVpc,
        public_subnets: List[ec2.ISubnet],
        bucket_raw: BucketOutput,
        bucket_gold: BucketOutput,
        kms_key_s3: KmsKeyOutput,
        env: str,
    ) -> None:
        super().__init__(scope, id_)

        lambda_name = app_config.application_name
        lambda_name_weekly = f"{lambda_name}_weekly"

        lambda_handler = "main.lambda_handler"
        lambda_weekly_handler = "main.lambda_handler_weekly"

        log_group = logs.LogGroup(
            scope=self,
            id="log_group",
            log_group_name=f"/aws/lambda/{lambda_name}",
            retention=RetentionDays.ONE_MONTH,
            encryption_key=kms_key_s3.this,
            removal_policy=RemovalPolicy.DESTROY,
        )

        lambda_layer = aws_lambda.LayerVersion(
            scope=self,
            id="lambda_layer",
            layer_version_name=f"{lambda_name}_lambda_layer",
            compatible_runtimes=[aws_lambda.Runtime.PYTHON_3_8],
            code=aws_lambda.Code.from_asset(str(Path(app_config.build_path, "lambda", "output").absolute())),
            compatible_architectures=[aws_lambda.Architecture.ARM_64, aws_lambda.Architecture.X86_64],
            removal_policy=RemovalPolicy.DESTROY,
        )

        # https://aws-sdk-pandas.readthedocs.io/en/3.0.0/layers.html
        aws_data_wrangeler_layer = aws_lambda.LayerVersion.from_layer_version_arn(
            self,
            "aws-data-wrangeler-layer",
            f"arn:aws:lambda:{scope.region}:336392948345:layer:AWSSDKPandas-Python38-Arm64:7",
        )

        lambda_statements = [
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "kms:Decrypt",
                    "kms:Encrypt",
                    "kms:DescribeKey",
                    "kms:ReEncrypt*",
                    "kms:GenerateDataKey*",
                ],
                resources=[kms_key_s3.arn],
            ),
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                ],
                resources=[log_group.log_group_arn],
            ),
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=["s3:ListBucket"],
                resources=[bucket_raw.arn, bucket_gold.arn],
            ),
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "s3:GetObject",
                    "s3:GetObjectAcl",
                    "s3:PutObject",
                    "s3:PutObjectAcl",
                    "s3:DeleteObject",
                ],
                resources=[bucket_raw.this.arn_for_objects("*"), bucket_gold.this.arn_for_objects("*")],
            ),
        ]

        lambda_runtime_role = iam.Role(
            scope=self,
            id="lambda_runtime_role",
            role_name=f"CFM_Role_{lambda_name}_lambda_runtime_role",
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),
            inline_policies={"lambda": iam.PolicyDocument(statements=lambda_statements)},
        )

        lambda_runtime_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaVPCAccessExecutionRole")
        )

        # To be restricted.
        lambdas_security_group = ec2.SecurityGroup(
            scope=self,
            id="lambda_security_group",
            security_group_name=f"{app_config.application_name}-lambda",
            description="Access of S3 from MS Primebrokerage Lambda",
            vpc=vpc,
            allow_all_outbound=True,
        )
        public_subnets_selection = ec2.SubnetSelection(subnets=public_subnets)

        self.app_on_event = aws_lambda.Function(
            scope=self,
            id="lambda",  # to change -> destroy and recreate the lambda.
            function_name=lambda_name,
            runtime=aws_lambda.Runtime.PYTHON_3_8,
            code=aws_lambda.Code.from_asset(str(Path(app_config.src_path, "lambda").absolute())),
            handler=lambda_handler,
            timeout=Duration.minutes(5),
            memory_size=512,
            architecture=aws_lambda.Architecture.ARM_64,
            role=lambda_runtime_role,
            layers=[lambda_layer, aws_data_wrangeler_layer],
            vpc=vpc,
            vpc_subnets=public_subnets_selection,
            environment={"APP_PACKAGE": app_config.app_package_name, "ENV": env},
            security_groups=[lambdas_security_group],
        )

        self.app_weekly = aws_lambda.Function(
            scope=self,
            id="LambdaWeekly",
            function_name=lambda_name_weekly,
            runtime=aws_lambda.Runtime.PYTHON_3_8,
            code=aws_lambda.Code.from_asset(str(Path(app_config.src_path, "lambda").absolute())),
            handler=lambda_weekly_handler,
            timeout=Duration.minutes(5),
            memory_size=512,
            architecture=aws_lambda.Architecture.ARM_64,
            role=lambda_runtime_role,
            layers=[lambda_layer, aws_data_wrangeler_layer],
            vpc=vpc,
            vpc_subnets=public_subnets_selection,
            environment={"APP_PACKAGE": app_config.app_package_name, "ENV": env},
            security_groups=[lambdas_security_group],
        )

        rule = Rule(
            self,
            "PbCompactionRuleWeekly",
            rule_name="pb_weekly_compaction",
            schedule=Schedule.cron(minute="0", hour="10", month="*", week_day="SAT"),
        )

        # Add the Lambda function as a target for the rule
        rule.add_target(LambdaFunction(self.app_weekly))

        # TODO : use Alerting stack outputs
        alerting_lambda_name = "cfm_logs_lambda_function"

        func = aws_lambda.Function.from_function_name(
            self,
            id="AlertingLambdaFunction",
            function_name=alerting_lambda_name,
        )
        # Alerting CFM integration :
        logs.SubscriptionFilter(
            self,
            id="SubscriptionFilterToCFMAlerting",
            destination=destinations.LambdaDestination(func, add_permissions=False),
            filter_pattern=FilterPattern.any_term("ERROR", "Error", "error"),
            log_group=log_group,
        )
