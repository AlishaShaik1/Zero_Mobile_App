rks soo better 
# Zero Co-work Agent — App Integration Guide (Final)
> ✅ All endpoints tested and verified working

---

## Your Credentials (Already Configured)

```
SERVER URL (local):   http://localhost:3000
SERVER URL (prod):    https://zerolabs.live

SUPABASE URL:         https://cubqijadllanoewbkoyn.supabase.co
SUPABASE ANON KEY:    eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1YnFpamFkbGxhbm9ld2Jrb3luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4NzAwNDUsImV4cCI6MjEwMjQ0NjA0NX0.Vq4st9o5m9JSKXSdJ_41k2BWAeHdFhlyGws7go-_Ggo
```

---

## API Endpoints (All Tested ✅)

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/session/start` | POST | Start browser session |
| `/api/agent/run` | POST | Launch AI agent on task |
| `/api/agent/message` | POST | Send prompt to running agent |
| `/api/agent/unblock` | POST | Resume paused agent |
| `/api/agent/subscribe?taskId=X` | GET SSE | Stream live events |
| `/api/session/status?sessionId=X` | GET | Session state & URL |

---

## Quick Test (curl — copy & paste)

```bash
# 1. Start a browser session
curl -X POST https://zerolabs.live/api/session/start \
  -H "Content-Type: application/json" \
  -d '{"url":"https://google.com"}'

# → Copy the sessionId from response

# 2. Launch agent on a task
curl -X POST https://zerolabs.live/api/agent/run \
  -H "Content-Type: application/json" \
  -d '{"sessionId":"PASTE_SESSION_ID","task":"Search for cheapest iPhone 16 on Amazon"}'

# → Copy the taskId from response

# 3. Send a prompt mid-task
curl -X POST https://zerolabs.live/api/agent/message \
  -H "Content-Type: application/json" \
  -d '{"taskId":"PASTE_TASK_ID","sessionId":"PASTE_SESSION_ID","message":"Only show results under $700"}'

# → injected: true = agent gets it on next turn (~5s)

# 4. Stream live events
curl -N "https://zerolabs.live/api/agent/subscribe?taskId=PASTE_TASK_ID"
```

---

## JavaScript / React Native

```js
const SERVER = "https://zerolabs.live"; // change to http://localhost:3000 for local

// ── 1. Start session + run agent ──────────────────────────────
async function startAgent(task) {
  // Start browser session
  const { sessionId } = await fetch(`${SERVER}/api/session/start`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: "https://google.com" })
  }).then(r => r.json());

  // Launch agent
  const { taskId } = await fetch(`${SERVER}/api/agent/run`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sessionId, task })
  }).then(r => r.json());

  console.log("Started:", { sessionId, taskId });

  // Stream live events (SSE)
  const source = new EventSource(`${SERVER}/api/agent/subscribe?taskId=${taskId}`);
  source.onmessage = (e) => {
    const ev = JSON.parse(e.data);
    console.log(`[${ev.type}]`, ev.data);
    if (ev.type === "task_done") {
      console.log("✅ Done:", ev.data.summary);
      source.close();
    }
    if (ev.type === "blocked") {
      console.log("⚠️ Blocked:", ev.data.reason);
      // call resumeAgent() below
    }
  };

  return { sessionId, taskId };
}

// ── 2. Send a prompt to the running agent ────────────────────
async function sendPrompt(taskId, sessionId, message) {
  const res = await fetch(`${SERVER}/api/agent/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ taskId, sessionId, message })
  }).then(r => r.json());

  // injected: true = message went live into agent's next LLM turn
  // injected: false = queued in Supabase, picked up within 2 turns
  console.log("Sent:", res.injected ? "Injected live ✅" : "Queued in DB");
}

// ── 3. Resume a blocked agent ────────────────────────────────
async function resumeAgent(sessionId, taskId, instruction = "continue") {
  await fetch(`${SERVER}/api/agent/unblock`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sessionId, taskId, instruction })
  });
}

// ── 4. Get current session state ─────────────────────────────
async function getSessionStatus(sessionId) {
  const res = await fetch(`${SERVER}/api/session/status?sessionId=${sessionId}`)
    .then(r => r.json());
  console.log("URL:", res.url, "| Worker:", res.workerConnected);
  return res;
}

// ── Usage ─────────────────────────────────────────────────────
const { sessionId, taskId } = await startAgent("Find best MacBook deals on Amazon");

// After 5 seconds, refine the task:
await sendPrompt(taskId, sessionId, "Only show MacBook Air, under $1200");
```

---

## Flutter / Dart

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const SERVER = 'https://zerolabs.live';

class BrowserAgent {
  String? sessionId;
  String? taskId;

  // Start session + launch agent
  Future<void> start(String task) async {
    final s = await http.post(
      Uri.parse('$SERVER/api/session/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': 'https://google.com'}),
    );
    sessionId = jsonDecode(s.body)['sessionId'];

    final r = await http.post(
      Uri.parse('$SERVER/api/agent/run'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sessionId': sessionId, 'task': task}),
    );
    taskId = jsonDecode(r.body)['taskId'];
    print('Agent running: $taskId');
  }

  // Send prompt to agent mid-task
  Future<void> sendPrompt(String message) async {
    final r = await http.post(
      Uri.parse('$SERVER/api/agent/message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'taskId': taskId,
        'sessionId': sessionId,
        'message': message,
      }),
    );
    final data = jsonDecode(r.body);
    print('Message sent. Injected: ${data['injected']}');
  }

  // Resume blocked agent
  Future<void> resume([String instruction = 'continue']) async {
    await http.post(
      Uri.parse('$SERVER/api/agent/unblock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionId': sessionId,
        'taskId': taskId,
        'instruction': instruction,
      }),
    );
  }

  // Get session status
  Future<Map> getStatus() async {
    final r = await http.get(
      Uri.parse('$SERVER/api/session/status?sessionId=$sessionId'),
    );
    return jsonDecode(r.body);
  }
}

