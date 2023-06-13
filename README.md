# openITCOCKPIT Workshops

This Repository contains all contains all necessary files, to setup an openITCOCKPIT Monitoring Server.


## Setup openITCOCKPIT Monitoring Server

1. Create a new Ubuntu VM (20.04 / 22.04).
2. Clone this repository.
3. Run `install.sh` or `install.sh "[MGMT-IP]"` 
4. Navigate to `https://192.168.xxx.xxx/info/`

### Features

Overview of all credentials
![Overview of all credentials](/screenshots/credentials_overview.png)

Web based SSH terminal
![Web based SSH terminal](/screenshots/webbased_ssh_terminal.png)

Installation of openITCOCKPIT
![openITCOCKPIT Login Screen](/screenshots/openitcockpit_login.jpg)


### Enterprise Workshops
Especially for Workshops where openITCOCKPIT Enterprise Modules should be used it is recommended setup and manage the Workshop VMs due to the Management Server from:

https://github.com/it-novum/openITCOCKPIT-workshops-enterprise

Run: `./install.sh "IP-OF-MGMT-SERVER"`


