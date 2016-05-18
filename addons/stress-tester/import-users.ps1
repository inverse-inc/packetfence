Import-Module ActiveDirectory 
$Users = Import-Csv -Delimiter "|" -Path ".\mock_data.csv"  
foreach ($User in $Users)  
{  
    $OU = "OU=PF-LOAD-TESTING,DC=DOMAIN,DC=NET"  
    $Password = $User.password
    $SAM = $User.username
    $DetailedName = $User.username
    New-ADUser -Name $DetailedName -SamAccountName $SAM -UserPrincipalName $SAM -DisplayName $DetailedName -GivenName $DetailedName -Surname $DetailedName -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Enabled $true -Path $OU  
} 
