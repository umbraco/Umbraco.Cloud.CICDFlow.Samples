#!/usr/bin/env bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/../../V2/bash/get_changes_by_id.sh"

    TEST_TEMP_DIR="$(mktemp -d)"
    export GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output.txt"
    touch "$GITHUB_OUTPUT"

    DOWNLOAD_FOLDER="$TEST_TEMP_DIR/downloads"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Positional parameter order:
#   $1  projectId
#   $2  apiKey
#   $3  deploymentId
#   $4  targetEnvironmentAlias
#   $5  downloadFolder
#   $6  pipelineVendor
#   $7  baseUrl  (default: https://api.cloud.umbraco.com)

# Helper: create a curl mock that writes $content to the -o file and prints $code
make_curl_mock() {
    local code="$1"
    local content="$2"

    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
args=("\$@")
for i in "\${!args[@]}"; do
    if [[ "\${args[\$i]}" == "-o" ]]; then
        printf '%s' '$content' > "\${args[\$((i+1))]}"
        break
    fi
done
echo "$code"
EOF
    chmod +x "$TEST_TEMP_DIR/curl"
}

# --- Guard tests ---

@test "exits with error when deploymentId is empty" {
    run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"I need a DeploymentId"* ]]
}

# --- Tests for 204 No Content ---

@test "reports no changes on HTTP 204 for GITHUB vendor" {
    make_curl_mock "204" ""

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "GITHUB"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No Changes"* ]]
    grep -q "remoteChanges=no" "$GITHUB_OUTPUT"
}

@test "reports no changes on HTTP 204 for AZUREDEVOPS vendor" {
    make_curl_mock "204" ""

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "AZUREDEVOPS"

    [ "$status" -eq 0 ]
    [[ "$output" == *"##vso[task.setvariable variable=remoteChanges;isOutput=true]no"* ]]
}

# --- Tests for 200 with content ---

@test "detects changes when diff file has content" {
    make_curl_mock "200" "diff --git a/file.txt b/file.txt"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "GITHUB"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes detected"* ]]
    grep -q "remoteChanges=yes" "$GITHUB_OUTPUT"
}

@test "reports no changes when diff file is empty on HTTP 200" {
    make_curl_mock "200" ""

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "GITHUB"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No Changes"* ]]
    grep -q "remoteChanges=no" "$GITHUB_OUTPUT"
}

@test "detects changes for AZUREDEVOPS vendor" {
    make_curl_mock "200" "diff --git a/file.txt b/file.txt"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "AZUREDEVOPS"

    [ "$status" -eq 0 ]
    [[ "$output" == *"##vso[task.setvariable variable=remoteChanges;isOutput=true]yes"* ]]
}

@test "detects changes for TESTRUN vendor" {
    make_curl_mock "200" "diff --git a/file.txt b/file.txt"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "TESTRUN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTRUN"* ]]
}

@test "creates download folder if it does not exist" {
    make_curl_mock "204" ""

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER/nested/path" \
        "TESTRUN"

    [ "$status" -eq 0 ]
    [ -d "$DOWNLOAD_FOLDER/nested/path" ]
}

# --- Tests for unknown vendor ---

@test "exits with error for unknown vendor" {
    make_curl_mock "200" "diff --git a/file.txt b/file.txt"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "UNKNOWN"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Please use one of the supported Pipeline Vendors"* ]]
}

# --- Tests for API errors ---

@test "exits with error on HTTP 401" {
    make_curl_mock "401" '{"error":"Unauthorized"}'

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "invalid-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 401"* ]]
}

@test "exits with error on HTTP 404" {
    make_curl_mock "404" '{"error":"Not found"}'

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "nonexistent-deploy" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 404"* ]]
}

# --- Tests for custom base URL ---

@test "uses custom baseUrl when provided" {
    CURL_CAPTURE="$TEST_TEMP_DIR/curl_args.txt"

    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
args=("\$@")
printf '%s\n' "\${args[@]}" > "$CURL_CAPTURE"
for i in "\${!args[@]}"; do
    if [[ "\${args[\$i]}" == "-o" ]]; then
        touch "\${args[\$((i+1))]}"
        break
    fi
done
echo "204"
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "Development" \
        "$DOWNLOAD_FOLDER" \
        "TESTRUN" \
        "https://custom.api.com"

    [ "$status" -eq 0 ]
    grep -q "custom.api.com" "$CURL_CAPTURE"
}
