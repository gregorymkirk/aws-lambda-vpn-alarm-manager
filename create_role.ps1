
#Creates a ro

$AssumeRolePolicy = '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'

$role= New-IAMRole -RoleName "VPN_Alarm_Mgr_lambda_role" -AssumeRolePolicyDocument $AssumeRolePolicy -Description "Role for VPN Alarm Manager Lambda" `
Register-IAMRolePolicy -RoleName $role.RoleName  -PolicyArn "arn:aws:iam::aws:policy/CloudWatchFullAccess"
Register-IAMRolePolicy -RoleName $role.RoleName -PolicyArn "arn:aws:iam::aws:policy/IAMReadOnlyAccess"

Write-host "Role Name: " $role.RoleName