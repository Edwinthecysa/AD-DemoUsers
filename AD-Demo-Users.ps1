Set-StrictMode -Version 2
$DebugPreference = "SilentlyContinue"
Import-Module ActiveDirectory

# Set the working directory to the script's directory
Push-Location (Split-Path ($MyInvocation.MyCommand.Path))

# Global variables
$ou = "OU=Homelab Tech,DC=homelab,DC=Local"
$initialPassword = "Password123"
$orgShortName = "HL"
$dnsDomain = "HOMELAB.local"
$company = "HOMELAB Tech"
$departments = @(
    @{Name="Finance"; Positions=("Chief Financial Officer","Finance Manager","Financial Analyst","Accountant")},
    @{Name="Human Resources"; Positions=("HR Director","HR Manager","HR Specialist","Recruiter")},
    @{Name="Sales"; Positions=("Sales Director","Sales Manager","Account Executive","Sales Representative")},
    @{Name="Marketing"; Positions=("Chief Marketing Officer","Marketing Manager","Brand Manager","Marketing Specialist")},
    @{Name="Legal"; Positions=("General Counsel","Legal Manager","Legal Advisor","Paralegal")},
    @{Name="Operations"; Positions=("Chief Operating Officer","Operations Manager","Process Improvement Specialist","Operations Analyst")},
    @{Name="IT"; Positions=("Chief Information Officer","IT Manager","Systems Administrator","Network Engineer")},
    @{Name="Customer Service"; Positions=("Customer Service Director","Customer Service Manager","Customer Support Specialist","Helpdesk Technician")},
    @{Name="Product Development"; Positions=("Chief Product Officer","Product Manager","Product Designer","Product Analyst")},
    @{Name="Corporate Strategy"; Positions=("Chief Strategy Officer","Strategy Manager","Business Analyst","Strategic Planner")}
)
$phoneCountryCodes = @{
    "SA" = "+27"; 
    "GB" = "+44"; 
    "US" = "+1"
}

# Parameters
$userCount = 1000
$locationCount = 2

# Files used
$firstNameFile = "Firstnames.txt"
$lastNameFile = "Lastnames.txt"
$addressFile = "Addresses.txt"
$postalAreaFile = "PostalAreaCode.txt"

# Validate locationCount
if ($locationCount -ge $phoneCountryCodes.Count) {
    Write-Error "ERROR: selected locationCount is higher than configured phoneCountryCodes. Maximum locationCount should be $($phoneCountryCodes.Count - 1)."
    Exit
}

# Read input files
$firstNames = Import-CSV $firstNameFile -Encoding utf7
$lastNames = Import-CSV $lastNameFile -Encoding utf7
$addresses = Import-CSV $addressFile -Encoding utf7
$postalAreaCodesTemp = Import-CSV $postalAreaFile

# Convert postal & phone area code object list into a hash
$postalAreaCodes = @{}
foreach ($row in $postalAreaCodesTemp) {
    $postalAreaCodes[$row.PostalCode] = $row.PhoneAreaCode
}

$securePassword = ConvertTo-SecureString -AsPlainText $initialPassword -Force

# Select locations
$locations = @()
$addressIndexesUsed = @()
while ($locations.Count -lt $locationCount) {
    $addressIndex = Get-Random -Minimum 0 -Maximum $addresses.Count
    if ($addressIndexesUsed -notcontains $addressIndex) {
        $locations += $addresses[$addressIndex]
        $addressIndexesUsed += $addressIndex
    }
}

# Create users
for ($i = 1; $i -le $userCount; $i++) {
    $Fname = ($firstNames | Get-Random).FirstName
    $Lname = ($lastNames | Get-Random).LastName
    $displayName = (Get-Culture).TextInfo.ToTitleCase("$Fname $Lname")

    $location = $locations | Get-Random
    $matchcc = $phoneCountryCodes[$location.Country]
    if (-not $matchcc) {
        Write-Debug "ERROR: No country code found for $($location.Country)"
        continue
    }
    $officePhone = "$matchcc $($postalAreaCodes[$location.PostalCode].Substring(1)) $(Get-Random -Minimum 100000 -Maximum 1000000)"
    
    $department = $departments | Get-Random
    $title = $department.Positions | Get-Random
    
    $employeeNumber = Get-Random -Minimum 100000 -Maximum 999999
    $sAMAccountName = "$orgShortName$employeeNumber"
    if (Get-ADUser -LDAPFilter "(sAMAccountName=$sAMAccountName)") {
        Write-Debug "ERROR: sAMAccountName $sAMAccountName already exists, skipping."
        $i--
        continue
    }

    # Create the user account
    New-ADUser -SamAccountName $sAMAccountName -Name $displayName -Path $ou `
        -AccountPassword $securePassword -Enabled $true `
        -GivenName $Fname -Surname $Lname -DisplayName $displayName `
        -EmailAddress "$Fname.$Lname@$dnsDomain" `
        -StreetAddress $location.Street -City $location.City `
        -PostalCode $location.PostalCode -State $location.State `
        -Country $location.Country -UserPrincipalName "$sAMAccountName@$dnsDomain" `
        -Company $company -Department $department.Name -EmployeeNumber $employeeNumber `
        -Title $title -OfficePhone $officePhone

    Write-Output "Created user #$i: $displayName, $sAMAccountName, $title, $department.Name, $officePhone, $location.Country, $location.Street, $location.City"
}

Write-Output "Script Complete. Exiting"
