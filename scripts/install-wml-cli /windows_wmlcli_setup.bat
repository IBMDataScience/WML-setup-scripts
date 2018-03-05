@echo off
setlocal EnableDelayedExpansion

REM ///////////////////////////////CHECKING PRE-REQUISITES//////////////////////////////////
echo ###################################################
echo  Setting up enviroment for Watson Machine Learning 
echo ###################################################
echo Checking pre-requisites ...
echo.

echo ###################################################
echo  Setting up IBM Cloud CLI - Phase 1 
echo ###################################################
echo.
WHERE bx >nul 2>nul
IF !ERRORLEVEL! NEQ 0 (
ECHO bx is not installed. Installing Bluemix CLI ...
ECHO.
powershell.exe -command "iex (New-Object Net.WebClient).DownloadString('https://clis.ng.bluemix.net/install/powershell')"

)ELSE (   
REM ////////////////////////////////LOGGING INTO BLUEMIX////////////////////////////////////
echo #################################################################
echo  Login to IBM Cloud, Use IBM id to login when prompted - Phase 2
echo #################################################################
ECHO.
bx login -a https://api.ng.bluemix.net
if !ERRORLEVEL! NEQ 0 (
  echo Bluemix login failed. Please try again.
  echo.
  exit /b 5
)
bx target --cf
set LF=^


REM The two empty lines are required here
ECHO.
set "cos="
for /F "delims=" %%f in ('bx resource groups') do (
    if defined cos set "cos=!cos!!LF!"
    set "cos=!cos!%%f"
)
set check_cos=!cos:No resource group found=!
if NOT "!check_cos!" == "!cos!" (
  echo No resource group found.
  echo.
  exit /b 5
)

echo #####################################################
echo  Setting up Watson Machine Learning Plugin - Phase 3
echo #####################################################
echo.

bx plugin install machine-learning -r Bluemix
echo.

REM ///////////////////////////////FETCHING COS INSTANCES/ CREATING NEW INSTANCE///////////

echo #################################################
echo  Setting up IBM Cloud Storage Instance - Phase 4
echo #################################################
echo.

set LF=^


REM The two empty lines are required here
ECHO Fetching the list of Object-Storage Instances...
ECHO.
set "cos="
for /F "delims=" %%f in ('bx resource service-instances --long ^| findstr "cloud-object-storage"') do (
    if defined cos set "cos=!cos!!LF!"
    set "cos=!cos!%%f"
)
IF "!cos!" == "" (
echo No Cloud Object Instances are found. Creating one ...
ECHO.
bx resource service-instance-create COS_CLI cloud-object-storage lite global
ECHO.
bx resource service-instance COS_CLI
ECHO.
ECHO Creating key cli_key_COS_CLI
ECHO.
bx resource service-key-create "cli_key_COS_CLI" Writer --instance-name "COS_CLI" --parameters {\"HMAC\":true} >nul 2>nul
ECHO.
set coskey="cli_key_COS_CLI"  
for /F "delims=" %%f in ('bx resource service-key !coskey! ^| findstr /C:"access_key_id"') do set access_key=%%f 
for /F "delims=" %%f in ('bx resource service-key !coskey! ^| findstr /C:"secret_access_key"') do set secret_key=%%f
set access_key=!access_key: =!
set access_key=!access_key::= - !
set secret_key=!secret_key: =!
set secret_key=!secret_key::= - !
ECHO Retreiving the access_key_id and secret_access_key...
ECHO.
echo !access_key!
echo !secret_key!
ECHO.
)ELSE (
ECHO Found existing object-Storage Instances...
ECHO.
set i=0
for /f "tokens=*" %%p in ("!cos!") do (
set "string=%%p"
set "string=!string:*  =!"
for /f "tokens=*" %%a in ("!string!") do set "string=%%a"
REM remove third and next tokens (delimited by two or more spaces)
set string="!string:  =&!"
for /f "tokens=1 delims=&" %%p in (!string!) do (
set "string=%%p"
set /a i+=1
set cos_instances[!i!]=!string!
)
)
set n=!i!
for /L %%j in (1,1,!n!) do echo %%j - !cos_instances[%%j]!
:loop
set /p inp="Please enter your choice number in [1...!n!] "
IF !inp! gtr !n! (goto loop)
IF !inp! lss 1 (goto loop)

for /L %%j in (1,1,!n!) do (
IF %%j==!inp! (
set instance_name=!cos_instances[%%j]!
goto continue
)
)
:continue
bx resource service-instance "!instance_name!"
bx resource service-keys --instance-name "!instance_name!"
ECHO.
set LF=^


REM The two empty lines are required here
set "output="
for /F "delims=" %%f in ('bx resource service-keys --instance-name "!instance_name!"') do (
    if defined output set "output=!output!!LF!"
    set "output=!output!%%f"
)
set keyname=cli_key_!instance_name!
set test=!output:%keyname%=!
if "!test!"=="!output!" (
ECHO Creating service key !keyname!...
ECHO.
bx resource service-key-create "!keyname!" Writer --instance-name "!instance_name!" --parameters {\"HMAC\":true} >nul 2>nul
ECHO.
for /F "delims=" %%f in ('bx resource service-key "!keyname!" ^| findstr /C:"access_key_id"') do set access_key=%%f 
for /F "delims=" %%f in ('bx resource service-key "!keyname!" ^| findstr /C:"secret_access_key"') do set secret_key=%%f
set access_key=!access_key: =!
set access_key=!access_key::= - !
set secret_key=!secret_key: =!
set secret_key=!secret_key::= - !
ECHO Retreiving the access_key_id and secret_access_key...
ECHO.
echo !access_key!
echo !secret_key!
ECHO Use the above credentials to configure aws later...
ECHO.
) else (
for /F "delims=" %%f in ('bx resource service-key "!keyname!" ^| findstr /C:"access_key_id"') do set access_key=%%f 
for /F "delims=" %%f in ('bx resource service-key "!keyname!" ^| findstr /C:"secret_access_key"') do set secret_key=%%f
set access_key=!access_key: =!
set access_key=!access_key::= - !
set secret_key=!secret_key: =!
set secret_key=!secret_key::= - !
ECHO Retreiving the access_key_id and secret_access_key...
ECHO.
echo !access_key!
echo !secret_key!
ECHO Use the above credentials to configure aws later...
ECHO.
)
)
)
ECHO.
ECHO.
REM ///////////////////////////FETCHING WML INSTANCES/ CREATING NEW INSTANCE///////////////
echo #######################################################
echo  Setting up Watson Machine Learning Instance - Phase 5
echo #######################################################
echo.

set LF=^


REM The two empty lines are required here
ECHO Fetching the list of WML Instances...
ECHO.
set "wml="
for /F "delims=" %%f in ('bx service list ^| findstr "pm-20"') do (
    if defined wml set "wml=!wml!!LF!"
    set "wml=!wml!%%f"
)
IF "!wml!" == "" (
echo No WML Instances are found. Creating one ...
ECHO.
bx service create pm-20 lite CLI_WML_Instance
bx service key-create CLI_WML_Instance cli_key_CLI_WML_Instance
for /F "tokens=2 delims=:" %%f in ('bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance ^| findstr /C:"instance_id"') do set instance_id=%%f
for /F delims^=^"^ tokens^=2 %%f in ("!instance_id!") do set instance_id=%%f

for /F delims^=^"^ tokens^=4 %%f in ('bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance ^| findstr /C:"url"') do set url=%%f

for /F "tokens=2 delims=:" %%f in ('bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance ^| findstr /C:"username"') do set username=%%f
for /F delims^=^"^ tokens^=2 %%f in ("!username!") do set username=%%f

for /F delims^=^"^ tokens^=4 %%f in ('bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance ^| findstr /C:"password"') do set password=%%f

echo.
echo instance_id - !instance_id!
echo username    - !username!
echo password    - !password!
echo url         - !url!

echo.
echo Use these details to configure the environment variables ML_INSTANCE, ML_USERNAME, ML_PASSWORD, ML_ENV
echo.
echo  set ML_INSTANCE=!instance_id!  
echo  set ML_USERNAME=!username!  
echo  set ML_PASSWORD=!password!

   
echo  set ML_ENV=!url!   
ECHO.
)ELSE (
ECHO Found existing WML Instances...
ECHO.
set i=0
for /f "tokens=*" %%p in ("!wml!") do (
set "string=%%p"

REM remove third and next tokens (delimited by two or more spaces)
set string="!string:  =&!"
for /f "tokens=1 delims=&" %%p in (!string!) do (
set "string=%%p"
set /a i+=1

set wml_instances[!i!]=!string!

)
)

set n=!i!
for /L %%j in (1,1,!n!) do echo %%j - !wml_instances[%%j]!
:loopwml
set /p inp="Please enter your choice number in [1...!n!]: "
IF !inp! gtr !n! (goto loopwml)
IF !inp! lss 1 (goto loopwml)

for /L %%j in (1,1,!n!) do (
IF %%j==!inp! (
set wmlinstance_name=!wml_instances[%%j]!
goto continuewml
)
)
:continuewml
set LF=^


REM The two empty lines are required here
set "output="
for /F "delims=" %%f in ('bx service keys "!wmlinstance_name!"') do (
    if defined output set "output=!output!!LF!"
    set "output=!output!%%f"
)
set keynamewml=cli_key_!wmlinstance_name!

set testwml=!output:%keynamewml%=!
if "!testwml!"=="!output!" (
bx service key-create "!wmlinstance_name!" "!keynamewml!"


for /F "tokens=2 delims=:" %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"instance_id"') do set instance_id=%%f
for /F delims^=^"^ tokens^=2 %%f in ("!instance_id!") do set instance_id=%%f

for /F delims^=^"^ tokens^=4 %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"url"') do set url=%%f

for /F "tokens=2 delims=:" %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"username"') do set username=%%f
for /F delims^=^"^ tokens^=2 %%f in ("!username!") do set username=%%f

for /F delims^=^"^ tokens^=4 %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"password"') do set password=%%f

echo.
echo instance_id - !instance_id!
echo username    - !username!
echo password    - !password!
echo url         - !url!
echo.

echo Use these details to configure the environment variables ML_INSTANCE, ML_USERNAME, ML_PASSWORD, ML_ENV
echo.
echo  set ML_INSTANCE=!instance_id!  
echo  set ML_USERNAME=!username!  
echo  set ML_PASSWORD=!password!

   
echo  set ML_ENV=!url!   
ECHO.

) else (
for /F "tokens=2 delims=:" %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"instance_id"') do set instance_id=%%f
for /F delims^=^"^ tokens^=2 %%f in ("!instance_id!") do set instance_id=%%f

for /F delims^=^"^ tokens^=4 %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"url"') do set url=%%f

for /F "tokens=2 delims=:" %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"username"') do set username=%%f
for /F delims^=^"^ tokens^=2 %%f in ("!username!") do set username=%%f

for /F delims^=^"^ tokens^=4 %%f in ('bx service key-show "!wmlinstance_name!" "!keynamewml!" ^| findstr /C:"password"') do set password=%%f

echo.
echo instance_id - !instance_id!
echo username    - !username!
echo password    - !password!
echo url         - !url!
echo.

echo Use these details to configure the environment variables ML_INSTANCE, ML_USERNAME, ML_PASSWORD, ML_ENV
echo.
echo  set ML_INSTANCE=!instance_id!  
echo  set ML_USERNAME=!username!  
echo  set ML_PASSWORD=!password!

   
echo  set ML_ENV=!url!   
ECHO.

)

)
)


echo ##########################################################
echo   Setting up awscli... Phase 6
echo ##########################################################
echo.
set config=0
set choice=0

REM ////////////////////////////////PYTHON CHECK//////////////////////////////////////////
echo Checking if python is installed...
set LF=^


REM The two empty lines are required here
set "pip_path="
for /F "delims=" %%f in ('py -m site --user-base 2^>^&1') do (
    if defined pip_path set "pip_path=!pip_path!!LF!"
    set "pip_path=!pip_path!%%f"
)

set test_pip=!pip_path:not recognized=!
if "!test_pip!" == "!pip_path!" (
set LF=^


REM The two empty lines are required here
set "pip_path="
for /F "delims=" %%f in ('python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())" 2^>^&1') do (
    if defined pip_path set "pip_path=!pip_path!!LF!"
    set "pip_path=!pip_path!%%f"
)
set test_pip=!pip_path:\Lib\site-packages=!
setx PATH "%PATH%;!test_pip!\Scripts\"
) else (
  echo.
  echo Please install python on your machine.
  echo.
  echo Setting up awscli - Phase 6 failed.
  echo.
  exit \b 5



)


REM ////////////////////////////PIP/AWSCLI CHECK //////////////////////////////////////////
echo Checking if pip is installed...
echo.

WHERE pip >nul 2>nul


IF !ERRORLEVEL! NEQ 0 (


ECHO pip is not installed. Please install pip on your machine.


ECHO.


echo Setting up awscli - Phase 6 failed.
echo.
exit \b 5


) else (
ECHO Checking if aws is installed...


ECHO.


WHERE aws >nul 2>nul


IF !ERRORLEVEL! NEQ 0 (


ECHO aws is not installed. Installing awscli...


ECHO.


pip install awscli


WHERE aws >nul 2>nul


IF !ERRORLEVEL! NEQ 0 (


ECHO Modify the path variable to include AWS path.


ECHO.


echo Setting up awscli - Phase 6 failed.
echo.
) ELSE (


set config=1
)

) ELSE (


set config=1
)

REM ////////////////// AWS CONFIGURE /////////////////////////////////
if !config! == 1 (

echo Please configure AWSCLI with the access_key_id and secret_access_key as displayed in Phase 4
echo Configuring awscli...
   
echo Default region name and Default output format are optional (press enter to ignore)   
echo.
powershell.exe -command "aws configure --profile ibm-cos"   
echo. 

   
echo Listing available buckets...   
echo Buckets are entities used for uploading data
set LF=^


set "buckets_list="
for /F "delims=" %%f in ('aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net s3 ls --profile ibm-cos') do (
    if defined buckets_list set "buckets_list=!buckets_list!!LF!"
    set "buckets_list=!buckets_list!%%f"
)
if "!buckets_list!" == "" (
 echo No buckets found.
 set choice=1
 echo.

) else (
  echo !buckets_list!
  echo.
  set /p choice="Do you want to create new buckets? : y/n"
  if "!choice!" == "y" (
     set choice=1
  ) else (
     set choice=2
  )

)

if !choice! == 1 (
set finished=0
:source_loop
if !finished! == 0 (
 set /p sourcebucketname="Please enter the name of the source bucket: "
 set LF=^


 set "source_bucket="
 for /F "delims=" %%f in ('aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net s3api create-bucket --bucket !sourcebucketname! --profile ibm-cos 2^>^&1') do (
    if defined source_bucket set "source_bucket=!source_bucket!!LF!"
    set "source_bucket=!source_bucket!%%f"
 )
 if "!source_bucket!" == "" (
   echo Source bucket !sourcebucketname! created successfully.
   set finished=1
 ) else (
   echo !source_bucket!
   goto source_loop
 )
 
) 
REM ///////////////////////// TARGET BUCKET ///////////////////
set finished=0
:target_loop
if !finished! == 0 (
 set /p targetbucketname="Please enter the name of the target bucket: "
 set LF=^


 set "target_bucket="
 for /F "delims=" %%f in ('aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net s3api create-bucket --bucket !targetbucketname! --profile ibm-cos 2^>^&1') do (
    if defined target_bucket set "target_bucket=!target_bucket!!LF!"
    set "target_bucket=!target_bucket!%%f"
 )
 if "!target_bucket!" == "" (
   echo Target bucket !targetbucketname! created successfully.
   set finished=1
 ) else (
   echo !target_bucket!
   goto target_loop
 )
 
) 

) 
REM /////////////// UPLOADING DATA TO COS //////////////////////////////////////

set finished=0
:upload_loop
if !finished! == 0 (
 set /p readchoice="Do you want to upload data to the sourcebucket :y/n  "
 if "!readchoice!" == "y" (
  set /p bucketname="Enter the bucket name:   "
  set /p fname="Enter the path to the file to upload:  "

  set LF=^


 set "source_bucket="
 for /F "delims=" %%f in ('
aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net --profile ibm-cos s3 cp !fname! s3://!bucketname!/ 2^>^&1') do (
    if defined source_bucket set "source_bucket=!source_bucket!!LF!"
    set "source_bucket=!source_bucket!%%f"
 )
 if %ERRORLEVEL% NEQ 1 (
   echo !fname! successfully uploaded to bucket !bucketname!
   goto upload_loop
 ) else (
   echo !source_bucket!
   goto upload_loop
 )
 ) 
 
echo ###############################################################   
echo  Setting up enviroment for Watson Machine Learning - Complete 

   
echo ###############################################################

   
echo.

   
echo  Get started with the WML CLI - execute the below export statements
   
echo  set ML_INSTANCE=!instance_id!  
echo  set ML_USERNAME=!username!  
echo  set ML_PASSWORD=!password!

   
echo  set ML_ENV=!url!   
echo  bx ml --help

   
echo  Tutorial Link - https://console.stage1.bluemix.net/docs/services/PredictiveModeling/ml_dlaas_working_with_sample_models.html#tutorial   
echo.

   
echo ###############################################################
) else (
     set finished=1
) 

)
)

)