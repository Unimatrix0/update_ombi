#!/bin/bash

####################################
##   update_ombi systemd script   ##
## GitHub: Unimatrix0/update_ombi ##
####################################

####################################
##  Override default settings by  ##
##  creating update_ombi.conf in  ##
##  the same directory that the   ##
##  script is running in and set  ##
##  the required variables there  ##
####################################

##   The systemd unit for Ombi    ##
ombiservicename="ombi"

##    The update_ombi log file    ##
logfile="/var/log/ombiupdater.log"

####################################
##  The remaining variables only  ##
##  need to be set or overridden  ##
##  if the script is unable to    ##
##  parse the ombi.service file   ##
##  for the correct settings      ##
####################################
## !! This should never happen !! ##
####################################

##  The service file's full path  ##
ombiservicefile="/etc/systemd/system/$ombiservicename.service"

##     Ombi install directory     ##
defaultinstalldir="/opt/Ombi"

##   User and Group Ombi runs as  ##
defaultuser="ombi"
defaultgroup="nogroup"
defaulturl="http://127.0.0.1:5000"

##       Level of verbosity       ##
##        By default, none        ##

declare -i verbosity=-1

############################################
## Do not modify anything below this line ##
##   unless you know what you are doing   ##
############################################

name="update_ombi"
version="1.0.13"

