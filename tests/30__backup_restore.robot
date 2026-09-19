*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Test Cases ***
Remember the server identity
    ${out} =    Run on node    curl -fsSk -H 'Host: plex.ci.test' https://127.0.0.1/identity | grep -o 'machineIdentifier="[^"]*"'
    Set Global Variable    ${MACHINE_ID}    ${out.strip()}

Back up the module
    ${repo}    ${path} =    Back up the module to the cluster repository    ${module_id}
    Set Global Variable    ${BACKUP_REPO}    ${repo}
    Set Global Variable    ${BACKUP_PATH}    ${path}

Remove the original instance
    Run on node    remove-module --no-preserve ${module_id}

Restore into a new instance
    ${rid} =    Restore the module from the cluster repository    ${BACKUP_REPO}    ${BACKUP_PATH}
    Set Global Variable    ${restored_id}    ${rid}
    Set Global Variable    ${module_id}    ${rid}

The restored server keeps its identity and settings
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be Equal    ${cfg['host']}    plex.ci.test
    Should Be Equal    ${cfg['timezone']}    Europe/Berlin
    Should Contain    ${cfg['media_paths']}    /srv/ci-media
    ${out} =    Wait Until Keyword Succeeds    90 times    10 seconds
    ...    Run on node    curl -fsSk -H 'Host: plex.ci.test' https://127.0.0.1/identity
    Should Contain    ${out}    ${MACHINE_ID}
