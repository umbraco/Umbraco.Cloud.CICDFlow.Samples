#!/usr/bin/env bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/../../V2/bash/get_latest_deployment.sh"

    TEST_TEMP_DIR="$(mktemp -d)"
    export GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output.txt"
    touch "$GITHUB_OUTPUT"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Positional parameter order:
#   $1  projectId
#   $2  apiKey
#   $3  targetEnvironmentAlias
#   $4  pipelineVendor
#   $5  baseUrl  (default: https://api.cloud.umbraco.com)

# --- Tests for successful response ---

@test "returns latest deployment id for GITHUB vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"data":[{"id":"deploy-abc123"}]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "Development" \
        "GITHUB"

    [ "$status" -eq 0 ]
    grep -q "latestDeploymentId=deploy-abc123" "$GITHUB_OUTPUT"
}

@test "returns latest deployment id for AZUREDEVOPS vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"data":[{"id":"deploy-xyz789"}]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "Development" \
        "AZUREDEVOPS"

    [ "$status" -eq 0 ]
    [[ "$output" == *"##vso[task.setvariable variable=latestDeploymentId;isOutput=true]deploy-xyz789"* ]]
}

# This test would have caught the `cat "content"` bug:
# With the bug, the response body was never printed (a "cat: content: No such file or directory"
# error went to stderr instead), so the deployment ID shown in output came only from the jq
# extraction line — but the raw API response was silently swallowed.
# The test asserts the response body is visible in stdout, which fails with `cat "content"`.
@test "displays API response body on successful call" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"data":[{"id":"deploy-abc123"}]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "Development" \
        "TESTRUN"

    [ "$status" -eq 0 ]
    # The response body must appear in stdout — not swallowed or sent to stderr
    [[ "$output" == *"deploy-abc123"* ]]
    # Ensure no file-not-found error leaked through (the pre-fix symptom)
    [[ "$output" != *"No such file or directory"* ]]
}

# --- Tests for empty deployment list ---

@test "reports no deployments found when data array is empty" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"data":[]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "Development" \
        "GITHUB"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No latest CICD Flow Deployments found"* ]]
}

# --- Tests for API errors ---

@test "exits with error on HTTP 401" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"error":"Unauthorized"}401'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "invalid-key" \
        "Development" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 401"* ]]
    [[ "$output" == *"Unauthorized"* ]]
}

@test "exits with error on HTTP 404" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"error":"Project not found"}404'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "nonexistent-project" \
        "test-api-key" \
        "Development" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 404"* ]]
}

# --- Tests for unsupported vendor ---

@test "exits with error for unknown vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"data":[{"id":"deploy-abc123"}]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "Development" \
        "UNKNOWN"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Please use one of the supported Pipeline Vendors"* ]]
}

# --- Tests for custom base URL ---

@test "uses custom baseUrl when provided" {
    CURL_CAPTURE="$TEST_TEMP_DIR/curl_args.txt"

    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
printf '%s\n' "\$@" > "$CURL_CAPTURE"
echo '{"data":[{"id":"deploy-abc123"}]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "Development" \
        "TESTRUN" \
        "https://custom.api.com"

    [ "$status" -eq 0 ]
    grep -q "custom.api.com" "$CURL_CAPTURE"
}
