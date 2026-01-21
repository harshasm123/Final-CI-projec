import * as cdk from 'aws-cdk-lib';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import { Construct } from 'constructs';

interface AuthStackProps extends cdk.StackProps {
  environment: string;
}

export class AuthStack extends cdk.Stack {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClient: cognito.UserPoolClient;
  public readonly authorizer: apigateway.CognitoUserPoolsAuthorizer;

  constructor(scope: Construct, id: string, props: AuthStackProps) {
    super(scope, id, props);

    const environment = props.environment;

    // ============================================
    // Cognito User Pool
    // ============================================
    this.userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: `ci-platform-${environment}`,
      selfSignUpEnabled: true,
      signInAliases: {
        email: true,
        username: true,
      },
      autoVerify: {
        email: true,
      },
      passwordPolicy: {
        minLength: 12,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ============================================
    // User Pool Client
    // ============================================
    this.userPoolClient = this.userPool.addClient('WebClient', {
      authFlows: {
        userPassword: true,
        userSrp: true,
        custom: true,
      },
      oAuth: {
        flows: {
          authorizationCodeGrant: true,
          implicitCodeGrant: true,
        },
        scopes: [cognito.OAuthScope.OPENID, cognito.OAuthScope.EMAIL, cognito.OAuthScope.PROFILE],
        callbackUrls: [
          'http://localhost:3000/callback',
          'http://localhost:3000',
        ],
        logoutUrls: [
          'http://localhost:3000/logout',
          'http://localhost:3000',
        ],
      },
      preventUserExistenceErrors: true,
    });

    // ============================================
    // User Pool Domain
    // ============================================
    const domain = this.userPool.addDomain('CognitoDomain', {
      cognitoDomain: {
        domainPrefix: `ci-platform-${environment}-${this.account}`,
      },
    });

    // ============================================
    // API Gateway Authorizer
    // ============================================
    this.authorizer = new apigateway.CognitoUserPoolsAuthorizer(this, 'CognitoAuthorizer', {
      cognitoUserPools: [this.userPool],
      identitySource: 'method.request.header.Authorization',
    });

    // ============================================
    // Outputs
    // ============================================
    new cdk.CfnOutput(this, 'UserPoolId', {
      value: this.userPool.userPoolId,
      exportName: `${this.stackName}-UserPoolId`,
    });

    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: this.userPoolClient.userPoolClientId,
      exportName: `${this.stackName}-UserPoolClientId`,
    });

    new cdk.CfnOutput(this, 'CognitoDomain', {
      value: domain.domainName,
      exportName: `${this.stackName}-CognitoDomain`,
    });

    new cdk.CfnOutput(this, 'CognitoLoginURL', {
      value: `https://${domain.domainName}.auth.${this.region}.amazoncognito.com/login?client_id=${this.userPoolClient.userPoolClientId}&response_type=code&redirect_uri=http://localhost:3000/callback`,
      exportName: `${this.stackName}-CognitoLoginURL`,
    });
  }
}
