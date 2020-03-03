# PowerShell script file to be executed as a AWS Lambda function. 
# 
# When executing in Lambda the following variables will be predefined.
#   $LambdaInput - A PSObject that contains the Lambda function input data.
#   $LambdaContext - An Amazon.Lambda.Core.ILambdaContext object that contains information about the currently running Lambda environment.
#
# The last item in the PowerShell pipeline will be returned as the result of the Lambda function.
#
# To include PowerShell modules with your Lambda function, like the AWSPowerShell.NetCore module, add a "#Requires" statement 
# indicating the module and version.

#Requires -Modules @{ModuleName='AWSPowerShell.NetCore';ModuleVersion='3.3.563.1'}

# Uncomment to send the input event to CloudWatch Logs
# Write-Host (ConvertTo-Json -InputObject $LambdaInput -Compress -Depth 5)

#main Function
Function Main{
   
    #We shoudl move the frist three to to environment variables to make this reusable in other envs
    $alarm_prefix= $env:alarm_prefix +"-VPN-Tunnel-Alarm"
    $alarm_desc_prefix = $env:alarm_desc_prefix + " VPN Tunnel:"
    $ifdown_alarm_actions = $env:action_arn 
    $alarm_desc_suffix = $env:alarm_desc_suffix
    $AWSAccount = (Get-STSCallerIdentity).Account
    $AWSAcctAlias = Get-IAMAccountAlias

    $alarm_namespace = 'AWS/VPN'

    $metrics = GetVPNTunnelMetrics
    if ($metrics -eq 1) {
        Write-Host "Error retrieving VPN Tunnel Metrics"
        Exit 1
    }

    $alarms = GetVPNTunnelAlarms $alarm_prefix
    if ($metrics -eq 1) {
        Write-Host "Error retrieving VPN Tunnel Alarms"
        Exit 1
    }

    #Find Metrics without Alarms, Create and alarm for item
    foreach ($metric in $metrics) {
        $alarm = ""
        $alarm= ($alarms|? {($_.Dimensions.Name -eq $metric.Dimensions.Name) -and ($_.Dimensions.Value -eq $metric.Dimensions.Value)})
        if ($alarm -eq $NULL) {

            # Create the missing alarm
            Write-Host "Creating Cloud Watch Alarm for "  $metric.Dimensions.Name " : " $metric.Dimensions.Value
            $retval = CreateAlarm $metric
            if ($reval -eq 1){
                Write-Host "Error Creating Alarm"
            }
            Else {
                Write-Host "Created Alarm $retval"
            }
        } 
        else {
            Write-Host "Found Cloud Watch Alarm:" $alarm.AlarmName". No action taken"
        }
    }

    #Find alarms with missing metrics, and delete them.
    foreach ($alarm in $alarms) {
        
        $metric= ($metrics|? {($_.Dimensions.Name -eq $alarm.Dimensions.Name) -and ($_.Dimensions.Value -eq $alarm.Dimensions.Value)})
        if ($metric -eq $NULL) {

            # delete the alarm
            Write-Host "Deleting Alarm:" $_.AlarmName "as mo matching metric was found"
            RemoveAlarm $_.AlarmName
        } 
        else {
            Write-Host "Found Metric :" $metric.MetricName " for " $metric.Dimensions.Value " matching "$alarm.AlarmName " No action needed"
        }
    }
}

Function GetVPNTunnelMetrics {
    #Function retrieves the VPN Tunnel state metrics.
    try{
        $Filter = [Amazon.CloudWatch.Model.DimensionFilter]::new()
        $Filter.Name = 'VpnId'
        $metrics=Get-CWMetricList -Namespace "AWS/VPN" -MetricName 'TunnelState' -Dimension $Filter
    }
    catch {
        $metrics=1
    }
    return $metrics
}

Function GetVPNTunnelAlarms{
    #Function to return a list of configured alarms based on the name prefix
    #since we create these alarms with the denfined name prefix this works.
    param([string]$prefix)
    try{
        $alarms = get-CWAlarm -AlarmNamePrefix $prefix
    }
    catch{
        $alarms= 1
    }
    return $alarms
}

Function RemoveAlarm{
    #Function to remove a CW Alarm 
    param ([string]$AlarmName)
    try {
        Remove-CWAlarm -AlarmName $AlarmName
        $status = 0
    }
    catch{
        $status = 1
    }
    Return $status
} 

Function CreateAlarm {
    #Function to create a Cloudwatch Alarm
    param([PSObject]$metric)
    $AlarmName = "$alarm_prefix-$AWSAcctAlias-$AWSAccount-" + $metric.Dimensions.Value 
    $AlarmDesc = "$alarm_desc_prefix-$AWSAcctAlias($AWSAccount)-" + $metric.Dimensions.Value + "$alarm_desc_suffix"
    if  ($metric.MetricName -eq 'TunnelState' ){
        #create a new metric alarm
        Write-Host "Creating Alarm for " $metric.MetricName ":" $metric.Dimensions.Value
        
       $a=Write-CWMetricAlarm `
        -AlarmName $AlarmName `
        -AlarmDescription  $AlarmDesc `
        -ActionsEnabled $True `
        -OKAction $ifdown_alarm_actions `
        -AlarmAction $ifdown_alarm_actions `
        -MetricName $metric.MetricName `
        -Namespace $Metric.NameSpace `
        -Dimension $metric.Dimensions `
        -Threshold 1 `
        -Statistic 'Average' `
        -ComparisonOperator 'LessThanThreshold' `
        -TreatMissingData 'missing' `
        -EvaluationPeriod 1 `
        -Period 600 `
        -PassThru

    }
    else{
        #object is not a CW metric for Tunnel State.
        return 1
    }
    Return $a
}

Main