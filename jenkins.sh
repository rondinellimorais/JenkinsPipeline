#!/bin/bash

# ============================================================
# Color

# Black        0;30     Dark Gray     1;30
# Red          0;31     Light Red     1;31
# Green        0;32     Light Green   1;32
# Brown/Orange 0;33     Yellow        1;33
# Blue         0;34     Light Blue    1;34
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37

# ============================================================
#local properties
export JENKINS_SERVER_URL="YOUR_SERVER_URL_HERE"
export TEXT_BOLD=`tput bold`
export TEXT_NOMRAL=`tput sgr0`
export RED='\033[1;31m'
export GREEN='\033[0;33m'
export NC='\033[0m' # No Color

bindArgs() {

    # vars of arguments
    export USER
    export PASSWORD
    export PARAMETER_KEY
    export PARAMETER_VALUE
    export USE_AUTH=false
    export SHOW_HELP=false
    export USE_PARAMETER=false

    while getopts u:p:s:k:v:h option
    do
        case "${option}"
        in
            u) USER=${OPTARG};;
            p) PASSWORD=${OPTARG};;
            s) JENKINS_SERVER_URL=${OPTARG};;
            k) PARAMETER_KEY=${OPTARG};;
            v) PARAMETER_VALUE=${OPTARG};;
            h) SHOW_HELP=true;;
            *) SHOW_HELP=true;; # default value
     esac
    done

    # debug
    # ===============
    # echo "jenkin url: ${JENKINS_SERVER_URL}"
    # echo "user: ${USER}"
    # echo "password: ${PASSWORD}"
    # echo "show help?: ${SHOW_HELP}"
    # exit 0

    # show help
    if [ ${SHOW_HELP} = true ]; then
        showHelp
        exit 0
    fi

    # check if authentication is enable
    if [[ ! -z "$USER" && ! -z "$PASSWORD" ]]; then
        USE_AUTH=true
    else
        USE_AUTH=false
    fi

    # check if contains jenkins parameter
    if [[ ! -z "$PARAMETER_KEY" && ! -z "$PARAMETER_VALUE" ]]; then
        USE_PARAMETER=true
    else
        USE_PARAMETER=false
    fi
}

init(){

    if [ -d ~/.ssh ] || [ ${USE_AUTH} = true ]; then
        # list jobs when authentication is via ssh or user and password
        listJobs
    else
        showAuthenticationPrompt
    fi
}

checkDependece(){

    if [ ! -f "jenkins-cli.jar" ]; then
        
        echo -e "\n===== Downloading ${TEXT_BOLD}jenkins-cli.jar${TEXT_NOMRAL} file =====\n"
        
        # download jar
        curl ${JENKINS_SERVER_URL}/jnlpJars/jenkins-cli.jar -o jenkins-cli.jar -#
    fi
}

listJobs(){

    # check if dependeces is install
    checkDependece

    # list jenkins jobs
    if [ ${USE_AUTH} = true ]; then
        # user authentication
        jenkins_jobs=$(java -jar jenkins-cli.jar -noKeyAuth -s ${JENKINS_SERVER_URL} list-jobs --username ${USER} --password ${PASSWORD})
    else
        # ssh authentication
        jenkins_jobs=$(java -jar jenkins-cli.jar -s ${JENKINS_SERVER_URL} list-jobs)
    fi

    # check if jobs is valid
    if [ -z "$jenkins_jobs" ]; then
        echo -e "\n ${RED}${TEXT_BOLD} No jenkins jobs available! ${TEXT_NOMRAL}${NC} \n"
        exit 0
    fi

    #show jenkins jobs
    showJobs
}

showJobs(){

    declare -a user_option_jobs
    index=0

    echo -e "\n ${GREEN}${TEXT_BOLD}What job will we build?${TEXT_NOMRAL}${NC} \n"
    for job in ${jenkins_jobs}; do
        user_option_jobs[index]=${job}
        index=`echo "${index} + 1" | bc`
    done

    # show user the jobs on list
    select opt in "${user_option_jobs[@]}" 
    do
        if [ ! -z "$opt" ]; then

            # check if contains jenkins parameter
            if [[ ! -z "$PARAMETER_KEY" && ! -z "$PARAMETER_VALUE" ]]; then
                
                # build selected job
                buildJob $opt

            else
                
                # check job has parameter
                showJobParameterQuestion $opt
            fi

            break
        else 
            case $opt in
                *) echo invalid option, try again:;;
            esac
        fi
    done
}

