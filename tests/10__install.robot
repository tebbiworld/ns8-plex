*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Variables ***
${CONFIG}    {"host":"plex.ci.test","lets_encrypt":false,"http2https":true,"network_mode":"bridge","media_paths":["/srv/ci-media"],"media_require_mount":false,"hw_transcoding":false,"timezone":"Europe/Berlin"}

*** Test Cases ***
Install the module
    IF    '${SCENARIO}' == 'update'
        ${output}  ${rc} =    Execute Command    add-module ${UPDATE_FROM} 1    return_rc=True
    ELSE
        ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1    return_rc=True
    END
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Configure the module
    Run on node    mkdir -p /srv/ci-media && chmod 755 /srv/ci-media
    Run task    module/${module_id}/configure-module    ${CONFIG}    decode_json=${FALSE}

Plex answers behind Traefik
    Wait Until Keyword Succeeds    90 times    10 seconds    Identity endpoint is served

Update to the image under test
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}
    Run on node    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    Wait Until Keyword Succeeds    90 times    10 seconds    Identity endpoint is served

Configuration reads back
    ${cfg} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${cfg['host']}    plex.ci.test
    Should Be Equal    ${cfg['timezone']}    Europe/Berlin
    Should Contain    ${cfg['media_paths']}    /srv/ci-media

No secret in the module environment
    ${leaks} =    Run on node    redis-cli --raw HKEYS module/${module_id}/environment | grep -Eci "PASS|SECRET|TOKEN|CLAIM" || true
    Should Be Equal As Integers    ${leaks.strip()}    0

*** Keywords ***
Identity endpoint is served
    ${out} =    Run on node    curl -fsSk -H 'Host: plex.ci.test' https://127.0.0.1/identity
    Should Contain    ${out}    machineIdentifier
