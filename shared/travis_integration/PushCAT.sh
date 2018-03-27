#!/usr/bin/env bash
set -e
export RIGHT_ST_LOGIN_ACCOUNT_ID=$RS_ACCOUNT
export RIGHT_ST_LOGIN_ACCOUNT_HOST=$RS_HOST
export RIGHT_ST_LOGIN_ACCOUNT_REFRESH_TOKEN=$RS_TOKEN

rsc_cmd="./rsc -h ${RS_HOST} -a ${RS_ACCOUNT} -r ${RS_TOKEN}"

echo ${rsc_cmd}

${rsc_cmd} ss index /api/catalog/catalogs/${RS_ACCOUNT}/applications

#${rsc_cmd} cm15 by_tag /api/tags/by_tag "resource_type=instances" "tags[]=devops:servertype=webserver" | \
#jq '.[] | { links: .links[].href}' |  \
#grep links | \
#cut -d":" -f2 | sed 's/"//g' |
#while read instance_href
#do
#        ${rsc_cmd} --dump=debug cm15 run_executable ${instance_href} "right_script_href=${right_script_href}" \
#        "inputs[][name]=APPLICATION_REPO" \
#        "inputs[][value]=text:https://github.com/$TRAVIS_REPO_SLUG.git" # GIT_URL is an environment variable set by Jenkins server
#done
