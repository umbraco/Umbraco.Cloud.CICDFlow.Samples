#!/usr/bin/env bats

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/../../V2/bash/apply_patch.sh"

    TEST_TEMP_DIR="$(mktemp -d)"
    export GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output.txt"
    touch "$GITHUB_OUTPUT"

    PATCH_FILE="$TEST_TEMP_DIR/git-patch.diff"
    echo "dummy patch content" > "$PATCH_FILE"

    # Base git mock: config/checkout/add/commit/push/rev-parse all succeed.
    # apply behaviour is controlled per-test by GIT_APPLY_REVERSE_RESULT and GIT_APPLY_CHECK_RESULT.
    # Defaults: reverse check fails (patch not yet applied), forward check succeeds (patch can apply).
    cat > "$TEST_TEMP_DIR/git" << 'EOF'
#!/bin/bash
case "$1" in
    config|checkout|add|commit|push) exit 0 ;;
    rev-parse) echo "abc123sha456"; exit 0 ;;
    apply)
        args="$*"
        if [[ "$args" == *"--reverse"* ]] && [[ "$args" == *"--check"* ]]; then
            exit "${GIT_APPLY_REVERSE_RESULT:-1}"
        fi
        if [[ "$args" == *"--check"* ]]; then
            exit "${GIT_APPLY_CHECK_RESULT:-0}"
        fi
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/git"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

# Positional parameter order:
#   $1  patchFile
#   $2  latestDeploymentId
#   $3  pipelineVendor
#   $4  gitUserName
#   $5  gitUserEmail

# --- Patch already applied ---

@test "exits 0 without re-applying when patch is already applied" {
    export GIT_APPLY_REVERSE_RESULT=0  # reverse check succeeds → already applied

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "TESTRUN" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Patch already applied"* ]]
}

# --- Patch applied successfully ---

@test "applies patch and exits 0 for TESTRUN vendor" {
    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "TESTRUN" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes are applied successfully"* ]]
}

@test "applies patch, commits, and writes updatedSha for GITHUB vendor" {
    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "GITHUB" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes are applied successfully"* ]]
    [[ "$output" == *"abc123sha456"* ]]
    grep -q "updatedSha=abc123sha456" "$GITHUB_OUTPUT"
}

@test "applies patch, commits, and writes updatedSha for AZUREDEVOPS vendor" {
    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "AZUREDEVOPS" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Changes are applied successfully"* ]]
    [[ "$output" == *"##vso[task.setvariable variable=updatedSha;isOutput=true]abc123sha456"* ]]
}

@test "commit message includes the deployment id" {
    COMMIT_CAPTURE="$TEST_TEMP_DIR/commit_msg.txt"

    cat >> "$TEST_TEMP_DIR/git" << EOF

# Override just the commit subcommand to capture message
EOF
    cat > "$TEST_TEMP_DIR/git" << EOF
#!/bin/bash
case "\$1" in
    config|checkout|add|push) exit 0 ;;
    rev-parse) echo "abc123sha456"; exit 0 ;;
    commit)
        printf '%s\n' "\$@" > "$COMMIT_CAPTURE"
        exit 0
        ;;
    apply)
        args="\$*"
        if [[ "\$args" == *"--reverse"* ]] && [[ "\$args" == *"--check"* ]]; then exit 1; fi
        if [[ "\$args" == *"--check"* ]]; then exit 0; fi
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/git"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "GITHUB" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 0 ]
    grep -q "deploy-abc123" "$COMMIT_CAPTURE"
}

# --- Patch cannot be applied ---

@test "exits 1 when patch cannot be applied" {
    export GIT_APPLY_CHECK_RESULT=1  # forward check fails → cannot apply

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "TESTRUN" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Patch cannot be applied"* ]]
}

# --- Git configuration ---

@test "configures git user name and email" {
    GIT_CONFIG_CAPTURE="$TEST_TEMP_DIR/git_config.txt"

    cat > "$TEST_TEMP_DIR/git" << EOF
#!/bin/bash
case "\$1" in
    config)
        echo "\$@" >> "$GIT_CONFIG_CAPTURE"
        exit 0
        ;;
    checkout|add|commit|push) exit 0 ;;
    rev-parse) echo "abc123sha456"; exit 0 ;;
    apply)
        args="\$*"
        if [[ "\$args" == *"--reverse"* ]] && [[ "\$args" == *"--check"* ]]; then exit 1; fi
        if [[ "\$args" == *"--check"* ]]; then exit 0; fi
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/git"

    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "TESTRUN" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 0 ]
    grep -q "user.name Test User" "$GIT_CONFIG_CAPTURE"
    grep -q "user.email test@example.com" "$GIT_CONFIG_CAPTURE"
}

# --- Unknown vendor ---

@test "exits 1 for unknown vendor" {
    PATH="$TEST_TEMP_DIR:$PATH" run bash "$SCRIPT_PATH" \
        "$PATCH_FILE" \
        "deploy-abc123" \
        "UNKNOWN" \
        "Test User" \
        "test@example.com"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Please use one of the supported Pipeline Vendors"* ]]
}
