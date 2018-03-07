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
# Requirements : don't forget to include jq file as well in same directory
# https://stedolan.github.io/jq/
#
# RELEASES
# v0.1 : Init
# * Check bare domains against a single IP for all domains of a subscription, send report email.
#
# v0.2 : Updated on 2017/11/08 :
# * Checks correctly multi A records DNS configurations.
# * Report a list of all not yet configured domains with CDNs IPs that should be set.
# * Report a list of all well configured domains as verification purposes.
#
# Todo :
# * Add "Ignore patterns" as second argument,
# * Example : $ ./checkDNS.sh "thomas.lafon@acquia.com" "factory.nestleprofessional.com"
#
#
# edit me! / Share me!
#

# Retrieves the domains list
readonly SCRIPTS_BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
readonly SITES_JSON_FILE="/mnt/gfs/$AH_SITE_GROUP.$AH_SITE_ENVIRONMENT/files-private/sites.json";
readonly JQ="$SCRIPTS_BASE/jq";
# Pass email adresses as argument, default to noalert mecanism
readonly MAIL_TO=${1:-noalert};
readonly IGNORED_PATTERNS=${A:-nopattern};

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

# MAIN
echo "Scan bare domain $(date '+%d/%m/%Y %H:%M:%S')";
domain_list || { echo "something went wrong while getting site list.";exit 1; }

MAIL_BODY="Hello, find here the list of all bare domains NOT on a CDN load balancer IP:\n";
MAIL_BODY_DOMAINS_OK="";
MAIL_BODY_DOMAINS_NOK="";

(for DOMAIN in ${SITES[@]}
do
  # gather details
  if [ "${DOMAIN:0:3}" != 'www' ] && [ "${DOMAIN:0:7}" != 'preprod' ] && [ "${DOMAIN: -17}" != 'acsitefactory.com' ]; then
    echo "===== checking $DOMAIN ====="
    BAREIP=`dig a $DOMAIN +short`
    CDN=`dig $DOMAIN.cdn.cloudflare.net +short`

    # We first assume config is set correctly
    # If any DNS entry ip is not against a CDN load balancer
    # we invalidate the conf
    CONFIGOK=1
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

    echo "config : $CONFIGOK"
    if [[ $CONFIGOK -eq 0 ]]; then
      MAIL_BODY_DOMAINS_NOK=$MAIL_BODY_DOMAINS_NOK$DOMAIN"\r";
      MAIL_BODY_DOMAINS_NOK=$MAIL_BODY_DOMAINS_NOK"IPs should be "$CDN"\r";

      echo "bare domain for $DOMAIN is not a CDN load balancer IP!";
    else
      MAIL_BODY_DOMAINS_OK=$MAIL_BODY_DOMAINS_OK$DOMAIN"\r";
      echo "bare domain for $DOMAIN is on a CDN load balancer IP!";
    fi

    echo "";

  fi

done

# send the email report.
if [[ ${MAIL_TO} != "noalert" ]]; then
  MAIL_SUBJECT="[$AH_SITE_GROUP.$AH_SITE_ENVIRONMENT] - Bare Domains not on a CDN !!";
  MAIL_BODY=$MAIL_BODY$MAIL_BODY_DOMAINS_NOK"\r\r";
  MAIL_BODY=$MAIL_BODY"All these domains have correct setup:\r\r"$MAIL_BODY_DOMAINS_OK"\r";
  echo -e "$MAIL_BODY" | mail -s "$MAIL_SUBJECT" "$MAIL_TO"
else
  # At this point, we probably are in testing mode, so output the result
  echo -e "$MAIL_BODY"
fi
)