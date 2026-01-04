# Hamorah - Technical Documentation

> **Hamorah** (Hebrew: המורה, "The Teacher") - An AI-powered Bible teaching app that provides deeply personal, empathetic spiritual guidance through Scripture.

## Project Overview

Hamorah is a Flutter-based mobile/desktop application that helps users discover what God's Word says about their questions, struggles, and life situations. The AI never gives personal advice - only points users to relevant Scripture and explains how it applies.

### Core Promise
- **Privacy-First**: All user data stored locally on device, encrypted
- **Scripture-Focused**: AI only provides Bible verses and explanations, never personal advice
- **Non-Denominational**: Broadly Christian principles from Scripture

---

## Technology Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| Local Database | SQLite (sqflite + sqflite_common_ffi) |
| User Data Storage | Hive (encrypted) |
| Secure Storage | flutter_secure_storage |
| Navigation | go_router |
| AI Backend | Grok API (xAI) |
| Typography | Google Fonts (Merriweather for Scripture) |

---

## Project Structure

```
lib/
├── core/
│   ├── ai/
│   │   └── hamorah_ai_service.dart      # Grok API integration + Hamorah persona
│   ├── router/
│   │   └── app_router.dart              # Navigation routes
│   ├── services/
│   │   └── initialization_service.dart  # App startup + data loading
│   └── theme/
│       └── app_theme.dart               # Colors, typography, themes
├── data/
│   ├── bible/
│   │   ├── bible_database.dart          # SQLite Bible storage
│   │   ├── bible_repository.dart        # Data access layer
│   │   ├── kjv_importer.dart            # Bible data import + sample data
│   │   └── models/
│   │       └── bible_models.dart        # BibleBook, BibleVerse, etc.
│   ├── conversation/
│   │   ├── conversation_repository.dart # Chat history storage
│   │   └── models/
│   │       └── conversation_models.dart # ChatMessage, Conversation
│   └── user/
│       ├── user_data_repository.dart    # Bookmarks, highlights, notes
│       └── models/
│           └── user_data_models.dart    # Bookmark, Highlight, VerseNote
├── features/
│   ├── conversation/                    # AI chat with Hamorah
│   ├── library/                         # Saved bookmarks, highlights, notes
│   ├── loading/                         # App initialization screen
│   ├── onboarding/                      # First-time user experience
│   ├── reader/                          # Bible reader
│   ├── search/                          # Scripture search
│   └── settings/                        # App settings, API key management
└── main.dart                            # App entry point
```

---

## Key Features

### 1. Bible Reader
- **Location**: `lib/features/reader/`
- **Database**: SQLite with FTS5 full-text search
- **Features**:
  - Book/chapter navigation
  - All 66 books with chapter counts
  - Verse display with Merriweather serif font
  - Long-press for verse actions

### 2. AI Conversation (Hamorah)
- **Location**: `lib/features/conversation/` + `lib/core/ai/`
- **AI Provider**: Grok API (xAI)
- **Model**: `grok-3-latest`
- **Features**:
  - Scripture-focused responses
  - Conversation history (persisted)
  - Suggestion chips for quick start
  - System prompt defines Hamorah persona

### 3. Bookmarks, Highlights & Notes
- **Location**: `lib/data/user/`
- **Storage**: Hive (encrypted local storage)
- **Features**:
  - 5 highlight colors (yellow, green, blue, pink, orange)
  - Bookmarks with optional notes
  - Verse notes
  - Swipe-to-delete in Library

### 4. Search
- **Location**: `lib/features/search/`
- **Features**:
  - Keyword search with FTS5
  - Search result highlighting
  - Semantic search placeholder (future)

---

## Data Models

### BibleVerse
```dart
class BibleVerse {
  final int id;
  final int bookId;      // 1-66
  final int chapter;
  final int verse;
  final String text;
  final String? bookName;
}
```

### ChatMessage
```dart
class ChatMessage {
  final String id;
  final MessageRole role;  // user, assistant, system
  final String content;
  final DateTime timestamp;
  final List<String>? relatedVerses;
}
```

### Bookmark / Highlight / VerseNote
- Stored in Hive boxes with custom TypeAdapters
- Linked by bookId, chapter, verse

---

## AI Persona: Hamorah

