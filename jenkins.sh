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

# ==============================
# declare local properties
# ==============================
export JENKINS_SERVER_URL="YOUR_SERVER_URL_HERE"
export TEXT_BOLD=`tput bold`
export TEXT_NOMRAL=`tput sgr0`
export RED='\033[1;31m'
export GREEN='\033[0;33m'
export NC='\033[0m' # No Color

# ==============================
# declare functions
# ==============================

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
#
# References
# https://unix.stackexchange.com/a/415155
function select_option {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "  $2) $1 "; }
    print_selected()   { printf "$ESC[0;36m❯ $2) $1 $ESC[0m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    # key_input()      { this function has removed by Rondinelli Morais, replaced by `read -r -sn1 t` below }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt" "$idx"
            else
                print_option "$opt" "$idx"
            fi
            ((idx++))
        done

        # HEX        ASCII
        # 1b 5b 41   .[A # Up arrow
        # 1b 5b 42   .[B # Down arrow
        # 1b 5b 43   .[C # Right arrow
        # 1b 5b 44   .[D # Left arrow
        #  |  |  |
        #  |  |  +------ ASCII A, B, C and D
        #  |  +--------- ASCII [
        #  +------------ ASCII ESC
        #
        # https://stackoverflow.com/a/25065393
        read -r -sn1 t
        case $t in
            A)  ((selected--));
                if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;

            B)  ((selected++));
                if [ $selected -ge $# ]; then selected=0; fi;;

           "") break ;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

function bindArgs {

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

function init {

    if [ -d ~/.ssh ] || [ ${USE_AUTH} = true ]; then
        # list jobs when authentication is via ssh or user and password
        listJobs
    else
        showAuthenticationPrompt
    fi
}

function checkDependece {

    if [ ! -f "jenkins-cli.jar" ]; then
        
        echo -e "\n===== Downloading ${TEXT_BOLD}jenkins-cli.jar${TEXT_NOMRAL} file =====\n"
        
        # download jar
        curl ${JENKINS_SERVER_URL}/jnlpJars/jenkins-cli.jar -o jenkins-cli.jar -#
    fi
}

function listJobs {

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

function showJobs {

    declare -a user_option_jobs
    index=0

    echo -e "\n ${GREEN}${TEXT_BOLD}What job will we build?${TEXT_NOMRAL}${NC} \n"
    for job in ${jenkins_jobs}; do
        user_option_jobs[index]=${job}
        index=`echo "${index} + 1" | bc`
    done

    # show user the jobs on list
    select_option "${user_option_jobs[@]}" 
    jobname="${user_option_jobs[$?]}"

    # check if contains jenkins parameter
    if [[ ! -z "$PARAMETER_KEY" && ! -z "$PARAMETER_VALUE" ]]; then
        
        # build selected job
        buildJob $jobname

    else
        
        # check job has parameter
        showJobParameterQuestion $jobname
    fi
}

function buildJob {

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

function showHelp {

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
    echo -e "Twitter..: @rondmorais"
    echo -e "Email....: rondinellimorais@gmail.com"
    echo -e "Github...: github.com/rondinellimorais\n"
}

function showAuthenticationPrompt {

    echo -e "\n${GREEN}${TEXT_BOLD}Jenkins authentication:${TEXT_NOMRAL}${NC}\n"

    # USER is a global var
    while echo -n "     * Enter jenkins [ username ] : "; read -r USER;
    do
        if [ ! -z "${USER}" ]; then
            break
        fi
    done

    # PASSWORD is a global var
    while echo -n "     * Enter jenkins [ password ] : "; read -r -s PASSWORD;
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

function showJobParameterQuestion {

    while true; do

        echo -n -e "${GREEN}${TEXT_BOLD} Do you want to change the parameter values (if any)?${TEXT_NOMRAL}${NC}${TEXT_BOLD} [Y / n] : ${NC}"; read YES_NO_OPT
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

function showJobParameterPrompt {

    # feedback message
    echo -e "\nPlease wait...\n"

    # get data of job
    if [ ${USE_AUTH} = true ]; then
        # user authentication
        XMLStr=$(java -jar jenkins-cli.jar -noKeyAuth -s ${JENKINS_SERVER_URL} get-job $1 --username ${USER} --password ${PASSWORD})
    else
        # ssh authentication
        XMLStr=$(java -jar jenkins-cli.jar -s ${JENKINS_SERVER_URL} get-job $1)
    fi

    # check last command is success
    if [ $? != 0 ]; then
        echo
        exit 1
    fi

    # properties > hudson.model.ParametersDefinitionProperty > parameterDefinitions > name
    parameterTagPath="/project/properties/hudson.model.ParametersDefinitionProperty/parameterDefinitions/*/name"

    # xml parse
    result_command=`xmllint --nocdata --shell --xpath ${parameterTagPath} - <<<"${XMLStr}" | sed 's/<[^>]*>/ /g' | sed 's/[^aA-zZ]/ /g'`

    # check last command is success
    if [ $? == 0 ]; then

        for parameter in ${result_command}; do
        
            # PARAMETER_KEY is a global var
            PARAMETER_KEY=${parameter}

            # PARAMETER_VALUE is a global var
            while echo -n "     * Enter parameter value of the '$PARAMETER_KEY' : "; read -r PARAMETER_VALUE;
            do
                if [ ! -z "${PARAMETER_VALUE}" ]; then
                    break
                fi
            done;

            # check if contains jenkins parameter
            if [[ ! -z "$PARAMETER_KEY" && ! -z "$PARAMETER_VALUE" ]]; then
                USE_PARAMETER=true
            fi
        done
    fi

    # build job
    buildJob $1
}

# Jenkins pipeline start here.
# This script list e show the jobs on jenkins to build
#
#   author   : Rondinelli Morais
#   twitter  : @rondmorais
#   email    : rondinellimorais@gmail.com
#   github   : github.com/rondinellimorais

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





