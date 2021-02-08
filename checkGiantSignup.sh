#!/bin/bash

outFile=output.html;

# Call Giant website link to check for open slots. Follow redirects (--location),
# Silent output except for errors (-sS), and write to specified file (--output).
url='https://giantfoodsched.rxtouch.com/rbssched/program/covid19/Patient/Advisory';
function giantCovidCurl() {
  curl "${url}" -sS --location --output ${outFile};
}

# Process output HTML (XHTML?) file to try to extract the relevant msg field(s).
# Right now I only know what the (current) "no appointments available" msg looks like.
noAppointmentsAvailableXpath='/html/body/table/tbody/tr[2]/td/table/tbody/tr/td/div/div/h2/span/span/text()';
inLineXpath='//*[@id="lbHeaderP"]/text()'
function giantCovidExtractMsg() {
  responseMsg="`xmllint --html --xpath ${noAppointmentsAvailableXpath} ${outFile} 2> /dev/null`";
  inLineResponseMsg="`xmllint --html --xpath ${inLineXpath} ${outFile} 2> /dev/null`";
  echo ${responseMsg};
  echo ${inLineResponseMsg};
}

# Print date, with color!
export BOLD_YELLOW="$(tput bold)$(tput setaf 11)";
export TPUT_RESET="$(tput sgr0)";
function printDate() {
  echo "${BOLD_YELLOW}`date`:${TPUT_RESET}";
}

# Write a email message to file, to be sent via `ssmpt`
emailFile=email-msg.txt;
function writeEmailMsgToFile() {
  cat > ${emailFile} << EOF
Subject: Giant Vaccine Appointments Might Be Available

There MIGHT be vaccine appointments available at Giant now.
Check out link: ${url}

Exerpt from from last call attempt:
  "${responseMsg}"
  "${inLineResponseMsg}"
EOF
}

# Expected "no appointments available" response msg
failureResponseMsg="There are currently no COVID-19 vaccine appointments available. Please check back later. We appreciate your patience as we open as many appointments as possible. Thank you.";
function sendEmailOnNonFailure() {
  if [ "${responseMsg}" != "${failureResponseMsg}" ]; then
    writeEmailMsgToFile;
    ssmtp -vvv email@domain < ${emailFile};
    ssmtp -vvv email@domain < ${emailFile};
    ssmtp -vvv email@domain < ${emailFile};
    #echo "hello world" | ssmtp -vvv email@domain
    sleep $((60 * 5)); # some extra sleep
  fi;
}

# Main loop / program
while true; do
  printDate;
  echo -n "  ";
  giantCovidCurl;
  giantCovidExtractMsg;
  sendEmailOnNonFailure;
  echo;
  sleep 60;
done