while [ $# -gt 0 ]; do
  case "$1" in
    --verbosity|-v=*)
      if [[ ${1#*=} =~ ^-?[0-8]$ ]]; then
          verbosity="${1#*=}"
      else
	      printf "****************************\n"
          printf "* Error: Invalid verbosity.*\n"
          printf "****************************\n"
          exit 1
	  fi
      ;;
    *)
      printf "****************************\n"
      printf "* Error: Invalid argument. *\n"
      printf "****************************\n"
      exit 1
  esac
  shift
done

declare -A LOG_LEVELS=([-1]="none" [0]="emerg" [1]="alert" [2]="crit" [3]="err" [4]="warning" [5]="notice" [6]="info" [7]="debug" [8]="trace")
function .log () {
    local LEVEL=${1}
    shift
    if [[ $verbosity =~ ^-?[0-8]$ ]]; then
            if [ $verbosity -ge $LEVEL ]; then
            echo "[${LOG_LEVELS[$LEVEL]}]" "$@"
        fi
    fi
	if [ $verbosity -eq 8 ] || [ $LEVEL -ne 8 ]; then
        echo "[${LOG_LEVELS[$LEVEL]}]" "$@" >> $logfile
    fi
}

unzip-strip() (
    local zip=$1
    local dest=${2:-.}
    local temp=$(mktemp -d) && tar -zxf "$zip" -C "$temp" && mkdir -p "$dest" &&
    shopt -s dotglob && local f=("$temp"/*) &&
    if (( ${#f[@]} == 1 )) && [[ -d "${f[0]}" ]] ; then
        cp -r "$temp"/*/* "$dest"
    else
        cp -r "$temp"/* "$dest"
    fi && rm -rf "$temp"/* "$temp"
)

# Import any custom config to override the defaults, if necessary
configfile="$(dirname $0)/update_ombi.conf"
if [ -e $configfile ]; then
    source $configfile > /dev/null 2>&1
    .log 6 "Script config file found...parsing..."
    if [ $? -ne 0 ] ; then
        .log 3 "Unable to use config file...using defaults..."
    else
        .log 6 "Parsed config file"
    fi
else
    .log 6 "No config file found...using defaults..."
fi

.log 6 "$name v$version"
.log 6 "Verbosity level: [${LOG_LEVELS[$verbosity]}]"
scriptuser=$(whoami)
.log 7 "Update script running as: $scriptuser"
if [ -e $ombiservicefile ]; then
    .log 6 "Ombi service file for systemd found...parsing..."
    ombiservice=$(<$ombiservicefile)
    installdir=$(grep -Po '(?<=WorkingDirectory=)(\S|(?<=\\)\s)+' <<< "$ombiservice")
    user=$(grep -Po '(?<=User=)(\w+)' <<< "$ombiservice")
    group=$(grep -Po '(?<=Group=)(\w+)' <<< "$ombiservice")
    url=$(grep -Po '(?<=\-\-host )(.+)$' <<< "$ombiservice")
    .log 6 "Parsing complete: InstallDir: $installdir, User: $user, Group: $group, URL: $url"
fi

if [ -z ${installdir+x} ]; then
    .log 5 "InstallDir not parsed...setting to default: $defaultinstalldir"
    installdir="$defaultinstalldir"
fi
if [ -z ${user+x} ]; then
    .log 5 "User not parsed...setting to default: $defaultuser"
    user="$defaultuser"
fi
if [ -z ${group+x} ]; then
    .log 5 "Group not parsed...setting to default: $defaultgroup"
    group="$defaultgroup"
fi
if [ -z ${url+x} ]; then
    .log 5 "URL not parsed...setting to default: $defaulturl"
    url="$defaulturl"
fi


.log 6 "Downloading Ombi update..."
declare -i i=1
declare -i j=5
while [ $i -le $j ]
do
    .log 6 "Checking for latest version"
    json=$(curl -sL https://ombiservice.azurewebsites.net/api/update/DotNetCore)
	.log 8 "json: $json"
    latestversion=$(grep -Po '(?<="updateVersionString":")([^"]+)' <<<  "$json")
    .log 7 "latestversion: $latestversion"
    json=$(curl -sL https://ci.appveyor.com/api/projects/tidusjar/requestplex/build/$latestversion)
    .log 8 "json: $json"
    jobId=$(grep -Po '(?<="jobId":")([^"]+)' <<<  "$json")
    .log 7 "jobId: $jobId"
    version=$(grep -Po '(?<="version":")([^"]+)' <<<  "$json")
    .log 7 "version: $version"
	if [ $latestversion != $version ]; then
		.log 2 "Build version does not match expected version"
		exit 1
	fi
    .log 6 "Latest version: $version...determining expected file size..."
    size=$(curl -sL https://ci.appveyor.com/api/buildjobs/$jobId/artifacts | grep -Po '(?<="linux.tar.gz","type":"File","size":)(\d+)')
    .log 7 "size: $size"
    if [ -e $size ]; then
        if [ $i -lt $j ]; then
            .log 3 "Unable to determine update file size...[attempt $i of $j]"
        else
            .log 2 "Unable to determine update file size...[attempt $i of $j]...Bailing!"
            exit 2
        fi
        i+=1
        continue
	elif [[ $size =~ ^-?[0-9]+$ ]]; then
        .log 6 "Expected file size: $size...downloading..."
        break
	else
        .log 1 "Invalid file size value...bailing!"
        exit 99
    fi
done
tempdir=$(mktemp -d)
file="$tempdir/ombi_$version.tar.gz"
wget --quiet --show-progress -O $file "https://ci.appveyor.com/api/buildjobs/$jobId/artifacts/linux.tar.gz"
.log 6 "Version $version downloaded...checking file size..."
if [ $(wc -c < $file) != $size ]; then
    .log 3 "Downloaded file size does not match expected file size...bailing!"
    exit 2
fi
.log 6 "File size validated...checking Ombi service status..."

declare -i running=0
if [ "`systemctl is-active $ombiservicename`" == "active" ]; then
    running=1
    .log 6 "Ombi is active...attempting to stop..."
    declare -i i=1
    declare -i j=5
    while [ $i -le $j ]
    do
        if [ $scriptuser = "root" ]; then
            systemctl stop $ombiservicename.service > /dev/null 2>&1
        else
            sudo systemctl stop $ombiservicename.service > /dev/null 2>&1
        fi
        if [ $? -ne 0 ] || [ "`systemctl is-active $ombiservicename`" == "active" ] ; then
            if [ $i -lt $j ]; then
                .log 3 "Failed to stop Ombi...[attempt $i of $j]"
				sleep 1
            else
                .log 2 "Failed to stop Ombi...[attempt $i of $j]...Bailing!"
                exit 2
            fi
            i+=1
            continue
        elif [ "`systemctl is-active $ombiservicename`" == "inactive" ]; then
            .log 6 "Ombi stopped...installing update..."
            break
        else
            .log 1 "Unknown error...bailing!"
            exit 99
        fi
    done
else
    .log 6 "Ombi is not active...installing update..."
fi

unzip-strip $file $installdir
.log 6 "Update installed...setting ownership..."
chown -R $user:$group $installdir

if [ $running -eq 1 ]; then
    .log 6 "Ownership set...starting Ombi..."
    declare -i i=1
    declare -i j=5
    while [ $i -le $j ]
    do
        if [ $scriptuser = "root" ]; then
            systemctl start $ombiservicename.service > /dev/null 2>&1
        else
            sudo systemctl start $ombiservicename.service > /dev/null 2>&1
        fi
        if [ $? -ne 0 ] || [ "`systemctl is-active $ombiservicename`" != "active" ] ; then
            if [ $i -lt $j ]; then
                .log 3 "Failed to start Ombi...[attempt $i of $j]"
				sleep 1
            else
                .log 2 "Failed to start Ombi...[attempt $i of $j]...Bailing!"
               exit 3
            fi
            i+=1
            continue
        elif [ "`systemctl is-active $ombiservicename`" == "active" ]; then
            .log 6 "Ombi started...waiting for confirmation..."
            declare -i k=1
            declare -i l=5
            while [ $k -le $l ]
            do
                sleep 5
                curl -sIL $url > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    if [ $k -lt $l ]; then
                        .log 4 "Ombi startup not confirmed...waiting 5 seconds...[attempt $k of $l]"
                    else
                        .log 2 "Ombi startup not confirmed...[attempt $k of $l]...bailing!"
                        exit 4
                    fi
                    k+=1
                    continue
                else
                    .log 6 "Ombi startup confirmed...cleaning up..."
                    break
                fi
            done
            break
        else
            .log 1 "Unknown error...bailing!"
            exit 99
        fi
    done
else
    .log 6 "Ownership set...not starting Ombi"
fi

.log 6 "Cleaning up..."
rm -rf "$tempdir"/* "$tempdir"
.log 6 "Update complete"