The Hamorah system prompt (`lib/core/ai/hamorah_ai_service.dart`) defines:

1. **Role**: Wise, warm, empathetic Bible teacher
2. **Constraints**:
   - ONLY provide Scripture + explanations
   - NEVER give personal advice
   - Non-denominational
3. **Response Format**:
   - Acknowledge with empathy (1-2 sentences)
   - Present 2-4 relevant Scripture passages
   - Explain application
   - Invite reflection (no directives)

---

## Database Schema

### SQLite (Bible)
```sql
CREATE TABLE verses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  text TEXT NOT NULL,
  UNIQUE(book_id, chapter, verse)
);

CREATE INDEX idx_verses_book_chapter ON verses(book_id, chapter);

CREATE VIRTUAL TABLE verses_fts USING fts5(
  text,
  content='verses',
  content_rowid='id'
);
```

### Hive Boxes
- `bookmarks` - Bookmark objects (typeId: 0)
- `highlights` - Highlight objects (typeId: 1)
- `notes` - VerseNote objects (typeId: 2)
- `chat_messages` - ChatMessage objects (typeId: 10)
- `conversations` - Conversation objects (typeId: 11)

---

## API Integration

### Grok API
- **Endpoint**: `https://api.x.ai/v1/chat/completions`
- **Auth**: Bearer token
- **Request Format**: OpenAI-compatible
- **Key Storage**: flutter_secure_storage (platform Keychain/Keystore)

```dart
final response = await http.post(
  Uri.parse('https://api.x.ai/v1/chat/completions'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  },
  body: jsonEncode({
    'model': 'grok-3-latest',
    'messages': messages,
    'max_tokens': 1024,
    'temperature': 0.7,
  }),
);
```

---

## Color Palette

### Light Theme
| Purpose | Color | Hex |
|---------|-------|-----|
| Primary | Sage Green | `#4A6741` |
| Secondary | Warm Brown | `#8B7355` |
| Background | Warm Off-White | `#FDFBF7` |
| Scripture Text | Dark Green | `#3D4F35` |
| Highlight Yellow | Gold | `#C4A35A` |

### Dark Theme
| Purpose | Color | Hex |
|---------|-------|-----|
| Primary | Light Sage | `#7FA575` |
| Background | Dark | `#1A1A1A` |
| Scripture Text | Light Green | `#B8C9B0` |

---

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.6.1      # State management
  hive: ^2.2.3                   # Local NoSQL storage
  hive_flutter: ^1.1.0           # Hive Flutter bindings
  sqflite: ^2.4.1                # SQLite for Bible
  sqflite_common_ffi: ^2.3.4     # SQLite for desktop
  flutter_secure_storage: ^9.2.2 # Secure API key storage
  go_router: ^14.8.0             # Navigation
  google_fonts: ^6.2.1           # Typography
  path_provider: ^2.1.4          # File paths
  http: ^1.2.2                   # API calls
  uuid: ^4.5.1                   # Unique IDs
  path: ^1.9.0                   # Path manipulation
  intl: ^0.19.0                  # Internationalization
  collection: ^1.18.0            # Collection utilities
```

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Windows | Working | Requires sqflite_common_ffi |
| macOS | Should work | Requires sqflite_common_ffi |
| Linux | Should work | Requires sqflite_common_ffi |
| Android | Ready | Native sqflite |
| iOS | Ready | Native sqflite |

---

## Key Files Quick Reference

| File | Purpose |
|------|---------|
| `main.dart` | App entry, SQLite FFI init |
| `app_theme.dart` | All colors, typography |
| `app_router.dart` | Route definitions |
| `initialization_service.dart` | Startup flow |
| `hamorah_ai_service.dart` | AI + system prompt |
| `bible_database.dart` | SQLite operations |
| `user_data_repository.dart` | Bookmarks/highlights/notes |
| `conversation_repository.dart` | Chat history |

---

## Future Enhancements (from original plan)

- [ ] On-device AI (Gemma) for offline use
- [ ] Multiple Bible translations (NIV, ESV, NASB)
- [ ] Semantic search with embeddings
- [ ] Cross-references
- [ ] Reading plans
- [ ] Audio Bible
- [ ] Cloud backup (opt-in)

---

## License

Private project - All rights reserved.
