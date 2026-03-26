#!/usr/bin/env bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/../../V2/bash/upload_artifact.sh"

    TEST_TEMP_DIR="$(mktemp -d)"
    export GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output.txt"
    touch "$GITHUB_OUTPUT"

    # Create a dummy artifact file for tests that need one
    ARTIFACT_FILE="$TEST_TEMP_DIR/artifact.zip"
    echo "dummy artifact content" > "$ARTIFACT_FILE"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Positional parameter order:
#   $1  projectId
#   $2  apiKey
#   $3  filePath
#   $4  description
#   $5  version
#   $6  pipelineVendor
#   $7  baseUrl  (default: https://api.cloud.umbraco.com)

# --- Guard tests ---

@test "exits with error when filePath is empty" {
    run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "" \
        "My description" \
        "1.0.0" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"filePath is empty"* ]]
}

@test "exits with error when file does not exist" {
    run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "/nonexistent/path/artifact.zip" \
        "My description" \
        "1.0.0" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"filePath does not contain a file"* ]]
}

# --- Tests for successful upload ---

@test "uploads artifact and returns artifactId for GITHUB vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"artifactId":"artifact-abc123"}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "GITHUB"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Artifact uploaded - Artifact Id: artifact-abc123"* ]]
    grep -q "artifactId=artifact-abc123" "$GITHUB_OUTPUT"
}

@test "uploads artifact and returns artifactId for AZUREDEVOPS vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"artifactId":"artifact-xyz789"}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "AZUREDEVOPS"

    [ "$status" -eq 0 ]
    [[ "$output" == *"##vso[task.setvariable variable=artifactId;isOutput=true]artifact-xyz789"* ]]
}

@test "uploads artifact for TESTRUN vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"artifactId":"artifact-test"}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "TESTRUN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"TESTRUN"* ]]
}

@test "exits with error for unknown vendor" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"artifactId":"artifact-test"}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "UNKNOWN"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Please use one of the supported Pipeline Vendors"* ]]
}

@test "displays upload response body on success" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"artifactId":"artifact-abc123"}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "TESTRUN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"artifact-abc123"* ]]
    [[ "$output" != *"No such file or directory"* ]]
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
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 401"* ]]
    [[ "$output" == *"Unauthorized"* ]]
}

@test "exits with error on HTTP 400" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"error":"Bad Request"}400'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "GITHUB"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 400"* ]]
}

# --- Tests for custom base URL ---

@test "uses custom baseUrl when provided" {
    CURL_CAPTURE="$TEST_TEMP_DIR/curl_args.txt"

    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
printf '%s\n' "\$@" > "$CURL_CAPTURE"
echo '{"artifactId":"artifact-test"}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "$ARTIFACT_FILE" \
        "My description" \
        "1.0.0" \
        "TESTRUN" \
        "https://custom.api.com"

    [ "$status" -eq 0 ]
    grep -q "custom.api.com" "$CURL_CAPTURE"
}
