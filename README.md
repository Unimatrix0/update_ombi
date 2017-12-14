# update_ombi
[Ombi](https://github.com/tidusjar/Ombi) update script for Systemd (Ubuntu based distros)

**Create the Ombi update script**
       
    wget https://raw.githubusercontent.com/Unimatrix0/update_ombi/master/update_ombi.sh

> ### Note:  
> This script assumes your systemd service is named **ombi**. If this is not the case, set the ***ombiservicename*** variable at the top of the script.  
> The script attempts to automatically detect the required variables by parsing the service file.  
> It assumes the service file is named ***ombiservicename*.service** in the default directory (/etc/systemd/system/).  
> If the service file can't be found, or if the variables can't be parsed from the service file, it assumes they are the defaults of
> * Installation Dir: **/opt/Ombi**
> * User: **ombi**
> * Group: **nogroup**
> * URL: **http://127.0.0.1:5000**
>
> The script also logs to /var/log/ombiupdater.log by default. Make sure that the user running the script has write access to this file.  
> You can override these defaults by setting the variables in the **Default variables** section at the top.

Edit the script file to set variables as needed.
       
    nano update_ombi.sh

Press <kbd>Ctrl</kbd>+<kbd>X</kbd> then <kbd>y</kbd> to save (assuming you're using nano).

Make it executable
```
chmod +x ~/update_ombi.sh 
```

When an update is available for Ombi simply run
```
sudo ./update_ombi.sh
```

If you do not plan to run the script as a user with full sudo privileges, you can restrict access for the user with the following:  
Edit the sudoers file to give restricted access to the script user
```
sudo visudo
```

Near the bottom of the file, add:
```
ombi    ALL=NOPASSWD: /bin/systemctl stop ombi.service, /bin/systemctl start ombi.service
```

> ### Note:
> This assumes you're running the script as **ombi** and that the systemd service is named **ombi**.

**Configuration File Support with Variables**

In order to ensure that update_ombi applys updates based on your exact configuration, you may need to create a configuration file. update-ombi looks for `update_ombi.conf` in the same directory as `update_ombi.sh`. 

|Variable|Comment|Default Value|
|:----------:|:-------------:|:--------------:|
|*ombiservicename*|The systemd unit for Ombi|ombi|
|*logfile*|The update_ombi log file|/var/log/ombiupdater.log|
|*ombiservicefile*|The service file's full path|/etc/systemd/system/$ombiservicename.service|
|*defaultinstalldir*|Ombi install directory|/opt/Ombi|
|*defaultuser*|The user Ombi runs as|ombi|
|*defaultgroup*|The group Ombi runs as|nogroup|
|*defaultip*|The IP Ombi runs on|127.0.0.1|
|*defaultport*|The port Ombi runs on|5000|
|*verbosity*|Level of verbosity (-1 to 8), see Log Levels below|-1|

**Log Levels**

By default, verbosity is set to -1, which means it will not output anything. Using switch `-v=#` or `--verbosity #`. Options 1 through 7 will log to STDOUT. Option 8 logs to STDOUT and the logfile. The default log location is `/var/log/ombiupdater.log`.

|Log Level|Status|
|:--:|:--:|
|-1|None|
|0|Emergency|
|1|Alert|
|2|Critical|
|3|Error|
|4|Warning|
|5|Notice|
|6|Info|
|7|Debug|
|8|Trace|

