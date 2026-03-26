#!/usr/bin/env bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/../../V2/bash/get_deployment_status.sh"

    TEST_TEMP_DIR="$(mktemp -d)"

    # Mock sleep to avoid waiting during polling tests
    cat > "$TEST_TEMP_DIR/sleep" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/sleep"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Positional parameter order:
#   $1  projectId
#   $2  apiKey
#   $3  deploymentId
#   $4  timeoutSeconds  (default: 1200)
#   $5  baseUrl         (default: https://api.cloud.umbraco.com)

# --- Tests for terminal deployment states ---

@test "exits 0 when deployment completes" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"deploymentState":"Completed","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deployment completed successfully"* ]]
}

@test "exits 1 when deployment fails" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"deploymentState":"Failed","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Deployment failed"* ]]
}

@test "exits 1 on unexpected deployment status" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"deploymentState":"Unknown","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected status"* ]]
}

# --- Tests for polling ---

@test "polls until deployment completes" {
    # First call returns InProgress, second returns Completed
    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
COUNT_FILE="$TEST_TEMP_DIR/call_count"
count=\$(cat "\$COUNT_FILE" 2>/dev/null || echo 0)
count=\$((count + 1))
echo \$count > "\$COUNT_FILE"

if [ \$count -eq 1 ]; then
    echo '{"deploymentState":"InProgress","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[]}200'
else
    echo '{"deploymentState":"Completed","modifiedUtc":"2024-01-01T00:00:01Z","deploymentStatusMessages":[]}200'
fi
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deployment completed successfully"* ]]
    # Verify it polled more than once
    [ "$(cat "$TEST_TEMP_DIR/call_count")" -eq 2 ]
}

@test "polls through Queued and Pending states before completing" {
    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
COUNT_FILE="$TEST_TEMP_DIR/call_count"
count=\$(cat "\$COUNT_FILE" 2>/dev/null || echo 0)
count=\$((count + 1))
echo \$count > "\$COUNT_FILE"

case \$count in
    1) echo '{"deploymentState":"Queued","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[]}200' ;;
    2) echo '{"deploymentState":"Pending","modifiedUtc":"2024-01-01T00:00:01Z","deploymentStatusMessages":[]}200' ;;
    *) echo '{"deploymentState":"Completed","modifiedUtc":"2024-01-01T00:00:02Z","deploymentStatusMessages":[]}200' ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deployment completed successfully"* ]]
    [ "$(cat "$TEST_TEMP_DIR/call_count")" -eq 3 ]
}

# --- Tests for status messages ---

@test "prints deployment status messages" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"deploymentState":"Completed","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[{"timestampUtc":"2024-01-01T00:00:00Z","message":"Build started"},{"timestampUtc":"2024-01-01T00:00:05Z","message":"Build finished"}]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Build started"* ]]
    [[ "$output" == *"Build finished"* ]]
}

# --- Tests for API errors ---

@test "exits 1 on HTTP 401" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"error":"Unauthorized"}401'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "invalid-key" \
        "deploy-abc123"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 401"* ]]
}

@test "exits 1 on HTTP 404" {
    cat > "$TEST_TEMP_DIR/curl" << 'EOF'
#!/bin/bash
echo '{"error":"Not found"}404'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "nonexistent-deploy"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected API Response Code: 404"* ]]
}

# --- Tests for custom options ---

@test "uses custom baseUrl when provided" {
    CURL_CAPTURE="$TEST_TEMP_DIR/curl_args.txt"

    cat > "$TEST_TEMP_DIR/curl" << EOF
#!/bin/bash
printf '%s\n' "\$@" > "$CURL_CAPTURE"
echo '{"deploymentState":"Completed","modifiedUtc":"2024-01-01T00:00:00Z","deploymentStatusMessages":[]}200'
EOF
    chmod +x "$TEST_TEMP_DIR/curl"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "test-project" \
        "test-api-key" \
        "deploy-abc123" \
        "" \
        "https://custom.api.com"

    [ "$status" -eq 0 ]
    grep -q "custom.api.com" "$CURL_CAPTURE"
}
