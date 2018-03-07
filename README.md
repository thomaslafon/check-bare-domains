# Check bare domains

This script checks, for an ACSF instance, if all bare domains DNS go through CDNs IPs on Cloudflare
The script retrieves all domains of a subscription reading "sites.json" on the server,
then check DNS entries for each one and compare them to CDNs IPs from Cloudflare.

Test the script by executing it locally on the server and it will send an email :
```sh
$ ./checkDNS.sh "thomas.lafon@acquia.com"
```

## Installation

### Crontab should contain
```sh
/mnt/gfs/${AH_SITE_NAME}/scripts/checkDNS.sh "simon.elliott@acquia.com, thomas.lafon@acquia.com" &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/cron-checkDNS.log
```
### Requirements

don't forget to include jq file as well in same directory
https://stedolan.github.io/jq/

## Releases
### v0.1 : Init
* Check bare domains against a single IP for all domains of a subscription, send report email.

### v0.2 : 11/08/2017
* Checks correctly multi A records DNS configurations.
* Report a list of all not yet configured domains with CDNs IPs that should be set.
* Report a list of all well configured domains as verification purposes.

### v0.3 : 03/07/2017 - Added documentation and README.md

## Todos
* Add "Ignore patterns" as second argument,
* Example : $ ./checkDNS.sh "thomas.lafon@acquia.com" "factory.nestleprofessional.com"


edit me! / Share me!