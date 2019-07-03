<#
.SYNOPSIS
Create a user using your account.
.PARAMETER Action
Specify how to create the new user:
create - User will get an email sent from Zoom. There is a confirmation link in this email. The user will then need to use the link to activate their Zoom account. 
The user can then set or change their password.
autoCreate - This action is provided for the enterprise customer who has a managed domain. This feature is 
disabled by default because of the security risk involved in creating a user who does not belong to your domain.
custCreate - This action is provided for API partners only. A user created in this way has no password and 
is not able to log into the Zoom web site or client.
ssoCreate - This action is provided for the enabled “Pre-provisioning SSO User” option. A user created in 
this way has no password. If not a basic user, a personal vanity URL using the user name (no domain) of 
the provisioning email will be generated. If the user name or PMI is invalid or occupied, it will use a random 
number or random personal vanity URL.
.PARAMETER Email
User email address.
.PARAMETER Type
Basic (1)
Pro (2)
Corp (3)
.PARAMETER FirstName
User's first namee: cannot contain more than 5 Chinese words.
.PARAMETER LastName
User's last name: cannot contain more than 5 Chinese words.
.PARAMETER PASSWORD
User password. Only used for the "autoCreate" function. The password has to have a minimum of 8 characters and maximum of 32 characters. 
It must have at least one letter (a, b, c..), at least one number (1, 2, 3...) and include both uppercase and lowercase letters. 
It should not contain only one identical character repeatedly ('11111111' or 'aaaaaaaa') and it cannot contain consecutive characters ('12345678' or 'abcdefgh').
.PARAMETER ApiKey
The API key.
.PARAMETER ApiSecret
THe API secret.
.EXAMPLE
New-ZoomUser -Action ssoCreate -Email helpdesk@lawfirm.com -Type Pro -FirstName Joseph -LastName McEvoy -ApiKey $ApiKey -ApiSecret $ApiSecret
.OUTPUTS
The Zoom API response as a hashtable.
#>

$Parent = Split-Path $PSScriptRoot -Parent
import-module "$Parent\ZoomModule.psm1"
. "$Parent\Users\Get-ZoomSpecificUserps1"


function New-ZoomUser {    
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact='Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('create', 'autoCreate', 'custCreate', 'ssoCreate')]
        [string]$Action,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateLength(1, 128)]
        [Alias('EmailAddress')]
        [string]$Email,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Corp', 1, 2, 3)]
        [string]$Type,

        [ValidateLength(1, 64)]
        [string]$FirstName,
        
        [ValidateLength(1, 64)]
        [string]$LastName,

        [string]$Password,
        
        [string]$ApiKey,
        
        [string]$ApiSecret,

        [switch]$PassThru
    )

    begin {
        $Uri = 'https://api.zoom.us/v2/users'
        #Get Zoom Api Credentials
        if (-not $ApiKey -or -not $ApiSecret) {
            $ApiCredentials = Get-ZoomApiCredentials
            $ApiKey = $ApiCredentials.ApiKey
            $ApiSecret = $ApiCredentials.ApiSecret
        }

        #Generate Headers with JWT (JSON Web Token)
        $Headers = New-ZoomHeaders -ApiKey $ApiKey -ApiSecret $ApiSecret
    }

    process {
        #Request Body
        $RequestBody = @{ }
        $RequestBody.Add('action', $Action)

        if ($Type) {
            $Type = switch ($Type) {
                'Basic' { 1 }
                'Pro' { 2 }
                'Corp' { 3 }
                Default { $Type }
            }
        }

        #User Info Object
        $UserInfo = @{
            'email' = $Email
            'type'  = $Type
        }

        $UserInfoKeyValues = @{
            'first_name' = $FirstName
            'last_name'  = $LastName
            'password'   = $Password
        }

        #Adds parameters to UserInfo object if not Null
        $UserInfoKeyValues.Keys | ForEach-Object {
            if (-not [string]::IsNullOrEmpty($UserInfoKeyValues.$_)) {
                $UserInfo.Add($_, $UserInfoKeyValues.$_)
            }
        }

        $RequestBody.add('user_info', $UserInfo)

        if ($pscmdlet.ShouldProcess) {
            try {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Body ($RequestBody | ConvertTo-Json) -Method Post
            }
            catch {
                Write-Error -Message "$($_.exception.message)" -ErrorId $_.exception.code -Category InvalidOperation
            }
            
            Write-Output (Get-ZoomSpecificUser -Email $Email)
        }
    }
}