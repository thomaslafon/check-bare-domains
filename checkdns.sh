#!/bin/bash
#
# This script checks, for an ACSF instance, if all bare domains DNS go through CDNs IPs on Cloudflare
# The script retrieves all domains of a subscription reading "sites.json" on the server, 
# then check DNS entries for each one and compare them to CDNs IPs from Cloudflare.
#
# Test the script by executing it locally on the server and it will send an email :
# $ ./checkDNS.sh "thomas.lafon@acquia.com"
#
# CRONTAB should contain
# /mnt/gfs/${AH_SITE_NAME}/scripts/checkDNS.sh "simon.elliott@acquia.com, thomas.lafon@acquia.com" &>> /var/log/sites/${AH_SITE_NAME}/logs/$(hostname -s)/cron-checkDNS.log
#
# Additional emails
# As the Scheduled Job textarea on Acquia Cloud Interface has a limited number of characters, you can add more recipient emails by by renaming recipients.example.txt to recipients.txt.
# This will add more recipients to the ones that are already in the Scheduled Job.
#
# Requirements : don't forget to include jq file as well in same directory
# https://stedolan.github.io/jq/
#
# RELEASES
## v0.1 : Init
# * Check bare domains against a single IP for all domains of a subscription, send report email.
#
## v0.2 : Updated on 2017/11/08 :
# * Checks correctly multi A records DNS configurations.
# * Report a list of all not yet configured domains with CDNs IPs that should be set.
# * Report a list of all well configured domains as verification purposes.
#
## v0.3 : Updated on 2019/12/19 :
# * Added "ignored_patterns" as second argument, separated by commas, no space
#   Useful for specific domains to be ignored, like factory domains
# 
# * Example : $ ./checkDNS.sh "thomas.lafon@acquia.com" "factory1.example.com,factory2.example.com"
# 
## v0.4 : 12/12/2019 - Added an Ignore Pattern as second argument
# * Example : $ ./checkDNS.sh "thomas.lafon@acquia.com" "factory.nestleprofessional.com"
# * to ignore all domains finishing with factory.nestleprofessional.com
#
## v0.5 : 01/09/2019 - Added recipient.txt file to add more email addresses
# * As the scheduled job in Acquia Cloud  has a limited number of character
# * You can add more email addresses in recipients.txt file where the script is installed on the server
#
## v0.6 : 01/13/2019 - Added domainstoexclude.txt file to ignore reporting on some domains
# * Rename domainstoexclude.example.txt to domainstoexclude.txt
# * Put 1 domain per line in domainstoexclude.txt
#
#
# edit me! / Share me!
#

# Retrieves the domains list
readonly SCRIPTS_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
readonly SITES_JSON_FILE="/mnt/gfs/$AH_SITE_GROUP.$AH_SITE_ENVIRONMENT/files-private/sites.json";
readonly JQ="$SCRIPTS_BASE/jq";
# Pass email adresses as argument, default to "noalert" mecanism
MAIL_TO=${1:-noalert};
# Prepare files
if [[ -f $SCRIPTS_BASE"/domainstoexclude.txt"  ]]; then
  IGNORED_ZONES=`cat $SCRIPTS_BASE/domainstoexclude.txt`
else
  IGNORED_ZONES=""
fi
if [[ -f $SCRIPTS_BASE"/recipients.txt" && $MAIL_TO != "noalert" ]]; then
  RECIPIENTS=`cat $SCRIPTS_BASE/recipients.txt`
  MAIL_TO=$MAIL_TO",$RECIPIENTS"
fi
# Pass ignored_patterns as argument, default to "nopattern" mecanism
readonly IGNORED_PATTERNS=${2:-nopattern};
if [[ $IGNORED_PATTERNS != "nopattern" ]]; then
  IFS=',' read -ra arrIGNORED <<< "$IGNORED_PATTERNS"
fi

# ACSF sites parsed from json.
declare -A SITES=();

