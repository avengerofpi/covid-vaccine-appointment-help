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
inLineXpath='//*[@id="lbHeaderP"]/text()';
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

In case you are not yet familiar with the Giant Foods scheduling interface, the
following advise is from my experience (updated early March):

If you are lucky enough to make it to the Enter Zip Codes page, you will need
to try out zip codes and hope you enter one with a Giant Foods with available
appointments nearby. Last I checked, it searches in a 10 mile radius, so you
will want to focus on Zip Codes that actually have Giant Foods stores that are
offering vaccine appointments. Based on research from early Feb, the list below
is what I work from.

After a certain number of zip codes are tried, you are kicked out of the
system. In my experience that cap is 10. The easiest way I have found to get
back in is starting fresh each time from a private/in-cognito browser session.

You will also need to login before you can schedule an actual appointment. If
you don't and if you are lucky enough to get to the "Click a Date > Click a
Time" calendar interface and the Time you click is still available by the time
you click it (there is a LOT of competition out there racing you), it will give
you some silly error message, redirect you to a login page, and then return you
to the Enter Zip Codes page after you have logged in. You will need to re-enter
the Zip Code (hopefully you remember the one that just worked for you...), and
hope that an appointment day/time that works for you is still available. 
  You may be able to defeat this frustration by logging in first. Last I
  checked, when you are on the Enter Zip Codes page, there is a Login button at
  the bottom of the screen; you may need to scroll down to see it. Good luck.

Zip Codes that might be worth searching (per research in early Feb (2021...)):
  20603 Waldorf
  20607 Accokeek
  20619 California
  20715 Bowie
  20747 District Heights
  20754 Dunkirk
  20774 Largo
  20782 Hyattsville
  20814 Bethesda
  20866 Burtonsville
  20878 Gaithersburg
  20906 Silver Spring
  21014 Belair
  21043 Ellicott City
  21061 Glen Burnie
  21075 Elkridge
  21093 Lutherville
  21157 Westminister
  21222 Dundalk
  21229 Baltimore
  21401 Annapolis
  21701 Frederick

Exerpts from latest response:
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
    if [[ ${waitTime} =~ '^[0-9]+$' ]] ; then
      sleepTime=$(( sleepTime + waitTime ));
    fi;
  fi;
}

# Main loop / program
while true; do
  sleepTime=1; # default sleep time (minutes)
  printDate;
  giantCovidCurl;
  giantCovidExtractMsg;
  sendEmailOnNonFailure;
  echo "Sleeping for ${sleepTime} minutes...";
  sleep "${sleepTime}m";
  echo;
done

