Creates a Lambda Function that will automatically create and destroy VPN Tunnel Alarms in an AWS Region.  The lambda will create alarms for VPN Tunnel IPs "Tunnel State" metrics that do not have an alarm previously set, and will delete exiting alarms when the metric no longer exists.



** PREREQUSITES
	* You will need to create an IAM role with Full access to Cloudwatch. 
	* You will need to provide the ARN of the SNS topic you want to notify for Alarms,
	  we use the same topic for Breaching and OK notifications.
	* Install PowershellCore on your deployment system: https://github.com/PowerShell/PowerShell
	* Install AWS Tools For Powershell https://aws.amazon.com/powershell/
	* Configure your development enviroment: https://docs.aws.amazon.com/lambda/latest/dg/powershell-devenv.html


** BUILD A ZIP PACKAGE FOR DEPLOYMENT:
	You will need to specify the environment variables in your deployment code:
		'alarm_prefix'='FRBINTERNALAPPS-NP'
		'alarm_desc_prefix'='FRB InternalApps (NonProd)''

New-AWSPowerShellLambdaPackage -ScriptPath .\VPN_alarm_manager.ps1 -OutputPackage .\VPN_alarm_manager.zip 


** PUBLISH THE LAMBDA DIRECTLY (be sure to update environment variables and IAM role as needed )

Publish-AWSPowerShellLambda -Name VPN_Alarm_Manager -ScriptPath VPN_alarm_manager.ps1  -IAMRoleARN 'arn:aws:iam::039197104970:role/Lambda-CloudWatch-FullAccess' -Profile intapps -Region us-east-1 -EnvironmentVariable @{'alarm_prefix'='FRBINTERNALAPPS-NP';'alarm_desc_prefix'='FRB InternalApps (NonProd)';'action_arn'='arn:aws:sns:us-east-1:039197104970:smx-warning-alarm-triggered'}

** Post Deployment Configuration

Configure the Lambda created to run on a fixed schedule (Once an hour is a good option)
