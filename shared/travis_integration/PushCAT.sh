#!/usr/bin/env bash

rsc_cmd="./rsc -h ${RS_HOST} -a ${RS_ACCOUNT} -r ${RS_TOKEN}"
  
# Get the schedule for publishing.
schedule_id=$(${rsc_cmd} --xm ':has(.name:val("Business Hours"))>.id' ss index /designer/collections/$RS_ACCOUNT/schedules | sed 's/"//g')
if [[ -z "$schedule_id" ]]
then
    echo "Need Business Hours schedule. "
    exit 1
fi
    
# Process the changed files and publish those that should be uploaded and published.
for cat_filename in ${CHANGED_FILES}
do
    # Only upload and publish files in the Travis_CATs folder
    if [[ ${cat_filename} = *Travis_CATs* ]]
    then
        cat_name=$(sed -n -e "s/^name[[:space:]]['\"]*\(.*\)['\"]/\1/p" $cat_filename)
        echo "Checking to see if ($cat_name - $cat_filename) has already been uploaded..."
        cat_href=$(${rsc_cmd} ss index collections/$RS_ACCOUNT/templates "filter[]=name==$cat_name" | jq -r '.[0].href')
            
        if [[ -z "$cat_href" ]]
        then
            echo "($cat_name - $cat_filename) not already uploaded, creating it now..."
            ${rsc_cmd} ss create collections/$RS_ACCOUNT/templates source=$cat_filename
        else
            echo "($cat_name - $cat_filename) already uploaded, updating it now..."
            ${rsc_cmd} ss update $cat_href source=$cat_filename
        fi
            
        echo "Checking to see if ($cat_name - $cat_filename) has already been published ..."
        catalog_href=$(${rsc_cmd} ss index /api/catalog/catalogs/$RS_ACCOUNT/applications | jq ".[] | select(.name==\"$cat_name\") | .href" | sed 's/"//g')

        if [[ -z "$catalog_href" ]]
        then
          echo "($cat_name - $cat_filename) not already published, publishing it now..."
          # Publish the CAT
          ${rsc_cmd} ss publish /designer/collections/${RS_ACCOUNT}/templates id="${cat_href}" schedules[]=${schedule_id}
        else
          echo "($cat_name - $cat_filename) already published, updating it now..."
          ${rsc_cmd} ss publish /designer/collections/${RS_ACCOUNT}/templates id="${cat_href}" schedules[]=${schedule_id} overridden_application_href="${catalog_href}"
        fi
    else 
        echo "Found file that is not a Travis CAT file: ${cat_filename} - No action taken."
    fi
done