# Grab list of all ACSF sites domains
domain_list() {
  info=$(cat ${SITES_JSON_FILE} | ${JQ} '.sites | to_entries | map({domain: .key, name: .value.name, db: .value.conf.acsf_db_name})');
  site_count=$(echo ${info} | ${JQ} 'length');

  local i=0;
  for ((i=0; i < site_count; i++))
  do
    domain=$(echo ${info} | ${JQ} -r '.['${i}'].domain');
    SITES[${domain}]="$domain";
  done

  if [[ ${#SITES[@]} -eq 0 ]]; then
    echo "$SITES_JSON_FILE doesn't contain domain names";
    return 1;
  fi

  return 0;
}

isbaredomain() {
  #regexp="^(([^.]*)(\.com(\..+)?|\.co(\.[^.]*$)+|\.[^\.]*))$"
  regexp="^(([^.]*)(\.com(\..+)?|\.co(\.[^.]*$)+|\.in(\.[^.]*$)+|\.[^\.]*))$"
  
  if [[ $1 =~ $regexp ]]; then 
    echo "1"
    return
  else
    echo "0"
    return
  fi
}

# MAIN
echo "Check CF configuration $(date '+%d/%m/%Y %H:%M:%S')";
domain_list || { echo "something went wrong while getting site list.";exit 1; }

MAIL_BODY="Hi everyone,\n\nPlease find here the list of all websites\n\n"
MAIL_BODY=$MAIL_BODY"############################\n"
MAIL_BODY=$MAIL_BODY"# NOT SET on a Cloudflare CDN #\n"
MAIL_BODY=$MAIL_BODY"############################\n\n"

MAIL_BODY_DOMAINS_OK="";
MAIL_BODY_DOMAINS_NOK="";

(for DOMAIN in ${SITES[@]}
do
  # gather details
  if [ "${DOMAIN:0:3}" != 'www' ] && [ "${DOMAIN:0:7}" != 'preprod' ] && [ "${DOMAIN: -17}" != 'acsitefactory.com' ]; then
    # check if domain does not contain ignored patterns
    ISAPATTERN=0
    for ignored_pattern in "${arrIGNORED[@]}"; do
      length=${#ignored_pattern}
      if [[ "${DOMAIN: -$length}" == $ignored_pattern ]]; then
        ISAPATTERN=1
      fi
    done

    if [[ $ISAPATTERN -eq 1 ]]; then
      continue
    fi
    # check if domain is is the IGNORED_DOMAINS
    if [[ $IGNORED_ZONES == *"$DOMAIN"* ]]; then
      continue
    fi

    echo "===== checking $DOMAIN ====="

    # We first assume config is set correctly
    # If any DNS entry ip is not against a CDN load balancer
    # we invalidate the conf
    CONFIGOK=1
    ISBAREDOMAIN=`isbaredomain "$DOMAIN"`

    # Remove /xxxxx part from the domain name
    regexp="^([^/]*)\/?.*$"
    if [[ $DOMAIN =~ $regexp ]]; then 
      REALDOMAIN=${BASH_REMATCH[1]};
    else
      REALDOMAIN=$DOMAIN
    fi

    if [[ $ISBAREDOMAIN -ge 1 ]]; then
      # If it's a bare domain we get A records
      BAREIP=`dig a $REALDOMAIN +short`
      CDN=`dig $REALDOMAIN.cdn.cloudflare.net +short`

      # Check multi DNS entries.
      for cdndomain in $CDN
      do
        ISLINEIN=0
        for bare in $BAREIP
          do
            if [ "$cdndomain" = "$bare" ]; then
              ISLINEIN=1
            fi
          done
          if [[ $ISLINEIN -eq 0 ]]; then
            CONFIGOK=0
          fi
      done

      if [[ $CONFIGOK -eq 0 ]]; then
        MAIL_BODY_DOMAINS_NOK=$MAIL_BODY_DOMAINS_NOK"===== $DOMAIN =====\rFirst ensure a DNS entry exists on Cloudflare \"$REALDOMAIN => {loadbalancerIP}\"\r";
        MAIL_BODY_DOMAINS_NOK=$MAIL_BODY_DOMAINS_NOK"If Yes, then please set A records on $REALDOMAIN :\r$CDN\r\r";
        echo "bare domain for $DOMAIN is not a CDN load balancer IP!";
      else
        MAIL_BODY_DOMAINS_OK=$MAIL_BODY_DOMAINS_OK"===== $DOMAIN =====\r$REALDOMAIN A records OK\r$CDN\r\r";
        echo "bare domain for $DOMAIN is on a CDN load balancer IP!";
      fi

    else
      # If it's a subdomain, then we check CNAME
      CURRENTCNAME=`dig cname $REALDOMAIN +short`
      if [[ "$REALDOMAIN.cdn.cloudflare.net." == "$CURRENTCNAME" ]]; then
        MAIL_BODY_DOMAINS_OK=$MAIL_BODY_DOMAINS_OK"===== $DOMAIN =====\r$REALDOMAIN CNAME OK\r$CURRENTCNAME\r\r";
        echo "CNAME OK : $CURRENTCNAME"
      else
        MAIL_BODY_DOMAINS_NOK=$MAIL_BODY_DOMAINS_NOK"===== $DOMAIN =====\r";
        MAIL_BODY_DOMAINS_NOK=$MAIL_BODY_DOMAINS_NOK"$REALDOMAIN must be set to $REALDOMAIN.cdn.cloudflare.net.\r\r"
        echo "CNAME NOT OK : $CURRENTCNAME should be $REALDOMAIN.cdn.cloudflare.net."
      fi
    fi
  fi

done

# send the email report.
if [[ ${MAIL_TO} != "noalert" ]]; then
  MAIL_SUBJECT="[$AH_SITE_GROUP.$AH_SITE_ENVIRONMENT] - Origin Lockdown / Cloudflare configuration";
  MAIL_BODY=$MAIL_BODY$MAIL_BODY_DOMAINS_NOK"\r\r";
  MAIL_BODY=$MAIL_BODY"######################################\r"
  MAIL_BODY=$MAIL_BODY"# All these sites have correct setup #\r"
  MAIL_BODY=$MAIL_BODY"######################################\r\r"$MAIL_BODY_DOMAINS_OK"\r";
  echo -e "$MAIL_BODY" | mail -s "$MAIL_SUBJECT" "$MAIL_TO"
else
  # At this point, we probably are in testing mode, so output the result
  echo -e "$MAIL_BODY"
fi
)


