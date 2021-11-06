#!/bin/bash
# You may add your name if you have contributed to this file.
echo -ne "
    ╔══════════════════════════════════════╗
    ║                                      ║
    ║ Linux/MacOS Translation utility 1.0  ║
    ║     Powered by David Copperfield     ║
    ║           A MuseScore User           ║
    ║                                      ║
    ╚══════════════════════════════════════╝\n\n"
# Functions
function Countdown() { # Countdown timer, format: Countdown [time in sec]
    _countdown=$1
    while [[ $_countdown -gt 0 ]]; do
        echo -ne "The programme will exit in $_countdown sec."
        ((_countdown--))
        sleep 1 #time interval
        echo -ne "\r"
    done
}
function Confirmation() { # Process Yes/No/Quit response
    while :; do
        echo -e "Confirm? (y/n) "
        read
        case ${REPLY} in
        [Yy]* | [Oo][Kk] | 1) # Approved
            return 3
            ;;
        [Qq]uit* | [Ee]sc* | [Ee]xit | -1) # Leave
            Countdown 5
            exit
            ;;
        "") # Avoid mis-press the Enter
            continue
            ;;
        *) # Not confirmed
            return
            ;;
        esac
    done
}
# Functions End

# ===== Modules ====
Check_bin() {                             #Check if the bin path exists
    bin_path=$HOME/Qt/5.15.2/clang_64/bin # Default bin path

    until [[ -d $bin_path ]]; do # Find the default bin path
        echo =========
        echo -e "\033[31mPath to lupdate not found.\033[0m"
        echo -e "Please provide a path to /Qt/(version)/clang_64/bin."
        read bin_path
    done

    export PATH="$PATH":$bin_path # Set user defined bin path
}
Lupdate() { # Generating/Updating .ts files
    while :; do
        read -rp "Input your language code: "
        case $REPLY in
        \* | all) # Update all existed .ts files
            ts_name=$(find . -name "*.ts")
            echo -e "You are updating\033[33m all existed .ts files\033[0m."
            ;;
        "") # Avoid mis-press the Enter
            continue
            ;;
        *)
            ts_name=./locale_${REPLY}.ts
            # ts_name+=$REPLY
            echo -e "Your ts file name is \033[33m${ts_name}\033[0m"
            ;;
        esac
        Confirmation
        if [[ $? -eq 3 ]]; then break; fi
    done
    echo Generating ${ts_name}
    cd $(dirname $0)
    lupdate -locations relative -no-obsolete ../ -ts ${ts_name}
    return
}

Lrelease() { # Generating/Updating .qm files
    cd $(dirname $0)
    echo lrelease *.ts
    lrelease -nounfinished *.ts
    return
}
# Module End
###########
Main() {
    Check_bin
    while :; do
        echo -e "Choose the mode:\n1. Generate .ts files.\n2. Update .qm files."
        read
        case $REPLY in
        1 | lupdate)
            Lupdate
            break
            ;;
        2 | lrelease)
            Lrelease
            break
            ;;
        [Qq]uit* | [Ee]sc* | [Ee]xit | -1)
            exit
            ;;
        *)
            continue
            ;;
        esac
    done
    sleep 1
    echo -e "\033[32mFinished\033[0m"
    Countdown 10
    exit
}
Main
