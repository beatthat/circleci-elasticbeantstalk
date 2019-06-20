#!/usr/bin/env bash

usage () {
    echo $"
Usage: $0 docker-account 
        [-b build-directory] 
        [-o output-properties] 
        [-p docker-repo-prefix] 
        [-r registry]  
        [-s services-directory] 
        [-t tag]
        [-u account] 
    build|push|push-local|print-service-tag <service_name>
"
}

cannonical () {
  local s=${1}
  s=$(echo ${s} | tr [:upper:] [:lower:])
  s=$(echo ${s} | perl -pe 's/[^a-zA-Z0-9\-\n]+/-/g')
  echo ${s}
}

service_tag () {
  local service_name=$1
  img=${DOCKER_REGISTRY_PREFIX}${DOCKER_ACCOUNT_PREFIX}${DOCKER_REPO_PREFIX}-${service_name}:${DOCKER_TAG}
  echo ${img}
}

ORIGINAL_CALL="$0 $@"
BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PWD="$(pwd)"
PROJECT_ROOT=${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2> /dev/null)}
PROJECT_NAME=${PROJECT_NAME:-${PROJECT_ROOT##*/}}
SERVICES_ROOT=${PROJECT_ROOT}/services
BUILD_DIR=${PWD}/build
DOCKER_REPO=$(cannonical ${PROJECT_NAME})
DOCKER_REPO_PREFIX=${DOCKER_REPO}
DOCKER_TAG=latest
DOCKER_REGISTRY=""
DOCKER_REGISTRY_PREFIX=""
DOCKER_ACCOUNT=""
DOCKER_ACCOUNT_PREFIX=""

source ${BIN}/lib/getopts_long.bash

while getopts_long ":t:s:p:o:u:r:b: account: build-dir: docker-repo-prefix: services-root: tag:" OPT_KEY; do
  case ${OPT_KEY} in
    'b' | 'build-dir' )
      BUILD_DIR=${OPTARG}
      ;;
    's' | 'services-root' )
      SERVICES_ROOT=${OPTARG}
      ;;
    't' | 'tag' )
      DOCKER_TAG=${OPTARG}
      ;;
    'p' | 'docker-repo-prefix' )
      DOCKER_REPO=${OPTARG}
      DOCKER_REPO_PREFIX=${DOCKER_REPO}
      ;;
    'o' )
      OUTPUT_PROPERTIES=${OPTARG}
      ;;
    'u' | 'account' )
      DOCKER_ACCOUNT=${OPTARG}
      DOCKER_ACCOUNT_PREFIX="${DOCKER_ACCOUNT}/"
      ;;
    'r' | 'registry' )
      DOCKER_REGISTRY=${OPTARG}
      DOCKER_REGISTRY_PREFIX="${DOCKER_REGISTRY}/"
      ;;
    '?' )
      echo "Invalid option: ${OPTARG}" 1>&2
      ;;
    ':' )
      echo "Invalid option: ${OPTARG} requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

CMD=$1; shift;

case "$CMD" in
        print-service-tag)
            service_name=${1}
            if [ "${service_name}" = "" ]; then
              echo "command 'print-service-tag' requires a <service_name> argument"
              usage
              exit 1
            fi
            st=$(service_tag ${service_name})
            echo ${st}
            ;;

        build)
            cd $SERVICES_ROOT 
            for d in */; do
                service_name=${d%/}
                img=$(service_tag ${service_name})
                cd ${SERVICES_ROOT}/${d} && \
                    DOCKER_IMAGE=${img} DOCKER_ACCOUNT=${DOCKER_ACCOUNT} DOCKER_REPO=${DOCKER_REPO} DOCKER_TAG=${DOCKER_TAG} make docker-build
            done
            ;;
        
        push)
            cd $SERVICES_ROOT 
            for d in */; do
                service_name=${d%/}
                img=$(service_tag ${service_name})
                docker push ${img}
            done
            ;;
        
        properties)
            cd $SERVICES_ROOT 
            if [ -z "${OUTPUT_PROPERTIES}" ]; then
              OUTPUT_PROPERTIES=${BUILD_DIR}/config/docker_services.properties
            fi
            mkdir -p $(dirname ${OUTPUT_PROPERTIES})
            echo "# generated by ${ORIGINAL_CALL}" > ${OUTPUT_PROPERTIES}
            for d in */; do
                service_name=${d%/}
                tag=$(service_tag ${service_name})
                echo "${service_name}=${tag}" >> ${OUTPUT_PROPERTIES}
            done
            echo "" >> ${OUTPUT_PROPERTIES}
            ;;

        *)
            usage
            exit 1
 
esac