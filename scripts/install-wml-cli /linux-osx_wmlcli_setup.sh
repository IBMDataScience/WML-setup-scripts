#!/bin/bash



echo "###################################################"
echo " Setting up enviroment for Watson Machine Learning "
echo "###################################################"

echo "Checking pre-requisites ..."
echo ""
echo "Checking if curl is installed..."
echo ""

########################################## CHECKING IF CURL IS INSTALLED##################################

curl_check="$(curl -V 2>&1)"
unamecheck=`uname -s`	
if [[ "$curl_check" == *"command not found"* ]]; then
  echo "Please install curl on your machine"
else

######################################### CHECKING IF BLUEMIX CLI IS INSTALLED############################
  echo "########################################"
  echo " Setting up IBM Cloud CLI - Phase 1"
  echo "########################################"
  echo ""
  bx_check="$(bx -v 2>&1)"
  unamestr=`uname`
  if [[ "$bx_check" == *"not recognized"* ]];then
    powershell.exe -command "iex (New-Object Net.WebClient).DownloadString('https://clis.ng.bluemix.net/install/powershell')"
  else
   if [[ "$bx_check" == *"command not found"* ]]; then
    if [[ "$unamestr" == 'Darwin' ]]; then
     curl -fsSL https://clis.ng.bluemix.net/install/osx | sh
    elif [[ "$unamestr" == 'Linux' ]]; then
     curl -fsSL https://clis.ng.bluemix.net/install/linux | sh
    fi
   fi
  fi

######################################## LOGIN INTO BLUEMIX #############################################
  echo "################################################################"
  echo " Login to IBM Cloud, use IBM id to login when prompted - Phase 2."
  echo "################################################################"
  echo ""
  bx login -a https://api.stage1.ng.bluemix.net --sso
  if [[ "$?" == 1 ]]; then
     echo "Bluemix login failed. Please try again."
     echo ""
     exit
  fi
  bx target --cf
  resource_group_check="$(bx resource groups 2>&1)"
  if [[ "$resource_group_check" == *"No resource group found"* ]]; then
     echo "No resource group found."
     echo ""
     exit
  fi
  echo ""

######################################## INSTALL WML CLI PLUGIN FROM BLUEMIX ############################

  echo "##########################################################"
  echo " Setting up Watson Machine Learning Plugin - Phase 3"
  echo "##########################################################"
  echo ""
  bx plugin install machine-learning -r Bluemix
  echo ""

