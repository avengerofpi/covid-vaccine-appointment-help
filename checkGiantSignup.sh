#!/bin/bash

outFile=output.html;
emailFile=email-msg.txt;
distroFile=distro.config;
responseSamplesDir=response-samples;

# Call Giant website link to check for open slots. Follow redirects (--location),
# Silent output except for errors (-sS), and write to specified file (--output).
url='https://giantfoodsched.rxtouch.com/rbssched/program/covid19/Patient/Advisory';
function giantCovidCurl() {
  curl "${url}" -sS --location --output ${outFile};
}

# Process output HTML (XHTML?) file to try to extract the relevant msg field(s).
noAppointmentsAvailableXpath='/html/body/table/tbody/tr[2]/td/table/tbody/tr/td/div/div/h2/span/span/text()';
inLineXpath='//*[@id="lbHeaderP"]/text()'
waitTimeXpathA='//*[@id="MainPart_lbWhichIsInText"]/text()';
waitTimeXpathB='//*[@id="MainPart_lbWhichIsIn"]/text()';
downXpathA='/html/body/div/div[1]/h2/text()';
downXpathB='/html/body/div/div[1]/p/text()';
function giantCovidExtractMsg() {
  responseMsg="`xmllint --html --xpath ${noAppointmentsAvailableXpath} ${outFile} 2> /dev/null`";
  inLineResponseMsg="`xmllint --html --xpath ${inLineXpath} ${outFile} 2> /dev/null`";
  waitTimeMsgA="`xmllint --html --xpath ${waitTimeXpathA} ${outFile} 2> /dev/null`";
  waitTimeMsgB="`xmllint --html --xpath ${waitTimeXpathB} ${outFile} 2> /dev/null`";
  downMsgA="`xmllint --html --xpath ${downXpathA} ${outFile} 2> /dev/null`";
  downMsgB="`xmllint --html --xpath ${downXpathB} ${outFile} 2> /dev/null`";

  # Combine waitTime parts, and trim white space (make empty string if only whitespace)
  waitTimeMsg="${waitTimeMsgA} ${waitTimeMsgB}";
  waitTimeMsg=$(echo "${waitTimeMsg}" | sed -e 's@\(^\s*\|\s*$\)@@g');

  # Combine down parts, and trim white space (make empty string if only whitespace)
  downMsg="${downMsgA} ${downMsgB}";
  downMsg=$(echo "${downMsg}" | sed -e 's@\(^\s*\|\s*$\)@@g');

  # Helpful logging
  echo "'${responseMsg}'";
  echo "'${inLineResponseMsg}'";
  echo "'${waitTimeMsg}'";
  echo "'${downMsg}'";

  # Save copy of response file if all extracts are blank
  concatExtracts="${responseMsg}${inLineResponseMsg}${waitTimeMsg}${downMsg}";
  if [ -z "${concatExtracts}" ]; then
    backupOutFile="`date +%F--%Hh%Mm%Ss`-${outFile}";
    backupOutPath="${responseSamplesDir}/${backupOutFile}";
    cp "${outFile}" "${backupOutPath}";
  fi;
}

# Print date, with color!
export BOLD_YELLOW="$(tput bold)$(tput setaf 11)";
export TPUT_RESET="$(tput sgr0)";
function printDate() {
  echo "${BOLD_YELLOW}`date`:${TPUT_RESET}";
}

# Write a email message to file, to be sent via `ssmpt`
function writeEmailMsgToFile() {
  cat > ${emailFile} << EOF
Subject: Giant Vaccine Appointments Might Be Available - "${waitTimeMsg}"

There MIGHT be vaccine appointments available at Giant now.
Check out link: ${url}

Exerpt from from last call attempt:
  "${responseMsg}"
  "${inLineResponseMsg}"
  "${waitTimeMsg}"
  "${downMsg}"
EOF
}

# Expected "no appointments available" response msg
function sendEmailOnNonFailure() {
  if [ -n "${inLineResponseMsg}" ]; then
    writeEmailMsgToFile;

    # Update the distro from file
    source "${distroFile}";

    # Send notification to each recipient in the distro
    for recipient in ${distro}; do
      ssmtp ${recipient}  < ${emailFile};
      echo "  msg sent to ${recipient}";
    done;
    #echo "hello world" | ssmtp -vvv email@domain

    # Adjust sleep time to be some default + estimated sleep time from the latest response
    #   waitTimeMsgB (if not empty) is expected to be of the form 'n minutes' or 'less than a minute'
    # Default/minimum sleep (after a valid response)
    sleepTime=20;
    # Try to parse and add estimated wait time
    waitTime=${waitTimeMsgB};
    waitTime=${waitTime/ minutes/};
    if ! [[ ${waitTime} =~ '^[0-9]+$' ]] ; then
      sleepTime=$(( sleepTime + waitTime ));
    fi;
  fi;
}

# Main loop / program
while true; do
  sleepTime=1; # default sleep time (minutes)
  printDate;
  echo -n "  ";
  giantCovidCurl;
  giantCovidExtractMsg;
  sendEmailOnNonFailure;
  echo "Sleeping for ${sleepTime} minutes...";
  sleep "${sleepTime}m";
  echo;
done

