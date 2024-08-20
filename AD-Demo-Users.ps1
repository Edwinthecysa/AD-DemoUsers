Set-StrictMode -Version 2
$DebugPreference = "SilentlyContinue"
Import-Module ActiveDirectory

Push-Location (Split-Path ($MyInvocation.MyCommand.Path))

# Global variables
$ou = "OU=DEDSEC TECH,DC=dedsec,DC=Local"
$initialPassword = "Password1"
$orgShortName = "DS"
$dnsDomain = "DEDSEC.local"
$company = "DEDSEC Tech"

$departments = @(
    @{Name = "Finance & Accounting"; Positions = @("Manager", "Accountant", "Data Entry")},
    @{Name = "Human Resources"; Positions = @("Manager", "Administrator", "Officer", "Coordinator")},
    @{Name = "Sales"; Positions = @("Manager", "Representative", "Consultant")},
    @{Name = "Marketing"; Positions = @("Manager", "Coordinator", "Assistant", "Specialist")},
    @{Name = "Engineering"; Positions = @("Manager", "Engineer", "Scientist")},
    @{Name = "Consulting"; Positions = @("Manager", "Consultant")},
    @{Name = "IT"; Positions = @("Manager", "Engineer", "Technician")},
    @{Name = "Logistics"; Positions = @("Manager", "Engineer")},
    @{Name = "Quality Control"; Positions = @("Manager", "Coordinator", "Clerk")},
    @{Name = "Purchasing"; Positions = @("Manager", "Coordinator", "Clerk", "Purchaser")}
)

$phoneCountryCodes = @{"SA" = "+27"; "GB" = "+44"; "US" = "+1"}
$userCount = 40
$locationCount = 2

# Files
$firstNameFile = "Firstnames.txt"
$lastNameFile = "Lastnames.txt"
$addressFile = "Addresses.txt"
$postalAreaFile = "PostalAreaCode.txt"

# Read input files
$firstNames = Import-Csv $firstNameFile
$lastNames = Import-Csv $lastNameFile
$addresses = Import-Csv $addressFile
$postalAreaCodes = @{}

Import-Csv $postalAreaFile | ForEach-Object {
    $postalAreaCodes[$_.PostalCode] = $_.PhoneAreaCode
}

$securePassword = ConvertTo-SecureString -AsPlainText $initialPassword -Force

# Select unique addresses
$locations = $addresses | Get-Random -Count $locationCount

# Create users
$usersCreated = 0

while ($usersCreated -lt $userCount) {
    $Fname = $firstNames | Get-Random
    $Lname = $lastNames | Get-Random
    $displayName = "$($Fname.FirstName) $($Lname.LastName)"
    
    $location = $locations | Get-Random
if ($postalAreaCodes.ContainsKey($location.PostalCode)) {
    $phoneCode = $phoneCountryCodes[$location.Country]
    $phoneAreaCode = $postalAreaCodes[$location.PostalCode]
    $officePhone = "$phoneCode $($phoneAreaCode.Substring(1)) $((Get-Random -Minimum 100000 -Maximum 1000000))"
} else {
    Write-Warning "No phone area code found for postal code $($location.PostalCode). Using default value."
    $phoneCode = $phoneCountryCodes[$location.Country]
    $officePhone = "$phoneCode 000000 $((Get-Random -Minimum 100000 -Maximum 1000000))"
}
    
    $departmentInfo = $departments | Get-Random
    $department = $departmentInfo.Name
    $title = $departmentInfo.Positions | Get-Random
    
    $employeeNumber = Get-Random -Minimum 100000 -Maximum 1000000
    $sAMAccountName = "$orgShortName$employeeNumber"

    if (-not (Get-ADUser -Filter {SamAccountName -eq $sAMAccountName} -ErrorAction SilentlyContinue)) {
        New-ADUser -SamAccountName $sAMAccountName -Name $displayName -Path $ou -AccountPassword $securePassword -Enabled $true -GivenName $Fname.FirstName -Surname $Lname.LastName -DisplayName $displayName -EmailAddress "$($Fname.FirstName).$($Lname.LastName)@$dnsDomain" -StreetAddress $location.Street -City $location.City -PostalCode $location.PostalCode -State $location.State -Country $location.Country -UserPrincipalName "$sAMAccountName@$dnsDomain" -Company $company -Department $department -EmployeeNumber $employeeNumber -Title $title -OfficePhone $officePhone

        Write-Output "Created user #$($usersCreated + 1): $displayName, $sAMAccountName, $title, $department, $officePhone"
        $usersCreated++
    }
}

Write-Output "Script Complete. Created $usersCreated users."
