# JARVIS AI Assistant - Backend

The official backend service for the JARVIS AI Assistant. Built with Dart, Shelf, and Firebase Genkit using Google Gemini models.

---

## 🏛 Architecture Overview

- **Flutter Frontend**: Handles user interface and audio/visual interactions.
- **Dart Backend (`jarvic_backend`)**: Centralized backend handling all AI logic, conversation persistence, tool execution, and Genkit workflows.
- **Firebase Genkit & Google Gemini**: Power intelligence, tool orchestration, and structured generation.
- **REST API**: Communicates with the Flutter client over secure Shelf HTTP endpoints.
- **Security**: The Gemini API key remains strictly server-side and is never exposed to the frontend.

```
Flutter Client (Frontend)
       │
       │ REST API (JSON)
       ▼
Dart Shelf Server (`jarvic_backend`)
       │
       ├── Middleware (CORS, Error handling, Logging)
       ├── Shelf Router (/api/health, /api/chat, /api/conversations)
       └── AI Services & Genkit Flows
             │
             ├── Custom AI Tools
             │     ├── Calculator (arithmetic + division-by-zero protection)
             │     ├── DateTime (local date, time, and datetime queries)
             │     └── AppInfo (capabilities and version metadata)
             │
             ▼
     Google Gemini API (via Genkit)
```

---

## 📁 Project Structure

```
jarvic_backend/
├── bin/
│   └── jarvic_backend.dart        # Server entrypoint
├── lib/
│   ├── config/
│   │   ├── ai_config.dart         # Centralized Genkit & Gemini singleton setup
│   │   ├── env.dart               # Safe environment variables loader (.env)
│   │   └── jarvis_prompts.dart    # JARVIS core persona & safety instructions
│   ├── flows/
│   │   └── chat_flow.dart         # Genkit chat flow with registered tools
│   ├── middleware/                # Shelf middlewares (CORS, logging, error handling)
│   ├── models/                    # Request/response DTOs and data models
│   ├── routes/                    # Shelf HTTP route handlers
│   ├── services/
│   │   └── jarvis_ai_service.dart # Core AI service with FlowAiGenerator
│   └── tools/
│       ├── app_info_tool.dart     # System capabilities & version metadata
│       ├── calculator_tool.dart   # Arithmetic operations with safe zero division
│       └── date_time_tool.dart    # Current local date & time retrieval
├── test/                          # Unit and integration test suites
│   ├── ai_config_test.dart        # Configuration and environment tests
│   ├── chat_flow_test.dart        # Genkit flow and tool binding tests
│   ├── jarvis_ai_service_test.dart# Service behavior & validation tests
│   └── tools_test.dart            # Calculator, DateTime, and AppInfo tool tests
├── .env                           # Local environment variables (git-ignored)
├── .env.example                   # Environment variables template
├── pubspec.yaml                   # Dependencies and SDK requirements
└── README.md
```

---

## 🛠 Features Implemented

### 1. Centralized AI Configuration & Safe Environment
- Singleton Genkit initialization configured with the `googleAI` plugin.
- Seamless loading of `.env` configurations without committing secrets.
- Automated fallback to process environment variables with developer override capabilities.

### 2. JARVIS Persona & AI Service
- Tailored system prompt establishing JARVIS as an intelligent, calm, confident, and professional assistant.
- Strict safety boundaries preventing hallucination of actions and OS command execution.
- Input validation (`InvalidMessageException`) and sanitized error handling (`JarvisAiException`).

### 3. Custom AI Tools & Genkit Flows
- **`calculator`**: Safe evaluation of addition, subtraction, multiplication, and division with explicit division-by-zero safeguards.
- **`getDateTime`**: Live retrieval of local date, time, or full timestamps.
- **`getAppInfo`**: Dynamic capability discovery and backend version information.
- **`jarvisChatFlow`**: Automated tool dispatch and multi-turn execution coordinated through Firebase Genkit.

---

## ⚙️ Prerequisites

- **Dart SDK**: `^3.14.0` (or Flutter SDK `>= 3.50.0`)
- **Google Gemini API Key**: Obtain one from [Google AI Studio](https://aistudio.google.com/).

---

## 🚀 Getting Started

### 1. Install Dependencies

```bash
dart pub get
```
*(Or `fvm dart pub get` if managing Flutter/Dart via FVM)*

### 2. Configure Environment

Copy the `.env.example` file to `.env`:

```bash
cp .env.example .env
```

Set your Gemini API key in `.env`:

```env
PORT=8080
HOST=localhost
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.5-flash
```

---

## 🧪 Testing & Analysis

Run formatting, static analysis, and test suites:

```bash
# Format code
dart format .

# Analyze code
dart analyze

# Run unit tests
dart test
```

---

## 📡 REST API Endpoints (Upcoming Phases)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Health check endpoint |
| `POST` | `/api/chat` | Send message and receive JARVIS response |
| `GET` | `/api/conversations` | List active conversations |
| `GET` | `/api/conversations/:id` | Retrieve conversation history |
| `DELETE` | `/api/conversations/:id` | Clear conversation history |

---

## 🔒 Security Best Practices

- Never commit `.env` or files containing live API keys to version control.
- All client-to-backend communication uses validated request schemas.
- Internal exception traces are sanitized and never leaked to API clients.
