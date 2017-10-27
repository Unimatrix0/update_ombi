#!/bin/bash

## Ensure this is set to the name ##
##  of your Ombi systemd service  ##
ombiservicename="ombi"

##   Default variables   ##
## Change only if needed ##
ombiservicefile="/etc/systemd/system/$ombiservicename.service"
defaultinstalldir="/opt/Ombi"
defaultuser="ombi"
defaultgroup="nogroup"

## Do not modify anything below this line ##
##   unless you know what you are doing   ##

if [ -e $ombiservicefile ]; then
    echo "Ombi service file for systemd found...parsing..."
    ombiservice=$(<$ombiservicefile)
    installdir=$(grep -Po '(?<=WorkingDirectory=)(\S|(?<=\\)\s)+' <<< "$ombiservice")
    user=$(grep -Po '(?<=User=)(\w+)' <<< "$ombiservice")
    group=$(grep -Po '(?<=Group=)(\w+)' <<< "$ombiservice")
    echo "Parsing complete: InstallDir: $installdir, User: $user, Group: $group"
fi

if [ -z ${installdir+x} ]; then
    echo "InstallDir not parsed...setting to default: $defaultinstalldir"
    installdir="$defaultinstalldir"
fi
if [ -z ${user+x} ]; then
    echo "User not parsed...setting to default: $defaultuser"
    user="$defaultuser"
fi
if [ -z ${group+x} ]; then
    echo "Group not parsed...setting to default: $defaultgroup"
    group="$defaultgroup"
fi

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

echo "Downloading Ombi update..."
json=$(curl -sL https://ci.appveyor.com/api/projects/tidusjar/requestplex)
jobId=$(grep -Po '(?<="jobId":")([^"]+)' <<<  "$json")
version=$(grep -Po '(?<="version":")([^"]+)' <<<  "$json")
file=ombi_$version.tar.gz
size=$(curl -sL https://ci.appveyor.com/api/buildjobs/$jobId/artifacts | grep -Po '(?<="linux.tar.gz","type":"File","size":)(\d+)')
wget --quiet -O $file https://ci.appveyor.com/api/buildjobs/$jobId/artifacts/linux.tar.gz
echo "Version $version downloaded...checking file size..."
if [ $(wc -c < $file) != $size ]; then
    echo "Downloaded file size does not match expected file size...bailing!"
    exit 1
fi
echo "File size validated...checking Ombi service status..."

declare -i running=0
if [ "`systemctl is-active $ombiservicename`" == "active" ]; then
    running=1
    echo "Ombi is active...attempting to stop..."
    declare -i i=1
    j=5
    while [ $i -le $j ]
    do
        systemctl stop $ombiservicename.service > /dev/null 2>&1
        if [ $? -ne 0 ] || [ "`systemctl is-active $ombiservicename`" == "active" ] ; then
            if [ $i -lt $j ]; then
                echo "Failed to stop Ombi...[attempt $i of $j]"
            else
                echo "Failed to stop Ombi...[attempt $i of $j]...Bailing!"
                exit 2
            fi
            i+=1
            continue
        elif [ "`systemctl is-active $ombiservicename`" == "inactive" ]; then
            echo "Ombi stopped...installing update..."
            break
        else
            echo "Unknown error...bailing!"
            exit 99
        fi
    done
else
    echo "Ombi is not active...installing update..."
fi

unzip-strip $file $installdir
echo "Update installed...setting ownership..."
chown -R $user:$group $installdir

if [ $running -eq 1 ]; then
    echo "Ownership set...starting Ombi..."
    declare -i i=1
    j=5
    while [ $i -le $j ]
    do
        systemctl start $ombiservicename.service > /dev/null 2>&1
        if [ $? -ne 0 ] || [ "`systemctl is-active $ombiservicename`" != "active" ] ; then
            if [ $i -lt $j ]; then
                echo "Failed to start Ombi...[attempt $i of $j]"
            else
                echo "Failed to start Ombi...[attempt $i of $j]...Bailing!"
               exit 3
            fi
            i+=1
            continue
        elif [ "`systemctl is-active $ombiservicename`" == "active" ]; then
            echo "Ombi started...cleaning up..."
            break
        else
            echo "Unknown error...bailing!"
            exit 99
        fi
    done
else
    echo "Ownership set...not starting Ombi"
fi

echo "Cleaning up..."
rm -f $file
echo "Update complete"
