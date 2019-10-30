#!/bin/bash
# This script runs the tests on Heroku CI
set -x

# Clone the Github repo to the right branch/commit to generate a .git folder for use in /app
git clone -b "$HEROKU_TEST_RUN_BRANCH" --single-branch https://github.com/SFDO-Tooling/CumulusCI 
cd CumulusCI
git reset --hard $HEROKU_TEST_RUN_COMMIT_VERSION
cd /app
mv CumulusCI/.git .

failed=0

# Run the CumulusCI Unit Tests
SFDX_CLIENT_ID="" coverage run `which pytest`
exit_status=$?
if [ "$exit_status" != "0" ]; then
    failed=1
fi

# Run the robot test suite
echo "------------------------------------------"
echo "Running Robot Framework library tests"
echo "------------------------------------------"

# Start TAP output
#echo "1...3"

export CUMULUSCI_KEYCHAIN_CLASS=cumulusci.core.keychain.EnvironmentProjectKeychain

# Create dev org
coverage run --append `which cci` org info dev > cci.log
coverage run --append `which cci` org default dev | tee cci.log

# Run CumulusCI Library Tests
coverage run --append `which cci` task run robot -o suites cumulusci/robotframework/tests/cumulusci | tee cci.log
exit_status=${PIPESTATUS[0]}
if [ "$exit_status" == "0" ]; then
    echo "ok 1 - Successfully ran CumulusCI Robot Library"
else
    echo "not ok 1 - Failed CumulusCI Robot Library: `tail -1 cci.log`"
    failed=1
fi

# Run Salesforce Library API Tests
coverage run --append `which cci` task run robot -o suites cumulusci/robotframework/tests/salesforce -o include api | tee cci.log
exit_status=${PIPESTATUS[0]}
if [ "$exit_status" == "0" ]; then
    echo "ok 2 - Successfully ran Salesforce Robot Library API"
else
    echo "not ok 2 - Failed Salesforce Robot Library API: `tail -1 cci.log`"
    failed=1
fi

# Run Salesforce Library UI Tests
coverage run --append `which cci` task run robot -o suites cumulusci/robotframework/tests/salesforce -o exclude api -o vars BROWSER:headlesschrome,CHROME_BINARY:$GOOGLE_CHROME_SHIM | tee cci.log
exit_status=${PIPESTATUS[0]}
if [ "$exit_status" == "0" ]; then
    echo "ok 3 - Successfully ran Salesforce Robot Library UI"
else
    echo "not ok 3 - Failed Salesforce Robot Library UI: `tail -1 cci.log`"
    failed=1
fi

# Delete the scratch org
coverage run --append `which cci` org scratch_delete dev | tee cci.log


# Clone the CumulusCI-Test repo to run test builds against it with cci
echo "------------------------------------------"
echo "Running test builds against CumulusCI-Test"
echo "------------------------------------------"
echo ""
echo "Cloning https://github.com/SFDO-Tooling/CumulusCI-Test"
git clone https://github.com/SFDO-Tooling/CumulusCI-Test
cd CumulusCI-Test
if [ "$HEROKU_TEST_RUN_BRANCH" == "master" ] ||\
   [[ "$HEROKU_TEST_RUN_BRANCH" == feature/* ]] ; then
    # Start TAP output
    echo "1...4"

    # Run ci_feature
    coverage run --append --source=../cumulusci `which cci` flow run ci_feature --org scratch --delete-org | tee cci.log
    exit_status=${PIPESTATUS[0]}
    if [ "$exit_status" == "0" ]; then
        echo "ok 1 - Successfully ran ci_feature"
    else
        echo "not ok 1 - Failed ci_feature: `tail -1 cci.log`"
        failed=1
    fi
        
    # Run ci_beta
    coverage run --append --source=../cumulusci `which cci` flow run ci_beta --org scratch --delete-org | tee -a cci.log
    exit_status=${PIPESTATUS[0]}
    if [ "$exit_status" == "0" ]; then
        echo "ok 4 - Successfully ran ci_beta"
    else
        echo "not ok 4 - Failed ci_beta: `tail -1 cci.log`"
        failed=1
    fi

    # Run ci_master
    coverage run --append --source=../cumulusci `which cci` flow run ci_master --org packaging | tee -a cci.log
    exit_status=${PIPESTATUS[0]}
    if [ "$exit_status" == "0" ]; then
        echo "ok 2 - Successfully ran ci_master"
    else
        echo "not ok 2 - Failed ci_master: `tail -1 cci.log`"
        failed=1
    fi

    # Run release_beta
    coverage run --append --source=../cumulusci `which cci` flow run release_beta --org packaging | tee -a cci.log
    exit_status=${PIPESTATUS[0]}
    if [ "$exit_status" == "0" ]; then
        echo "ok 3 - Successfully ran release_beta"
    else
        echo "not ok 3 - Failed release_beta: `tail -1 cci.log`"
        failed=1
    fi

fi

# Combine the CumulusCI-Test test coverage with the nosetest coverage
echo "Combining .coverage files"
cd ..
coverage combine .coverage CumulusCI-Test/.coverage

# Record to coveralls.io
coveralls

exit $failed
