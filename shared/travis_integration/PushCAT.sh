#!/usr/bin/env bash
set -e
export RIGHT_ST_LOGIN_ACCOUNT_ID=$RS_ACCOUNT
export RIGHT_ST_LOGIN_ACCOUNT_HOST=$RS_HOST
export RIGHT_ST_LOGIN_ACCOUNT_REFRESH_TOKEN=$RS_TOKEN

rsc_cmd="./rsc -h ${RS_HOST} -a ${RS_ACCOUNT} -r ${RS_TOKEN}"

# Only push files that are updated in the "Travis_CATs" folder.
CHANGED_FILES=`git diff --name-only $TRAVIS_COMMIT_RANGE | grep "Travis_CATs"`

if [ ! -z $CHANGED_FILES ]
then
    
    for cat_filename in ${CHANGED_FILES}
    do
        cat_name=$(sed -n -e "s/^name[[:space:]]['\"]*\(.*\)['\"]/\1/p" $cat_filename)
        echo "Checking to see if ($cat_name - $cat_filename) has already been uploaded..."
        cat_href=$(${rsc_cmd} ss index collections/$ACCOUNT_ID/templates "filter[]=name==$cat_name" | jq -r '.[0].href')
        
        if [[ -z "$cat_href" ]]
        then
            echo "($cat_name - $cat_filename) not already uploaded, creating it now..."
            ${rsc_cmd} ss create collections/$ACCOUNT_ID/templates source=$cat_filename
        else
            echo "($cat_name - $cat_filename) already uploaded, updating it now..."
            ${rsc_cmd} ss update $cat_href source=$cat_filename
        fi
    done
else
    echo "No Travis CAT file changes found."
    echo "Files that were changed: ${CHANGD_FILES}"
fi


#${rsc_cmd} ss index /api/catalog/catalogs/${RS_ACCOUNT}/applications

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
