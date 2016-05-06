Import-Module ActiveDirectory 
$Users = Import-Csv -Delimiter "|" -Path ".\mock_data.csv"  
foreach ($User in $Users)  
{  
    $OU = "OU=PF-LOAD-TESTING,DC=DOMAIN,DC=NET"  
    $Password = $User.password 
    $Detailedname = $User.username
    $UserFirstname = $User.username
    $FirstLetterFirstname = $User.username
    $SAM = $User.username 
    New-ADUser -Name $Detailedname -SamAccountName $SAM -UserPrincipalName $SAM -DisplayName $Detailedname -GivenName $user.firstname -Surname $user.name -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Enabled $true -Path $OU  
} 