buildJob(){

    job=$1
    echo -e "\n===== Building job ${TEXT_BOLD}${job} ${TEXT_NOMRAL} =====\n"
    
    # command for build job
    declare -a  JENKINS_COMMAND
    JENKINS_COMMAND[${#JENKINS_COMMAND[@]}]="java -jar jenkins-cli.jar"

    # ==============================
    # authentication method
    # ==============================
    if [ ${USE_AUTH} = true ]; then
        # user authentication
        JENKINS_COMMAND[${#JENKINS_COMMAND[@]}]=" -noKeyAuth -s ${JENKINS_SERVER_URL} build ${job} --username ${USER} --password ${PASSWORD} "
    else
        # ssh authentication
        JENKINS_COMMAND[${#JENKINS_COMMAND[@]}]=" -s ${JENKINS_SERVER_URL} build ${job} "
    fi

    # ==============================
    # jenkins parameter
    # ==============================
    if [ ${USE_PARAMETER} = true ]; then
        JENKINS_COMMAND[${#JENKINS_COMMAND[@]}]=" -p ${PARAMETER_KEY}=${PARAMETER_VALUE} "
    fi

    # end of command
    JENKINS_COMMAND[${#JENKINS_COMMAND[@]}]=" -w "

    # result of jebkins command
    # echo "jenkins command: ${JENKINS_COMMAND[@]}"
    build_result=`echo ${JENKINS_COMMAND[@]} | bash`

    # http://www.iemoji.com/view/emoji/784/objects/wrench
    # echo -e "\xF0\x9F\x94\xA8 \xF0\x9F\x94\xA7"
    
    # command for show console
    # java -jar jenkins-cli.jar -s ${JENKINS_SERVER_URL} console ${job} -f

    # show link to log
    build_number=`echo ${build_result} | sed 's/[^0-9]//g'`

    echo -e "\n===== ${TEXT_BOLD} View output log the link below ${TEXT_NOMRAL} =====\n"
    printf "${TEXT_BOLD} \t\e[3;4;33m${JENKINS_SERVER_URL}/job/${job}/${build_number}/console\n\e[0m ${TEXT_NOMRAL}\n\n"
    echo -e "Great! \xF0\x9F\x8D\xBA\n\n"
}

showHelp(){

    # usage
    echo -e "usage: ./jenkins [options...]\n"
    echo -e "${GREEN}${TEXT_BOLD}VALID OPTIONS ARE:${TEXT_NOMRAL}${NC}\n"
    echo -e "   -u  Username jenkins. Use with -p"
    echo -e "   -p  Password of the user jenkins. Use with -u"
    echo -e "   -h  help :)"
    echo -e "   -k  Jenkins parameter name. Use with -v"
    echo -e "   -v  Jenkins parameter value. Use with -k"
    echo -e "   -s  To specify jenkins URL. (We recomend edit script e chenge var JENKINS_SERVER_URL)\n"
    echo -e "When -u or -p is not specified, the script use ${TEXT_BOLD}ssh public key${TEXT_NOMRAL} \n"

    # ssh public key authentication
    echo -e "${GREEN}${TEXT_BOLD}SSH PUBLIC KEY AUTHENTICATION:${TEXT_NOMRAL}${NC}\n"
    echo -e "You need create the ssh key. Just follow this commands:\n"
    echo -e "   1. ssh-keygen -t rsa"
    echo -e "   2. cat ~/.ssh/id_rsa.pub"
    echo -e "   3. Copy the resulting public key into the SSH keys section on Jenkins \n"

    # support
    echo -e "${GREEN}${TEXT_BOLD}CONTACT:${TEXT_NOMRAL}${NC}\n"
    echo -e "Author...: Rondinelli Morais"
    echo -e "Twitter..: @rmorais"
    echo -e "Email....: rondinellimorais@gmail.com\n"
}

showAuthenticationPrompt() {

    echo -e "\n${GREEN}${TEXT_BOLD}Jenkins authentication:${TEXT_NOMRAL}${NC}\n"

    # USER is a global var
    while echo -n "     * ${TEXT_BOLD} Enter jenkins [ username ] : ${TEXT_NOMRAL}"; read -r USER;
    do
        if [ ! -z "${USER}" ]; then
            break
        fi
    done

    # PASSWORD is a global var
    while echo -n "     * ${TEXT_BOLD} Enter jenkins [ password ] : ${TEXT_NOMRAL}"; read -r -s PASSWORD;
    do
        echo "" # new line
        if [ ! -z "${PASSWORD}" ]; then
            break
        fi
    done

    # check if authentication is enable
    if [[ -n "$USER" && -n "$PASSWORD" ]]; then
        USE_AUTH=true
    else
        USE_AUTH=false
    fi

    # feedback message
    echo -e "\nPlease wait..."

    # list jobs
    listJobs
}

showJobParameterQuestion(){

    echo "" # new build
    while true; do

        echo -n -e "${GREEN}${TEXT_BOLD}Does '$1' have any parameters?${TEXT_NOMRAL}${NC}${TEXT_BOLD} [Y / n] : ${NC}"; read YES_NO_OPT
        case $YES_NO_OPT in
            [Yy]* ) 
                showJobParameterPrompt $1
                break;;

            [Nn]* ) 
                buildJob $1;;
                * ) ;;
        esac
    done
}

showJobParameterPrompt(){

    # PARAMETER_KEY is a global var
    echo "" # new line
    while echo -n "     * ${TEXT_BOLD} Enter '$1' parameter name : ${TEXT_NOMRAL}"; read -r PARAMETER_KEY;
    do
        if [ ! -z "${PARAMETER_KEY}" ]; then
            break
        fi
    done;

    # PARAMETER_VALUE is a global var
    while echo -n "     * ${TEXT_BOLD} Enter parameter value of the '$PARAMETER_KEY' : ${TEXT_NOMRAL}"; read -r PARAMETER_VALUE;
    do
        if [ ! -z "${PARAMETER_VALUE}" ]; then
            break
        fi
    done;

    # check if contains jenkins parameter
    if [[ ! -z "$PARAMETER_KEY" && ! -z "$PARAMETER_VALUE" ]]; then
        USE_PARAMETER=true
    fi

    # build job
    buildJob $1
}

# check args
bindArgs $@

# dont replace 'YOUR_SERVER_URL_HERE' string below
if [ "$JENKINS_SERVER_URL" == "YOUR_SERVER_URL_HERE" ]; then
    echo -e "${RED}${TEXT_BOLD}'YOUR_SERVER_URL_HERE' is not valid URL! Please, edit jenkins script or use the option -s YOU_JENKINS_SERVER_URL ${TEXT_NOMRAL}${NC} \n"
    exit 1
else
    # start script
    init
fi





