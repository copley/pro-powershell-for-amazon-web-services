
#This example will generate a PreSigned URL with expiration.

Param
(
    [string][parameter(mandatory=$true)]$AccessKey, 
    [string][parameter(mandatory=$true)]$SecretKey, 
    [string][parameter(mandatory=$false)]$Verb = 'GET',
    [DateTime][parameter(mandatory=$true)]$Expires, 
    [string][parameter(mandatory=$true)]$Bucket,
    [string][parameter(mandatory=$true)]$Key
)

#Calculate the expiration
$EpochTime = [DateTime]::Parse('1970-01-01')
$ExpiresSeconds = ($Expires.ToUniversalTime() - $EpochTime).TotalSeconds

#Canonicalization of the URL
$Path = [Amazon.S3.Util.AmazonS3Util]::UrlEncode("/$Bucket/$Key", $true)
$Data = "$Verb`n`n`n$ExpiresSeconds`n$Path"

#Using the classes directly
$HMAC = New-Object System.Security.Cryptography.HMACSHA1
$HMAC.key = [System.Text.Encoding]::UTF8.GetBytes($SecretKey);
$signature = $HMAC.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Data.ToCharArray()))
$signature_encoded = [Amazon.S3.Util.AmazonS3Util]::UrlEncode([System.Convert]::ToBase64String($signature), $true)

"https://s3.amazonaws.com/$Bucket/$Key" + "?AWSAccessKeyId=$AccessKey&Expires=$ExpiresSeconds&Signature=$signature_encoded"


