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
    # started again and the agent of the new instance never comes up. Only the units shipped by
    # the module are stopped: its agent (agent.service) must keep running, or the
    # instance can no longer be removed.
    Run on node    runagent -m ${module_id} bash -c 'cd ~/.config/systemd/user && ls *.service *.timer 2>/dev/null | xargs -r systemctl --user disable --now'

Restore into a new instance
    ${rid} =    Restore the module from the cluster repository    ${BACKUP_REPO}    ${BACKUP_PATH}
    Set Global Variable    ${restored_id}    ${rid}
    Should Not Be Equal    ${restored_id}    ${module_id}

The restored server keeps its identity and settings
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be Equal    ${cfg['host']}    plex.ci.test
    Should Be Equal    ${cfg['timezone']}    Europe/Berlin
    Should Contain    ${cfg['media_paths']}    /srv/ci-media
    # asked at the backend of the restored instance: the stopped original still owns a
    # route for the same host name, so the host header is ambiguous
    ${route} =    Run task    module/traefik1/get-route    {"instance":"${restored_id}"}
    Should Be Equal    ${route['host']}    plex.ci.test
    ${out} =    Wait Until Keyword Succeeds    90 times    10 seconds
    ...    Run on node    curl -fsS ${route['url']}/identity
    Should Contain    ${out}    ${MACHINE_ID}
