# Check bare domains

This script checks, for an ACSF instance, if all bare domains DNS go through CDNs IPs on Cloudflare
The script retrieves all domains of a subscription reading "sites.json" on the server,
then check DNS entries for each one and compare them to CDNs IPs from Cloudflare.

You can test the script by executing it locally on the server:
```sh
$ ./checkDNS.sh "thomas.lafon@acquia.com"
```

## Installation

### Crontab should contain at least
```sh
/mnt/gfs/${AH_SITE_NAME}/scripts/check-bare-domains/checkDNS.sh "thomas.lafon@acquia.com" &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/cron-checkDNS.log
```
### Additional emails
As the Scheduled Job textarea on Acquia Cloud Interface has a limited number of characters, you can add more recipient emails by by renaming recipients.example.txt to recipients.txt. This will add more recipients to the ones that are already in the Scheduled Job.

### Requirements
don't forget to include jq file as well in same directory, the one included works well
https://stedolan.github.io/jq/

## Releases
### v0.1 : Init
* Check bare domains against a single IP for all domains of a subscription, send report email.

### v0.2 : 11/08/2017
* Checks correctly multi A records DNS configurations.
* Report a list of all not yet configured domains with CDNs IPs that should be set.
* Report a list of all well configured domains as verification purposes.

### v0.3 : 03/07/2017 - Added documentation and README.md

### v0.4 : 12/12/2019 - Added an Ignore Pattern as second argument
* Example : $ ./checkDNS.sh "thomas.lafon@acquia.com" "factory.nestleprofessional.com"
* to ignore all domains finishing with factory.nestleprofessional.com

### v0.5 : 01/09/2019 - Added recipient.txt file to add more email addresses
* As the scheduled job in Acquia Cloud  has a limited number of character
* You can add more email addresses in recipients.txt file where the script is installed on the server

### v0.6 : 01/14/2019 - Added domainstoexclude.txt file to ignore reporting on some domains
* Rename domainstoexclude.example.txt to domainstoexclude.txt
* Put 1 domain per line in domainstoexclude.txt


## Todos

edit me! / Share me!
