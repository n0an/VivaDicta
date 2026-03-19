# MCPLI Architecture

MCPLI turns any MCP server into a first‑class CLI tool with a fast, seamless experience. It uses long‑lived daemon processes managed by macOS launchd with socket activation for optimal performance and reliability. This document explains the current architecture and how each component works together.

**Note**: This is a macOS-only architecture using launchd for process management.

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [Core Components](#core-components)
4. [Daemon Lifecycle Management](#daemon-lifecycle-management)
5. [macOS launchd Integration](#macos-launchd-integration)
6. [Socket Activation Implementation](#socket-activation-implementation)
7. [Environment and Identity Management](#environment-and-identity-management)
8. [IPC Communication](#ipc-communication)
9. [Configuration System](#configuration-system)
10. [Performance Characteristics](#performance-characteristics)
11. [Security Model](#security-model)
12. [Key Components and Code References](#key-components-and-code-references)

## System Overview

MCPLI (Model Context Protocol CLI) is a TypeScript-based command-line interface that transforms stdio-based MCP (Model Context Protocol) servers into persistent, high-performance command-line tools. The system architecture is built around daemon processes that maintain long-lived connections to MCP servers, enabling rapid tool execution with sub-100ms response times.

The system operates on the principle of **daemon-per-server-configuration**, where each unique combination of MCP server command, arguments, and environment variables spawns a dedicated daemon process. This ensures complete isolation between different server configurations while maximizing reuse for identical configurations.

## Architecture Principles

### 1. Persistence-First Design
MCPLI prioritizes persistent daemon processes over stateless execution. Every tool invocation attempts to use or create a daemon, ensuring consistent performance and state management.

### 2. Process Isolation
Each daemon manages exactly one MCP server process, creating a clean 1:1 relationship that simplifies error handling and resource management.

### 3. Identity-Based Daemon Management
Daemon identity is computed using SHA-256 hashing of the normalized server command, arguments, and environment variables, ensuring deterministic daemon selection.

### 4. Zero-Configuration Operation
The system automatically handles daemon creation, process management, and cleanup without requiring user configuration or manual process management.

### 5. macOS-Native Integration
Deep integration with macOS launchd provides robust process management, automatic respawning, and system-level socket activation.

## Core Components

### Entry Point (`src/mcpli.ts`)

The main entry point handles command-line argument parsing and orchestrates the execution flow.

Key responsibilities:
- Command-line argument parsing with `--` separator handling
- Tool method validation against available MCP server tools
- Options processing (timeout, debug flags, output formatting)
- Error message formatting and user feedback

### Daemon Client (`src/daemon/client.ts`)

The daemon client manages communication with daemon processes through the launchd orchestrator.

The client implements a streamlined daemon lifecycle management system:

1. **Single-request connections**: The client opens one Unix socket connection per request and closes it after the response. No connection pooling.
2. **No preflight checks**: The client does not ping before sending the request. It relies on launchd to spawn the daemon on first connection if needed.
3. **Orchestrator.ensure**: ensure() creates or updates the launchd plist and socket for the daemon identity and returns the socket path. It does not restart the daemon unless explicitly requested.
4. **preferImmediateStart=false**: The client requests ensure() with preferImmediateStart=false to avoid kickstarting on every request, eliminating the previous 10+ second delays caused by restarts.
5. **Adaptive Connect Retry Budget**: When `orchestrator.ensure()` indicates the job was just `loaded` or `reloaded` (or explicitly `started`), the client temporarily increases the IPC connect retry budget to ~8 seconds. This smooths over the brief socket rebind window under launchd after a plist update, preventing transient `ECONNREFUSED`. In steady-state (no update), a short default budget (~3s) is used.
6. **IPC Timeout Auto‑Buffering**: For tool calls, IPC timeout is automatically set to at least `(tool timeout + 60s)` to ensure the transport timeout never undercuts tool execution timeout.
7. **Request Cancellation**: Tool calls support cancellation via `AbortSignal`. On abort, the client issues a protocol‑level cancel for the matching request id; the daemon aborts that request while remaining online.

### Daemon Wrapper (`src/daemon/wrapper.ts`)

The daemon wrapper runs as the long-lived daemon process and manages the MCP server connection.

Core daemon functionality:
- **MCP Server Management**: Spawns and maintains stdio connection to MCP server
- **IPC Server**: Handles Unix domain socket communication from clients
- **Request Processing**: Translates IPC requests to MCP JSON-RPC calls
- **Lifecycle Management**: Handles graceful shutdown and error recovery
- **Inactivity Management**: Automatic shutdown after configurable timeout
- **Shutdown Protection**: A daemon-wide allowShutdown flag prevents accidental exits during normal operation
- **Signal Handling**: SIGTERM and SIGINT trigger a graceful shutdown sequence, closing the IPC server and MCP client cleanly

## Daemon Lifecycle Management

### Daemon Identity and Uniqueness

Daemon identity is computed using a deterministic hashing algorithm that ensures identical server configurations share the same daemon process.

The identity computation process:

1. **Command Normalization**: Converts relative paths to absolute, handles platform differences
2. **Argument Processing**: Filters empty arguments, maintains order
3. **Environment Sorting**: Creates deterministic key-value ordering
4. **JSON Serialization**: Combines all components into consistent format
5. **SHA-256 Hashing**: Generates cryptographic hash of the serialized data
6. **ID Truncation**: Uses first 8 characters for human-readable daemon IDs

**Environment inclusion**: Only environment variables explicitly provided after the CLI `--` (i.e., as part of the MCP server command definition) are included in the identity hash. MCPLI_* variables and the caller's shell environment do not affect the daemon identity.

**Label format**: Launchd service labels follow `com.mcpli.<cwdHash>.<daemonId>`, where cwdHash is an 8-character SHA-256 hash of the absolute working directory.

**Socket path**: Sockets are created under the macOS `$TMPDIR` base to avoid AF_UNIX limits: `$TMPDIR/mcpli/<cwdHash>/<daemonId>.sock` (typically `/var/folders/.../T/mcpli/<cwdHash>/<daemonId>.sock`).

### Process Spawning and Management

The spawning process implements launchd-based lifecycle management:
- **No lock files**: launchd manages daemon lifecycle tied to a socket.
- **On-demand startup**: With preferImmediateStart=false, the client does not kickstart the job; the first socket connection activates the daemon if it isn't already running.
- **No unconditional restarts**: ensure() never restarts an already-running daemon unless explicitly requested.

## macOS launchd Integration

### launchd Service Architecture

MCPLI leverages macOS launchd for robust daemon process management and automatic service recovery.

### Property List (Plist) Configuration

Each daemon requires a launchd property list file that defines the service configuration with the label format `com.mcpli.<cwdHash>.<daemonId>` and socket activation configured for fast startup.

Key configuration elements:
- **Label**: `com.mcpli.<cwdHash>.<daemonId>`
- **ProgramArguments**: Path to daemon wrapper executable
- **EnvironmentVariables**: Complete environment for daemon execution including MCPLI_TIMEOUT in milliseconds
- **Sockets**: Socket activation configuration with file paths and permissions
- **KeepAlive**: `{ SuccessfulExit: false }` to avoid keeping the job alive after clean exit; launchd will start it on the next socket connection
- **ProcessType**: Background designation for system resource management

## Socket Activation Implementation

### Modern Socket Activation Architecture

MCPLI implements modern macOS socket activation using the `launch_activate_socket` API through the `socket-activation` npm package.

The implementation handles several critical aspects:

1. **FD Collection**: Uses `socket-activation` package to retrieve inherited file descriptors
2. **Validation**: Ensures at least one socket FD is available from launchd
3. **Server Creation**: Creates Node.js net.Server instance from inherited FD
4. **Required in launchd mode**: The daemon strictly uses the socket-activation package to collect inherited FDs. If no FDs are available for the configured socket name, startup fails rather than falling back to a non-activated socket.

## Environment and Identity Management

### Environment Variable Processing

MCPLI implements sophisticated environment variable handling to ensure proper daemon isolation while supporting flexible server configuration.

### Identity Hash Computation

The daemon identity system ensures that functionally identical server configurations share daemon processes while maintaining complete isolation between different configurations.

The normalization process handles several important cases:
- **Path Resolution**: Converts path-like command inputs to absolute paths; bare executables remain unchanged
- **Environment Ordering**: Ensures deterministic hash generation regardless of variable order
- **Empty Value Handling**: Includes empty-string environment values if explicitly provided
- **Environment scope**: Only environment variables explicitly supplied as part of the MCP server command (after `--`) are considered for identity hashing. Ambient shell env is ignored. MCPLI_* variables are included only if passed after `--`.

## IPC Communication

MCPLI uses a simple newline-delimited JSON protocol over Unix domain sockets.

The IPC protocol uses newline-delimited JSON over Unix domain sockets:

**Request Format:**
```json
{
  "id": "unique-request-id",
  "method": "callTool|listTools|ping",
  "params": { /* method-specific parameters */ }
}
```

**Response Format:**
```json
{
  "id": "matching-request-id",
  "result": { /* method response */ },
  "error": "error message if failed"
}
```

**Processing Flow Notes:**
- No preflight ping is performed; a single request/response connection is used.
- The client does not kickstart the job; launchd activation on connect is relied upon.
- Cancellation is request‑scoped. The client sends `cancelCall` for the request id; the daemon aborts the matching request without affecting other requests or the daemon lifecycle.

## Configuration System

MCPLI uses a centralized configuration system (src/config.ts) that provides environment variable support and sensible defaults for all timeout values.

### Configuration Priority (highest to lowest):
1. **CLI arguments** (--timeout=300)
2. **Environment variables** (MCPLI_DEFAULT_TIMEOUT=600)
3. **Built-in defaults** (1800 seconds)

### Environment Variables:
- `MCPLI_DEFAULT_TIMEOUT`: Daemon inactivity timeout in seconds
- `MCPLI_TOOL_TIMEOUT_MS`: Default tool execution timeout in milliseconds (preferred)
- `MCPLI_IPC_TIMEOUT`: IPC connection timeout in milliseconds (auto-buffer ≥ tool+60s)
- `MCPLI_TIMEOUT`: Internal daemon wrapper timeout in milliseconds; derived from CLI `--timeout` or `MCPLI_DEFAULT_TIMEOUT` (default: 1800000)

## Performance Characteristics

### Execution Time Analysis

MCPLI's performance profile demonstrates significant advantages of the daemon-based architecture:

Performance benefits:
- **95% Reduction**: Warm execution times are ~95% faster than cold starts
- **Consistency**: Minimal variance in warm execution times (±5ms)
- **Scalability**: Performance remains constant regardless of execution count
- **Memory Efficiency**: Shared daemon processes reduce system memory usage

**Measured warm-execution performance** (Apple Silicon, Node 18+):
- **Simple echo tool**: 60–63ms end-to-end
- **Network-bound weather tool**: ~316ms end-to-end (dominated by external API latency)

### Resource Utilization Profile

Resource characteristics:
- **Memory Footprint**: ~15-30MB per daemon process (varies by MCP server)
- **CPU Usage**: Minimal during idle, spikes only during active tool execution
- **File Descriptors**: 3-5 FDs per daemon (socket, pipes, log files)
- **Disk Space**: <1MB per daemon for plist files, sockets, and logs

### Concurrent Execution Scaling

Concurrency characteristics:
- **Multiple clients can connect concurrently** to the same daemon via the Unix socket
- **Requests are handled per connection**. The MCP SDK handles JSON-RPC concurrency; MCPLI does not apply explicit request serialization in the wrapper
- **Load Distribution**: Multiple daemon types can run simultaneously for different server configurations

## Security Model

### Security Features

1. **File System Security**:
   - Unix domain sockets with 0600 permissions (owner-only access)
   - Plist files in user-specific directories
   - Temporary files with restricted permissions

2. **Process Security**:
   - Daemon processes run under user credentials only
   - No privilege escalation or system-level access
   - Complete process isolation between different daemon instances

3. **Communication Security**:
   - Local Unix sockets only (no network exposure)
   - Process-to-process communication without external access
   - Request/response validation and sanitization

4. **Environment Security**:
   - Environment variable filtering prevents sensitive data leakage
   - Controlled environment inheritance for MCP servers
   - No automatic environment variable propagation

## Key Components and Code References

**High‑level CLI**:
- src/mcpli.ts - Entry point with argument parsing and tool discovery

**Daemon management and client**:
- src/daemon/client.ts - DaemonClient with IPC communication
- src/daemon/wrapper.ts - MCPLIDaemon process wrapper

**Orchestration and daemon identity**:
- src/daemon/runtime.ts - Orchestrator interface and identity functions including:
  - normalizeCommand(), normalizeEnv()
  - computeDaemonId(command, args, env)
  - deriveIdentityEnv(), isValidDaemonId()
  - Orchestrator interface with ensure(), stop(), status(), clean()

**Launchd orchestrator**:
- src/daemon/runtime-launchd.ts - LaunchdRuntime implementation

**IPC layer**:
- src/daemon/ipc.ts - Unix socket communication protocol

## Core APIs

### Orchestrator Interface (src/daemon/runtime.ts)
```ts
export interface Orchestrator {
  ensure(
    command: string,
    args: string[],
    options: EnsureOptions
  ): Promise<EnsureResult>;
  stop(id?: string): Promise<void>;
  status(): Promise<RuntimeStatus[]>;
  clean(): Promise<void>;
}

export function normalizeCommand(
  command: string,
  args?: string[]
): { command: string; args: string[] };

export function computeDaemonId(
  command: string,
  args?: string[],
  env?: Record<string, string>
): string;

export function isValidDaemonId(id: string): boolean;
```

### Daemon Client (src/daemon/client.ts)
```ts
export class DaemonClient {
  constructor(command: string, args: string[], options?: DaemonClientOptions);
  async listTools(): Promise<any>;
  async callTool(params: { name: string; arguments: any }): Promise<any>;
  async ping(): Promise<boolean>;
}
```

## Example: End‑to‑End Sequence

1) User runs:
   ```
   mcpli get-weather -- OPENAI_API_KEY=sk-live node weather-server.js
   ```
2) CLI parses args and discovers tools:
   - parseCommandSpec() extracts env = { OPENAI_API_KEY: "sk-live" }, command = "node", args = ["weather-server.js"].
   - discoverToolsEx(...) creates DaemonClient with env.
3) DaemonClient computes daemonId = computeDaemonId(command, args, env).
4) DaemonClient calls orchestrator.ensure(...) which writes plist and ensures launchd service.
5) Client connects to socket; launchd spawns daemon if needed.
6) Wrapper creates MCP client with merged env and starts IPC server.
7) Tool execution flows through IPC → wrapper → MCP server → response.
8) Later calls with same command/args/env reuse the same daemon for instant startup.

## Operational Considerations

- **Server command requirement**: The server command after -- is always required for all tool execution.
- **Inactivity timeout**: Wrapper resets timer on every IPC request; graceful shutdown on timeout.
- **Logging**: When debug/logs are enabled, the MCP server's stderr is inherited.
- **Cleanup**: Stale plist/sockets are removed when processes are gone via orchestrator.clean().
- **macOS-only**: Current architecture requires macOS and launchd for process management.

---

## Conclusion

The MCPLI architecture represents a sophisticated approach to command-line tool management, combining the benefits of persistent daemon processes with robust process management and efficient IPC communication. The system's design prioritizes performance, reliability, and security while maintaining simplicity for end users.

Key architectural achievements:
- **Performance**: Sub-100ms tool execution for warm processes (measured 60-63ms for simple tools)
- **Reliability**: Comprehensive error handling with shutdown protection and automatic recovery
- **Scalability**: Efficient resource usage with concurrent client support and daemon isolation  
- **Security**: Process isolation and restricted file system permissions
- **Maintainability**: Clean separation of concerns with launchd-based orchestration

The integration with macOS launchd provides enterprise-grade process management, while the socket activation system ensures efficient resource utilization and fast startup times. The result is a production-ready CLI tool system that transforms simple MCP servers into high-performance, persistent command-line tools.