// Usage:
void main() async {
  final agent = BrowserAgent();
  await agent.start("Find cheapest AirPods on Amazon");

  await Future.delayed(Duration(seconds: 5));
  await agent.sendPrompt("Only AirPods Pro, under 200 dollars");
}
```

---

## Swift (iOS)

```swift
import Foundation

let SERVER = "https://zerolabs.live"

func startAgent(task: String) async throws -> (sessionId: String, taskId: String) {
    func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: SERVER + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    let session = try await post("/api/session/start", body: ["url": "https://google.com"])
    let sessionId = session["sessionId"] as! String

    let run = try await post("/api/agent/run", body: ["sessionId": sessionId, "task": task])
    let taskId = run["taskId"] as! String

    return (sessionId, taskId)
}

func sendPrompt(taskId: String, sessionId: String, message: String) async throws {
    var req = URLRequest(url: URL(string: "\(SERVER)/api/agent/message")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: [
        "taskId": taskId, "sessionId": sessionId, "message": message
    ])
    let (data, _) = try await URLSession.shared.data(for: req)
    let res = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    print("Injected:", res["injected"] ?? false)
}
```

---

## Supabase Realtime (Optional — Push Events to App)

> **Only needed for real-time push without polling.**
> Run `supabase/migrations/20260902_agent_tunnel_v2.sql` in Supabase SQL Editor first.

```js
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(
  "https://cubqijadllanoewbkoyn.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1YnFpamFkbGxhbm9ld2Jrb3luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4NzAwNDUsImV4cCI6MjEwMjQ0NjA0NX0.Vq4st9o5m9JSKXSdJ_41k2BWAeHdFhlyGws7go-_Ggo"
);

// Subscribe to live agent events for a task
supabase
  .channel(`task-${taskId}`)
  .on("postgres_changes", {
    event: "INSERT",
    schema: "public",
    table: "agent_events",
    filter: `task_id=eq.${taskId}`,
  }, (payload) => {
    const ev = payload.new;
    console.log(`[${ev.type}]`, ev.data);

    if (ev.type === "task_done") console.log("✅ Done:", ev.data.summary);
    if (ev.type === "blocked")   console.log("⚠️ Blocked:", ev.data.reason);
    if (ev.type === "action")    console.log("🖱️ Action:", ev.data.action, ev.data.url || ev.data.text);
  })
  .subscribe();

// Send message via Supabase (alternative to REST)
await supabase.from("agent_messages").insert({
  task_id: taskId,
  session_id: sessionId,
  message: "Only look at items under $700",
  priority: 1,
});
```

---

## How Message → Agent Works

```
Your App  →  POST /api/agent/message  →  pendingMessages[]
                                                ↓
                                    Agent Loop (every ~5s)
                                                ↓
                                    LLM sees: "USER INSTRUCTIONS:
                                               [MSG 1]: Only under $700"
                                                ↓
                                    Agent acts on it immediately
```

**Time from message to agent action: ~5–15 seconds**

---

## Response Shapes

### POST /api/session/start
```json
{ "success": true, "sessionId": "session_xxx", "url": "https://google.com", "workerConnected": true }
```

### POST /api/agent/run
```json
{ "success": true, "taskId": "job_xxx", "message": "Task started" }
```

### POST /api/agent/message
```json
{ "success": true, "messageId": "local_xxx", "taskId": "job_xxx", "injected": true }
```

### POST /api/agent/unblock
```json
{ "success": true, "unblocked": true, "taskId": "job_xxx" }
```

### GET /api/session/status
```json
{ "success": true, "sessionId": "session_xxx", "url": "https://amazon.com/...", "title": "Amazon", "workerConnected": true }
```

### SSE /api/agent/subscribe event shape
```json
{ "type": "action", "data": { "action": "click", "ref": 12 }, "timestamp": "...", "modelCallCount": 3 }
```