####################################### CREATE A NEW COS / USE AN EXISTING ONE ##########################

  echo "##########################################################"
  echo " Setting up IBM Cloud Storage Instance - Phase 4"
  echo "##########################################################"
  echo ""
  cos=`bx resource service-instances --long | grep "cloud-object-storage"`
  if [[ $cos == "" ]]; then
    echo "No Cloud Object Instances are found. Creating one ..."
    echo ""
    bx resource service-instance-create COS_CLI cloud-object-storage lite global
    bx resource service-instance COS_CLI
    echo "Creating key cli_key_COS_CLI"
    bx resource service-key-create "cli_key_COS_CLI" Writer --instance-name "COS_CLI" --parameters '{"HMAC":true}' > /dev/null 2>&1
    a=`bx resource service-instances --long | tail -1 | awk -F"   " '{print $2}'`
    echo "Instance-name - $a"
    #Extract access_key_id from the creds
    access_key_id=`bx resource service-key cli_key_COS_CLI | grep "access_key_id"| cut -d\:  -f2`
    echo "access_key_id - $access_key_id"
    secret_access_key=`bx resource service-key cli_key_COS_CLI | grep "secret_access_key"| cut -d\:  -f2`
    echo "secret_access_key - $secret_access_key"
    echo ""
  else
    echo "Found existing COS Instances..."
    echo ""
    IFS=$'\n'
    array=($(bx resource service-instances --long| grep "cloud-object-storage" | awk -F" {2,}" '{print $2}'))
	n=1
	for i in ${array[@]}; do echo "$n) $i"; n=$((n+1)); done
    echo "Please enter your choice number in [1...${#array[@]}]"
    finished=0
    while  [ ${finished} == 0 ]; do
    	read number
    	if [[ "$((number))" -gt "0" && "$((number))" -le "${#array[@]}"  ]]; then
    	  finished=1
    	else
    	  echo "Please enter a valid choice in [1...${#array[@]}]"
    	fi
    done
    keys=`bx resource service-keys --instance-name ${array[$((number-1))]}`
    keyname="cli_key_${array[$((number-1))]}"

    if [[ "$keys" == *"$keyname"* ]];then
     echo "Instance-name - ${array[$((number-1))]}"
     access_key_id=`bx resource service-key $keyname | grep "access_key_id"| cut -d\:  -f2`
     echo "Access key id - $access_key_id"

     secret_access_key=`bx resource service-key $keyname | grep "secret_access_key"| cut -d\:  -f2`
     echo "Secret access key - $secret_access_key"
     #Extract access_key_id from the creds
     echo ""
     echo "Use the above credentials to configure awscli in Phase 6..."
     echo ""
    else
      echo "Creating key $keyname..."

      bx resource service-key-create $keyname Writer --instance-name ${array[$((number-1))]} --parameters '{"HMAC":true}' > /dev/null 2>&1
      #Extract access_key_id from the creds
      access_key_id=`bx resource service-key $keyname | grep "access_key_id"| cut -d\:  -f2`
      echo "Instance-name - ${array[$((number-1))]}"

      echo "access_key_id - $access_key_id"
      secret_access_key=`bx resource service-key $keyname | grep "secret_access_key"| cut -d\:  -f2`
      echo "secret_access_key - $secret_access_key"
      echo ""
      echo "Use the above credentials to configure aws later..."
      echo ""
    fi
    echo ""
  fi

