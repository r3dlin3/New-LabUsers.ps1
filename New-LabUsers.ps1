<#
.SYNOPSIS
New-LabUsers.ps1 - PowerShell script to populate a test lab with user accounts

.DESCRIPTION 
This PowerShell script will populate Active Directory in a test lab environment
with a set of OUs and user accounts based on randomly selected names and values.

.OUTPUTS
Results are output to console as the script is running.

.PARAMETER InputFileName
Use this parameter if you need to specify a different text file name containing
the list of users. A generated list of names is also provided with the script.

.PARAMETER PasswordLength
Use this parameter if you need to specify a different password length. By default
all the user accounts are created with a randomly generated password that is 16
characters long. You can reset the password for any user that you want to log on
with.

.PARAMETER OU
Use this parameter if you want to name the top-level OU something different than
the default name of "CORP".

.EXAMPLE
.\New-LabUsers.ps1
Uses the RandomNameList.txt file to generate the list of user accounts in an OU
called "CORP" in Active Directory.

.EXAMPLE
.\New-LabUsers.ps1 -InputFileName .\MyNames.txt -PasswordLength 8 -OU TestLab
Uses the MyNames.txt file to generate the list of user accounts in an OU
called "TestLab" in Active Directory.

.EXAMPLE
.\New-LabUsers.ps1 -UPNSuffix contoso.com

.NOTES
Script originaly written by: Paul Cunningham (https://github.com/cunninghamp/New-LabUsers.ps1)

Random Password Generator function from Scripting Guys blog post:
http://blogs.technet.com/b/heyscriptingguy/archive/2013/06/03/generating-a-new-password-with-windows-powershell.aspx

Random name list generated from:
http://listofrandomnames.com

License:

The MIT License (MIT)

Copyright (c) 2015 Paul Cunningham

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Change Log
V1.00, 2015-11-22 - Initial version
v1.1, 2017-06-02 - Various changes
#>

[CmdletBinding()]
param (
	
	[Parameter( Mandatory=$false)]
	[string]$InputFileName = "RandomNameList.txt",

    [Parameter( Mandatory=$false)]
    [int]$PasswordLength = 16,

    [Parameter( Mandatory=$false)]
    [string]$DefaultPassword,

    [Parameter( Mandatory=$false)]
    [string]$OU = "CORP",

    [Parameter( Mandatory=$false)]
    [string]$UPNSuffix

	)


#...................................
# Variables
#...................................

$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Top level OU created to hold the users and other objects
# and the list of sub-OUs to create under it
$CompanyOU = $OU
$SubOUs = @(
    "Users",
    "Computers",
    "Groups",
    "Resources",
    "Shared"
    )

#Country and city for the test users
$DefaultCountry = "FR"
$DefaultCity = "Paris"




#List of department names randomly chosen for each user
$Departments = @(
    "Administration",
    "Human Resources",
    "Legal",
    "Finance",
    "Engineering",
    "Sales",
    "Information Technology",
    "Service"
    )

# Password length and character set to use for random password generation
$ascii=$NULL;For ($a=33;$a -le 126;$a++) {$ascii+=,[char][byte]$a }


#...................................
# Functions
#...................................

# Test whether an OU already exists
Function Test-OUPath()
{
    param([string]$path)
    
    $OUExists = [adsi]::Exists("LDAP://$path")
    
    return $OUExists
}

# Random password generator
Function Get-TempPassword() {

    Param(
        [int]$length = $PasswordLength,
        [string[]]$sourcedata
    )

    For ($loop=1; $loop -le $length; $loop++)
    {
        $TempPassword+=($sourcedata | Get-Random)
    }

    return $TempPassword
}

#...................................
# Script
#...................................

if (!(Test-Path $InputFileName))
{
    Write-Warning "The input file name you specified can't be found."
    EXIT
}


# Create the OU structure to hold the test users and other objects

$Forest = Get-ADForest
$Domain = Get-ADDomain


if ([string]::IsNullOrEmpty($UPNSuffix)) {
    $UPNSuffix = $Forest.Name
}

$OUPath = "OU=" + $CompanyOU + "," + $Domain.DistinguishedName

if (!(Test-OUPath $OUPath))
{
    Write-Host "Creating OU: $CompanyOU"

    try
    {
        New-ADOrganizationalUnit -Name $CompanyOU -Path $Domain.DistinguishedName -ErrorAction STOP
    }
    catch
    {
        Write-Warning $_.Exception.Message
    }
}
else
{
    Write-Host "OU $CompanyOU already exists"
}

foreach ($SubOU in $SubOUs)
{
    $OUPath = "OU=$SubOU,OU=$CompanyOU," + $Domain.DistinguishedName
    
    if (!(Test-OUPath $OUPath))
    {
        Write-Host "Creating OU: $SubOU"
        New-ADOrganizationalUnit -Name $SubOU -Path $("OU=" + $CompanyOU + "," + $Domain.DistinguishedName)
    }
    else
    {
        Write-Host "OU $SubOU already exists"
    }
}


# Create the user accounts from the list of names
$ListOfNames = @()
$UsersOU = "OU=Users,OU=$CompanyOU," + $Domain.DistinguishedName

$RawNames = @(Get-Content $InputFileName)

foreach ($RawName in $RawNames)
{

    $FirstName = ($RawName.Trim()).Split(" ")[0]
    $LastName = ($RawName.Trim()).Split(" ")[1]
    $officephone = "555-" + ("{0:D4}" -f (Get-Random -Min 0000 -Maximum 9999))
    $Department = $Departments[(Get-Random -Minimum 0 -Maximum ($($Departments.Count) - 1))]
    if ($DefaultPassword) {
        $passwd = $DefaultPassword
    } else {
        $passwd = Get-TempPassword -length $PasswordLength -sourcedata $ascii
    }

    $Props = [ordered]@{
        "FullName" = $FirstName + " " + $LastName;
        "AccountName" = $FirstName + "." + $LastName;
        "FirstName" = $FirstName;
        "LastName" = $LastName;
        "Department" = $Department
        "OfficePhone" = $officephone
        "Password" = $passwd
        "Country" = $DefaultCountry
        "City" = $DefaultCity
        "UserPrincipalName" = "$FirstName.$LastName@$UPNSuffix" `
    }

    $User = New-Object PSObject -Property $Props

    $ListOfNames += $User

}

[int] $nbUser = 0
foreach ($Name in $ListOfNames)
{
    Write-Host "Creating User: $($Name.FullName)"
    try
    {
        New-ADUser -Name $Name.FullName `
               -GivenName $Name.FirstName `
               -Surname $Name.LastName `
               -SamAccountName $Name.AccountName `
               -UserPrincipalName $Name.UserPrincipalName `
               -Department $Name.Department `
               -Path $UsersOU `
               -Enabled $true `
               -AccountPassword (ConvertTo-SecureString $Name.Password -AsPlainText -Force) `
               -OfficePhone $Name.Officephone `
               -Country $Name.Country `
               -City $Name.$city `
               -ErrorAction STOP
        $nbUser++
    }
    catch
    {
        Write-Warning $_.Exception.Message
    }
}
Write-Host -ForegroundColor green "$nbUser out of $($ListOfNames.Count) users created."

#...................................
# Finished
#...................................

Write-Host -ForegroundColor green "Finished."


