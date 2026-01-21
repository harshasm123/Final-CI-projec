import * as cdk from 'aws-cdk-lib';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

interface EventBridgeStackProps extends cdk.StackProps {
  environment: string;
  mainStackName: string;
}

export class EventBridgeStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: EventBridgeStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // EventBridge Rules for Scheduled Tasks
    // ============================================

    // Rule 1: Comprehensive Data Ingestion (Every 6 hours)
    new events.Rule(this, 'ComprehensiveDataIngestionRule', {
      ruleName: `ci-comprehensive-ingestion-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(6)),
      description: 'Trigger comprehensive data ingestion every 6 hours',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'ComprehensiveDataIngestionFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-comprehensivedataingestion-${environment}`
        )
      )
    );

    // Rule 2: Data Quality Checks (Every 4 hours)
    new events.Rule(this, 'DataQualityCheckRule', {
      ruleName: `ci-data-quality-check-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(4)),
      description: 'Trigger data quality checks every 4 hours',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'DataQualityCheckFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-dataqualitycheck-${environment}`
        )
      )
    );

    // Rule 3: AI Insights Generation (Every 8 hours)
    new events.Rule(this, 'AIInsightsRule', {
      ruleName: `ci-ai-insights-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(8)),
      description: 'Trigger AI insights generation every 8 hours',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'AIHandlerFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-aihandler-${environment}`
        )
      )
    );

    // Rule 4: Alert Generation (Every 2 hours)
    new events.Rule(this, 'AlertGenerationRule', {
      ruleName: `ci-alert-generation-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(2)),
      description: 'Trigger alert generation every 2 hours',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'AlertHandlerFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-alerthandler-${environment}`
        )
      )
    );

    // Rule 5: Competitive Analysis (Every 12 hours)
    new events.Rule(this, 'CompetitiveAnalysisRule', {
      ruleName: `ci-competitive-analysis-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(12)),
      description: 'Trigger competitive analysis every 12 hours',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'CompetitiveAnalysisFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-competitiveanalysis-${environment}`
        )
      )
    );

    // Rule 6: Brand Intelligence Aggregation (Every 24 hours)
    new events.Rule(this, 'BrandIntelligenceRule', {
      ruleName: `ci-brand-intelligence-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(24)),
      description: 'Trigger brand intelligence aggregation every 24 hours',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'BrandHandlerFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-brandhandler-${environment}`
        )
      )
    );

    // Rule 7: Dashboard Refresh (Every 1 hour)
    new events.Rule(this, 'DashboardRefreshRule', {
      ruleName: `ci-dashboard-refresh-${environment}`,
      schedule: events.Schedule.rate(cdk.Duration.hours(1)),
      description: 'Trigger dashboard refresh every 1 hour',
    }).addTarget(
      new targets.LambdaFunction(
        lambda.Function.fromFunctionArn(
          this,
          'DashboardHandlerFunction',
          `arn:aws:lambda:${this.region}:${this.account}:function:ci-dashboardhandler-${environment}`
        )
      )
    );

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'EventBridgeRulesCreated', {
      value: '7 EventBridge rules created successfully',
      exportName: `${this.stackName}-EventBridgeRulesCreated`,
    });
  }
}
