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
function giantCovidExtractMsg() {
  xmllint --html --xpath ${noAppointmentsAvailableXpath} ${outFile};
}

# Print date, with color!
export BOLD_YELLOW="$(tput bold)$(tput setaf 11)";
export TPUT_RESET="$(tput sgr0)";
function printDate() {
  echo "${BOLD_YELLOW}`date`:${TPUT_RESET}";
}

while true; do
  printDate;
  echo -n "  ";
  giantCovidCurl;
  giantCovidExtractMsg;
  echo;
  echo;
  sleep 60;
done

