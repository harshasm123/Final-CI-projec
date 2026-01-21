import * as cdk from 'aws-cdk-lib';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

interface FrontendStackProps extends cdk.StackProps {
  environment: string;
}

export class FrontendStack extends cdk.Stack {
  public readonly loadBalancer: elbv2.ApplicationLoadBalancer;
  public readonly ecsCluster: ecs.Cluster;
  public readonly fargateService: ecs.FargateService;

  constructor(scope: Construct, id: string, props: FrontendStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // VPC for ECS Fargate
    // ============================================
    const vpc = new ec2.Vpc(this, 'FrontendVpc', {
      maxAzs: 2,
      cidrMask: 24,
      natGateways: 1,
    });

    // ============================================
    // ECS Cluster
    // ============================================
    this.ecsCluster = new ecs.Cluster(this, 'FrontendCluster', {
      vpc,
      clusterName: `ci-frontend-cluster-${environment}`,
    });

    // ============================================
    // Application Load Balancer
    // ============================================
    this.loadBalancer = new elbv2.ApplicationLoadBalancer(this, 'ALB', {
      vpc,
      internetFacing: true,
      loadBalancerName: `ci-frontend-alb-${environment}`,
    });

    // ============================================
    // ECS Task Definition
    // ============================================
    const taskDefinition = new ecs.FargateTaskDefinition(this, 'TaskDef', {
      memoryLimitMiB: 512,
      cpu: 256,
      family: `ci-frontend-task-${environment}`,
    });

    // Add container
    const container = taskDefinition.addContainer('ReactNginx', {
      image: ecs.ContainerImage.fromRegistry('nginx:latest'),
      logging: ecs.LogDriver.awsLogs({
        streamPrefix: 'ci-frontend',
        logRetention: logs.RetentionDays.ONE_WEEK,
      }),
      portMappings: [
        {
          containerPort: 80,
          protocol: ecs.Protocol.TCP,
        },
      ],
    });

    // ============================================
    // ECS Fargate Service
    // ============================================
    this.fargateService = new ecs.FargateService(this, 'FargateService', {
      cluster: this.ecsCluster,
      taskDefinition,
      desiredCount: 2,
      serviceName: `ci-frontend-service-${environment}`,
      assignPublicIp: false,
    });

    // ============================================
    // Load Balancer Target Group
    // ============================================
    const targetGroup = this.loadBalancer.addTarget('FargateTarget', {
      port: 80,
      targets: [this.fargateService],
      healthCheck: {
        path: '/',
        interval: cdk.Duration.seconds(60),
        timeout: cdk.Duration.seconds(5),
        healthyThresholdCount: 2,
        unhealthyThresholdCount: 3,
      },
    });

    // ============================================
    // ALB Listener
    // ============================================
    this.loadBalancer.addListener('HttpListener', {
      port: 80,
      defaultTargetGroups: [targetGroup],
    });

    // ============================================
    // Auto Scaling
    // ============================================
    const scaling = this.fargateService.autoScaleTaskCount({
      minCapacity: 2,
      maxCapacity: 10,
    });

    scaling.scaleOnCpuUtilization('CpuScaling', {
      targetUtilizationPercent: 70,
    });

    scaling.scaleOnMemoryUtilization('MemoryScaling', {
      targetUtilizationPercent: 80,
    });

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: this.loadBalancer.loadBalancerDnsName,
      exportName: `${this.stackName}-LoadBalancerDNS`,
    });

    new cdk.CfnOutput(this, 'LoadBalancerURL', {
      value: `http://${this.loadBalancer.loadBalancerDnsName}`,
      exportName: `${this.stackName}-LoadBalancerURL`,
    });

    new cdk.CfnOutput(this, 'ECSClusterName', {
      value: this.ecsCluster.clusterName,
      exportName: `${this.stackName}-ECSClusterName`,
    });
  }
}
