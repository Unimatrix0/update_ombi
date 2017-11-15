# update_ombi
Ombi (tidusjar/Ombi) update script for Systemd (Ubuntu based distros)

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