################################# CREATE A NEW WML INSTANCE / USE AN EXISTING ONE #####################################
  echo "##########################################################"
  echo " Setting up Watson Machine Learning Instance - Phase 5"
  echo "##########################################################"
  echo ""

  wml=`bx service list | grep "pm-20"`
  if [[ $wml == "" ]]; then
    echo "No Watson Machine Learning Instances are found. Creating one ..."
    echo ""
    bx service create pm-20 lite CLI_WML_Instance
    bx service key-create CLI_WML_Instance cli_key_CLI_WML_Instance
    instance_id=`bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance | grep "instance_id"| awk -F": " '{print $2}'| cut -d'"' -f2`
    echo "Instance-name - CLI_WML_Instance"
    echo "instance_id - $instance_id"
    username=`bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance | grep "username"| awk -F": " '{print $2}'| cut -d'"' -f2`
    echo "username - $username"
    password=`bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance | grep "password"| awk -F": " '{print $2}'| cut -d'"' -f2`
    echo "password - $password"
    url=`bx service key-show CLI_WML_Instance cli_key_CLI_WML_Instance | grep "url"| awk -F": " '{print $2}'| cut -d'"' -f2`
    echo "url - $url"
    echo "Use these details to configure the environment variables ML_INSTANCE, ML_USERNAME, ML_PASSWORD, ML_ENV"
    echo "Example"
    echo "export ML_INSTANCE=$instance_id"
    echo "export ML_USERNAME=$username"
    echo "export ML_PASSWORD=$password"
    echo "export ML_ENV=$url"
    echo ""
    #Extract access_key_id from the creds
  else
    echo "Found existing WML Instances..."
    service_instances=`bx services list | grep "pm-20"`
    IFS=$'\n'
    wml_array=($(bx service list | grep "pm-20"| awk -F" {2,}" '{print $1}'))
	n=1
	for i in ${wml_array[@]}; do echo "$n) $i"; n=$((n+1)); done
    echo "Please enter your choice number in [1...${#wml_array[@]}]"
    finished=0
    while  [ ${finished} == 0 ]; do
    	read number
    	if [[ "$((number))" -gt "0" && "$((number))" -le "${#wml_array[@]}"  ]]; then
    	  finished=1
    	else
    	  echo "Please enter a valid choice in [1...${#wml_array[@]}]"
    	fi
    done
    keys=`bx service keys ${wml_array[$((number-1))]}`
    keyname="cli_key_${wml_array[$((number-1))]}"

    if [[ "$keys" == *"$keyname"* ]];then
     echo "Instance-name - ${wml_array[$((number-1))]}"
     instance_id=`bx service key-show ${wml_array[$((number-1))]} $keyname  | grep "instance_id"| awk -F": " '{print $2}'| cut -d'"' -f2`
     echo "instance_id - $instance_id"
     username=`bx service key-show ${wml_array[$((number-1))]} $keyname  | grep "username"| awk -F": " '{print $2}'| cut -d'"' -f2`
     echo "username - $username"
     password=`bx service key-show ${wml_array[$((number-1))]} $keyname  | grep "password"| awk -F": " '{print $2}'| cut -d'"' -f2`
     echo "password - $password"
     url=`bx service key-show ${wml_array[$((number-1))]} $keyname | grep "url"| awk -F": " '{print $2}'| cut -d'"' -f2`
     echo "url - $url"
     echo "Use these details to configure the environment variables ML_INSTANCE, ML_USERNAME, ML_PASSWORD, ML_ENV"
     echo "Example"
     echo "export ML_INSTANCE=$instance_id"
     echo "export ML_USERNAME=$username"
     echo "export ML_PASSWORD=$password"
     echo "export ML_ENV=$url"
     echo ""
    else
      bx service key-create ${wml_array[$((number-1))]} $keyname
      instance_id=`bx service key-show ${wml_array[$((number-1))]} $keyname  | grep "instance_id"| awk -F": " '{print $2}'| cut -d'"' -f2`
      echo "Instance-name - ${wml_array[$((number-1))]}"
      echo "instance_id - $instance_id"
      username=`bx service key-show ${wml_array[$((number-1))]} $keyname | grep "username"| awk -F": " '{print $2}'| cut -d'"' -f2`
      echo "username - $username"
      password=`bx service key-show ${wml_array[$((number-1))]} $keyname  | grep "password"| awk -F": " '{print $2}'| cut -d'"' -f2`
      echo "password - $password"
      url=`bx service key-show ${wml_array[$((number-1))]} $keyname  | grep "url"| awk -F": " '{print $2}'| cut -d'"' -f2`
      echo "url - $url"
      echo "Use these details to configure the environment variables ML_INSTANCE, ML_USERNAME, ML_PASSWORD, ML_ENV"
      echo "Example"
      echo "export ML_INSTANCE=$instance_id"
      echo "export ML_USERNAME=$username"
      echo "export ML_PASSWORD=$password"
      echo "export ML_ENV=$url"
      echo ""
    fi
    echo ""
  fi

