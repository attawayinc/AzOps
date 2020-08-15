<#
    .SYNOPSIS
    Pester tests to validate the AzOps Module for "In a Box" deployments.

    .DESCRIPTION
    Pester tests to validate the AzOps Module for "In a Box" deployments.

    These tests validate using the AzOps Module to perform the following deployment scenarios:

     - "In a Box" end-to-end deployment (-Tag "iab")

    Tests have been updated to use Pester version 5.0.x

    .EXAMPLE
    To run "In a Box" tests only:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "iab"

    .EXAMPLE
    To run "In a Box" tests only, and create test results for CI:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "iab" -CI

    .EXAMPLE
    To run "In a Box", create test results for CI, and output detailed logs to host:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "iab" -CI -Output Detailed

    .INPUTS
    None

    .OUTPUTS
    None
#>

Describe "Tenant E2E Deployment (Integration Test)" -Tag "integration", "e2e", "iab" {

    BeforeAll {

        # Import AzOps Module
        Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force
        # Make private functions from AzOps Module available for BeforeAll block
        (Get-ChildItem "./src/private/*.ps1").FullName | Import-Module -Force

        #region setup
        # Task: Initialize environment variables
        $env:AZOPS_STATE = $TestDrive
        $env:AZOPS_INVALIDATE_CACHE = 1
        $env:AZOPS_MAIN_TEMPLATE = ("$PSScriptRoot/../template/template.json")
        $env:AZOPS_STATE_CONFIG = ("$PSScriptRoot/../src/AzOpsStateConfig.json")

        #Use AzOpsReference published in https://github.com/Azure/Enterprise-Scale
        Start-AzOpsNativeExecution {
            git clone 'https://github.com/Azure/Enterprise-Scale'
        } | Out-Host
        $AzOpsReferenceFolder = (Join-Path $pwd -ChildPath 'Enterprise-Scale/azopsreference')
        Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "AzOpsReferenceFolder Path is: $AzOpsReferenceFolder"
        $mySMBtechAzState = '3fc1081d-6105-4e19-b60c-1ec1252cf560 (3fc1081d-6105-4e19-b60c-1ec1252cf560)/mySMBtech (mySMBtech)/.AzState'
        Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "mySMBtechAzState Path is: $mySMBtechAzState"

        # Task: Check if 'mySMBtech' Management Group exists
        Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Removing mySMBtech Management Group"
        if (Get-AzManagementGroup -GroupName 'mySMBtech' -ErrorAction SilentlyContinue) {
            Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Running Remove-AzOpsManagementGroup"
            Remove-AzOpsManagementGroup -GroupName  'mySMBtech'
        }
        Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "mySMBtech Management Group hierarchy removed"
        #endregion

        # Task: Initialize azops/
        Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Running Initialize-AzOpsRepository"
        Initialize-AzOpsRepository -SkipResourceGroup -SkipPolicy

        # Task: Deployment of 10-create-managementgroup.parameters.json
        Get-ChildItem -Path "$PSScriptRoot/../template/10-create-managementgroup.parameters.json" | ForEach-Object {
            $tempFileName = (Join-Path -Path $TestDrive -ChildPath $_.Name)
            Copy-Item -Path $_.FullName  -Destination $TestDrive
            $content = Get-Content -Path $tempFileName | ConvertFrom-Json -Depth 100
            $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            $content | ConvertTo-Json -Depth 100 | Out-File -FilePath $tempFileName

            Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Running New-AzOpsStateDeployment for 10-create-managementgroup.parameters.json"
            New-AzOpsStateDeployment -FileName $tempFileName
        }

        # Task: Deployment of 20-create-child-managementgroup.parameters.json
        Get-ChildItem -Path "$PSScriptRoot/../template/20-create-child-managementgroup.parameters.json" | ForEach-Object {
            $tempFileName = (Join-Path -Path $TestDrive -ChildPath $_.Name)
            Copy-Item -Path $_.FullName  -Destination $TestDrive
            $content = Get-Content -Path $tempFileName | ConvertFrom-Json -Depth 100
            $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            $content | ConvertTo-Json -Depth 100 | Out-File -FilePath $tempFileName

            Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Running New-AzOpsStateDeployment for 20-create-child-managementgroup.parameters.json"
            New-AzOpsStateDeployment -FileName $tempFileName
        }

        # Task: Deployment of 30-create-policydefinition-at-managementgroup.parameters.json
        Get-ChildItem -Path "$PSScriptRoot/../template/30-create-policydefinition-at-managementgroup.parameters.json" | ForEach-Object {
            $tempFileName = (Join-Path -Path $TestDrive -ChildPath $_.Name)
            Copy-Item -Path $_.FullName  -Destination $TestDrive
            $content = Get-Content -Path $tempFileName | ConvertFrom-Json -Depth 100
            $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            $content | ConvertTo-Json -Depth 100 | Out-File -FilePath $tempFileName

            Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Running New-AzOpsStateDeployment for 30-create-policydefinition-at-managementgroup.parameters.json"
            New-AzOpsStateDeployment -FileName $tempFileName
        }

        <# State: Disabling this due to bug where Policy assignment fails for first time.

            Get-ChildItem -Path "$PSScriptRoot/../template/40-create-policyassignment-at-managementgroup.parameters.json" | ForEach-Object {
                $tempFileName = (Join-Path -Path $TestDrive -ChildPath $_.Name)
                Copy-Item -Path $_.FullName  -Destination $TestDrive
                $content = Get-Content -Path $tempFileName | ConvertFrom-Json -Depth 100
                $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
                $content | ConvertTo-Json -Depth 100 | Out-File -FilePath $tempFileName
                New-AzOpsStateDeployment -FileName $tempFileName
            }

            #>

        # Task: Re-initialize azops/
        Initialize-AzOpsRepository -SkipResourceGroup -SkipPolicy
    }

    Context "In-a-Box" {
        # Debug: Get-AzTenantDeployment | Sort-Object -Property Timestamp -Descending | Format-Table
        It "Passes ProvisioningState 10-create-managementgroup" {
            (Get-AzTenantDeployment -Name "10-create-managementgroup").ProvisioningState | Should -Match "Succeeded"
        }
        It "Passes ProvisioningState 20-create-child-managementgroup" {
            (Get-AzTenantDeployment -Name "20-create-child-managementgroup").ProvisioningState | Should -Match "Succeeded"
        }
        It "Passes ProvisioningState 30-create-policydefinition-at-managementgroup" {
            (Get-AzTenantDeployment -Name "30-create-policydefinition-at-managementgroup").ProvisioningState | Should -Match "Succeeded"
        }
        It "Passes Discovery of mySMBtech Management Group" {
            (Get-ChildItem -Directory -Recurse -Path $env:AZOPS_STATE).Name | Should -Contain 'mySMBtech (mySMBtech)'
        }

        It "Passes Policy Definition Test" {
            $mySMBtechAzOpsState = ((Get-ChildItem -Recurse -Directory -path $env:AZOPS_STATE) | Where-Object { $_.Name -eq 'mySMBtech (mySMBtech)' }).FullName
            $AzOpsReferencePolicyCount = (Get-ChildItem "$AzOpsReferenceFolder/$mySMBtechAzState/Microsoft.Authorization_policyDefinitions*.json").count
            foreach ($policyDefinition in (Get-ChildItem "$AzOpsReferenceFolder/$mySMBtechAzState/Microsoft.Authorization_policyDefinitions*.json")) {
                Copy-Item $policyDefinition $mySMBtechAzOpsState -Force
            }
            foreach ($policyDefinition in (Get-ChildItem "$mySMBtechAzOpsState/Microsoft.Authorization_policyDefinitions*.json")) {
                # Write-AzOpsLog -Level Information -Topic "AzOps.IAB.Tests" -Message "Deploying Policy Definition: $policyDefinition"
                $scope = New-AzOpsScope -path $policyDefinition.FullName
                $deploymentName = (Get-Item $policyDefinition).BaseName.replace('.parameters', '').Replace(' ', '_')
                if ($deploymentName.Length -gt 64) {
                    $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                }
                New-AzManagementGroupDeployment -Location $env:AZOPS_DEFAULT_DEPLOYMENT_REGION -TemplateFile $env:AZOPS_MAIN_TEMPLATE -TemplateParameterFile $policyDefinition.FullName -ManagementGroupId $scope.managementGroup -Name $deploymentName -AsJob
            }

            Get-Job | Wait-Job

            # Comment: There is an unexplained delay between successful deployment -> and GET.
            $timeout = New-TimeSpan -Minutes 5
            $stopwatch = [diagnostics.stopwatch]::StartNew()

            $mySMBtechJsonCount = 0
            while ($stopwatch.elapsed -lt $timeout) {

                # Comment: Refresh Policy at mySMBtech scope
                Get-AzOpsResourceDefinitionAtScope -scope (New-AzOpsScope -path $mySMBtechAzOpsState)
                $mySMBtechJson = Get-Content -path (New-AzOpsScope -path $mySMBtechAzOpsState).statepath | ConvertFrom-Json
                $mySMBtechJsonCount = $mySMBtechJson.parameters.input.value.properties.policyDefinitions.Count
                if ($mySMBtechJsonCount -lt $AzOpsReferencePolicyCount) {
                    Start-Sleep -Seconds 30
                }
                else {
                    break
                }
            }

            $mySMBtechJsonCount | Should -Be $AzOpsReferencePolicyCount
        }

        It "Passes PolicySet Definition Test" {
            $mySMBtechAzOpsState = (Get-ChildItem -Recurse -Directory -path $env:AZOPS_STATE | Where-Object { $_.Name -eq 'mySMBtech (mySMBtech)' }).FullName
            $AzOpsReferencePolicySetCount = (Get-ChildItem "$AzOpsReferenceFolder/$mySMBtechAzState/Microsoft.Authorization_policySetDefinitions*.json").count
            foreach ($policySetDefinition in (Get-ChildItem "$AzOpsReferenceFolder/$mySMBtechAzState/Microsoft.Authorization_policySetDefinitions*.json")) {
                Copy-Item $policySetDefinition $mySMBtechAzOpsState -Force
            }
            foreach ($policySetDefinition in (Get-ChildItem "$mySMBtechAzOpsState/Microsoft.Authorization_policySetDefinitions*.json")) {
                # Write-AzOpsLog -Level Verbose -Topic "AzOps.IAB.Tests" -Message "Deploying Policy Definition: $policySetDefinition"

                # Changing the Scope to match mySMBtech
                (Get-Content -path $policySetDefinition -Raw) -replace '/providers/Microsoft.Management/managementGroups/mySMBtech/', '/providers/Microsoft.Management/managementGroups/mySMBtech/' | Set-Content -Path $policySetDefinition
                $scope = New-AzOpsScope -path $policySetDefinition.FullName

                $deploymentName = (Get-Item $policySetDefinition).BaseName.replace('.parameters', '').Replace(' ', '_')
                if ($deploymentName.Length -gt 64) {
                    $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                }
                New-AzManagementGroupDeployment -Location $env:AZOPS_DEFAULT_DEPLOYMENT_REGION `
                    -TemplateFile $env:AZOPS_MAIN_TEMPLATE `
                    -TemplateParameterFile $policySetDefinition.FullName `
                    -ManagementGroupId $scope.managementGroup `
                    -Name $deploymentName -AsJob
            }

            Get-Job | Wait-Job

            # There is an unexplained delay between successful deployment -> and GET.
            $timeout = New-TimeSpan -Minutes 5
            $sw = [diagnostics.stopwatch]::StartNew()
            $mySMBtechJsonSetCount = 0
            while ($sw.elapsed -lt $timeout) {

                # Refresh Policy at mySMBtech scope
                Get-AzOpsResourceDefinitionAtScope -scope (New-AzOpsScope -path $mySMBtechAzOpsState)
                $mySMBtechJson = Get-Content -path (New-AzOpsScope -path $mySMBtechAzOpsState).statepath | ConvertFrom-Json
                $mySMBtechJsonSetCount = $mySMBtechJson.parameters.input.value.properties.policySetDefinitions.Count
                if ($mySMBtechJsonSetCount -lt $AzOpsReferencePolicySetCount) {
                    start-sleep -seconds 30
                }
                else {
                    break
                }
            }
            $mySMBtechJsonSetCount | Should -Be $AzOpsReferencePolicySetCount
        }
    }

    AfterAll {
        # Cleaning up mySMBtech Management Group
        if (Get-AzManagementGroup -GroupName 'mySMBtech' -ErrorAction SilentlyContinue) {
            Write-AzOpsLog -Level Verbose -Topic "AzOps.IAB.Tests" -Message "Cleaning up mySMBtech Management Group"
            Remove-AzOpsManagementGroup -groupName  'mySMBtech'
        }
    }
}
