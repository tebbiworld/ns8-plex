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

Stop the original instance
    # Stopped, not removed: on Rocky 9 (systemd 252) a module removed and re-created
    # within seconds gets the same UID back, the user manager for that UID is not
    # started again and the agent of the new instance never comes up.
    Run on node    runagent -m ${module_id} bash -c 'systemctl --user list-unit-files --state=enabled --no-legend "*.service" "*.timer" | cut -d" " -f1 | xargs -r systemctl --user disable --now'

Restore into a new instance
    ${rid} =    Restore the module from the cluster repository    ${BACKUP_REPO}    ${BACKUP_PATH}
    Set Global Variable    ${restored_id}    ${rid}
    Should Not Be Equal    ${restored_id}    ${module_id}

The restored server keeps its identity and settings
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be Equal    ${cfg['host']}    plex.ci.test
    Should Be Equal    ${cfg['timezone']}    Europe/Berlin
    Should Contain    ${cfg['media_paths']}    /srv/ci-media
    ${out} =    Wait Until Keyword Succeeds    90 times    10 seconds
    ...    Run on node    curl -fsSk -H 'Host: plex.ci.test' https://127.0.0.1/identity
    Should Contain    ${out}    ${MACHINE_ID}