############################################ CHECKING IF PIP/AWSCLI IS INSTALLED #######################################
  echo "##########################################################"
  echo " Setting up awscli... Phase 6"
  echo "##########################################################"
  echo ""
  configure=0
  echo "Checking if python is installed..."
  pip_installation_folder="$(python -m site --user-base 2>&1)"
  if [[ "$pip_installation_folder" == *"command not found"* ]]; then
    echo ""
    echo "Please install python on your machine."
    echo ""
    echo "Setting up awscli - Phase 6 failed."
    echo ""
    exit
  else
    export PATH="$pip_installation_folder/bin/:$PATH"
  fi
  echo ""
  echo "Checking if pip is installed..."
  echo ""
  pip_check="$(pip --version 2>&1)"
  if [[ "$pip_check" == *"command not found"* ]]; then
   echo "'Please install pip on your machine"
   echo ""
   echo "Setting up awscli - Phase 6 failed."
   echo ""
   exit
  else
   echo "Checking if awscli is installed..."
   echo ""
   aws_check="$(aws --version 2>&1)"
   if [[ "$aws_check" == *"command not found"* ]]; then
    pip install awscli --upgrade --user
    aws_check="$(aws --version 2>&1)"

    if [[ "$aws_check" == *"command not found"* ]]; then
     echo ""
     echo "aws not found in your PATH. Please modify PATH variable to include the path to AWS."
     echo ""
     echo "Setting up awscli - Phase 6 failed."
     echo ""
    else
     configure=1
    fi
   else
    configure=1
   fi
   if [[ $configure == 1 ]]; then
    echo "Please configure AWSCLI with the access_key_id and secret_access_key as displayed in Phase 4"
    echo "Configuring awscli..."
    echo "Default region name and Default output format are optional (press enter to ignore)"
    echo ""
    aws configure --profile ibm-cos
    echo ""
    echo "Listing available buckets..."
    echo "Buckets are entities used for uploading data"
    echo "Used for storing training data and training results"
    list=`aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net s3 ls --profile ibm-cos`
    choice=0
    if [[ "$list" == "" ]];then
        echo "No buckets found. Creating buckets..."
    	choice=1
    else
      echo ""
      echo "$list"
      echo "Do you want to create new buckets for source data and target data: y/n"
      read choice
      if [[ "$choice" == "y" ]];then
        choice=1
      fi
      if [[ "$choice" == "n" ]];then
        choice=2
      fi
    fi
    if [[ "$choice" == 1 ]]; then
    finished=0
    while  [ ${finished} == 0 ]; do
        echo "Enter the source bucket name: "
        read sourcebucketname

        buckets="$(aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net s3api create-bucket --bucket "$sourcebucketname" --profile ibm-cos 2>&1)"
        if [[ "$buckets" == "" ]];then
          echo "Source Bucket $buckets successfully created."
          finished=1
        else
         echo $buckets
        fi
    done
    finished=0
    while  [ ${finished} == 0 ]; do
        echo "Enter the target bucket name: "
        read targetbucketname
        buckets="$(aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net s3api create-bucket --bucket "$targetbucketname" --profile ibm-cos 2>&1)"
        if [[ "$buckets" == "" ]];then
          echo "Target bucket $buckets successfully created."
          finished=1
        else
         echo $buckets
        fi
    done
    fi
    choice=2
    if [[ "$choice" == 2 ]]; then
    finished=0
    while  [ ${finished} == 0 ]; do
        echo "Do you want to upload training data to a bucket: y/n"
        read choice
        if [[ "$choice" == "y" ]];then
        # finished=1
        #fi
         echo "Enter the bucket name: "
         read bucketname
         echo "Enter the file name to upload"
         read filename
         buckets="$(aws --endpoint-url=http://s3-api.us-geo.objectstorage.softlayer.net --profile ibm-cos s3 cp "$filename" s3://"$bucketname"/ 2>&1)"
         if [[ "$?" == 0 ]];then
           echo "$filename successfully uploaded to bucket $bucketname"
         else
          echo $buckets
         fi
        else
         finished=1
        fi
    done
    fi
    echo "###############################################################"
    echo " Setting up enviroment for Watson Machine Learning - Complete "
    echo "###############################################################"
    echo ""
    echo " Get started with the WML CLI - execute the below export statements"
    echo " export ML_INSTANCE=$instance_id"
    echo " export ML_USERNAME=$username"
    echo " export ML_PASSWORD=$password"
    echo " export ML_ENV=$url"
    echo " bx ml --help"
    echo " Tutorial Link - https://console.stage1.bluemix.net/docs/services/PredictiveModeling/ml_dlaas_working_with_sample_models.html#tutorial"
    echo ""
    echo "###############################################################"
   fi
  fi

fi
