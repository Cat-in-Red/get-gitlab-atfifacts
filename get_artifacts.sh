#!/bin/bash

# Скрипт принимает на вход имя джобы и возвращает последние ее артефакты от последнего успешного выполнения
# Требует jq, unzip


ERROR=""

ARTIFACT_FILE=${ARTIFACT_FILE:-"artifacts.zip"}

function _usage() {
   echo "${0##*/} <job name>"
}

function _get_artifacts() {
    local _job_name=$1

    local _resp=$(curl -sS -q -f -LL --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "${CI_API_V4_URL}/projects/$CI_PROJECT_ID/jobs?scope=success")
    if [[ -z $_resp  ]]; then
        return 1
    fi

    local _job_id=$(echo $_resp | jq --arg _job_name $_job_name '[.[] | select(.name == $_job_name)] |.[0].id')
    if [[ -z "$_job_id" || $_job_id == "null" ]]; then
        ERROR="Not found successfully jobs with name $_job_name"
        return 1
    fi

    local _status=$(curl -sS -q -LL -w "%{http_code}"  -o $ARTIFACT_FILE --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "${CI_API_V4_URL}/projects/$CI_PROJECT_ID/jobs/$_job_id/artifacts")
    if [ $_status != 200 ]; then
        ERROR="Can't download atrifacts from job $_job_id. HTTP status: $_status"
        return 1
    fi

    return 0
}


#############__main__#############
if [[ ! $# -eq 1 ]]; then
    _usage
    exit 1
fi

job_name=$1
echo "Downloading artifacts from last successfull job $job_name..."
_get_artifacts $job_name
if [ ! $? -eq 0 ]; then
    echo $ERROR
    exit 1;
fi

echo "Extracting artifacts"
unzip -o $ARTIFACT_FILE
_get_artifacts $job_name
if [ ! $? -eq 0 ]; then
    exit 1;
fi

rm $ARTIFACT_FILE
