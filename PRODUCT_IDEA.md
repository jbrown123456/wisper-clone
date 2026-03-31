# Product pitch: Native thought → English execution layer

## Overview

Build a macOS system-level input tool that allows non-native English speakers (starting with developers) to speak in their native language and instantly produce high-quality, structured English output in any text field.

This is not a translation tool.

This is a thinking-to-execution layer that upgrades raw intent into professional, idiomatic English.

---

## Problem

Non-native English developers:

- Think in their native language
- Struggle to express ideas clearly in English
- Produce weaker prompts, code comments, and documentation
- Lose time mentally translating before interacting with AI tools

Existing tools:

- Translation tools are too literal
- Voice tools assume English input
- AI chat tools require manual prompt construction

---

## Solution

A global hotkey-driven macOS app that:

1. Captures native speech
2. Converts it into intent (not literal text)
3. Rewrites into high-quality English output
4. Injects directly into the active text field

---

## Core value

**Think in your language. Ship in English.**

Output must be:

- Better than what the user could write themselves
- Structured and concise
- Developer-aware

---

## Key features

### System-level input

- macOS menu bar app
- Global hotkey activation
- Works in any app

### Streaming voice pipeline

- Real-time transcription (local)
- Partial transcripts processed continuously
- Incremental cloud calls

### Intent-based rewriting (core)

Not translation. Upgrade.

**Example**

- **Input:** “make this api faster it's kinda slow”
- **Output:** Act as a senior backend engineer. Diagnose intermittent API latency issues and propose optimizations.

### Developer-aware output

- Recognizes technical intent
- Outputs structured prompts, debugging tasks, instructions

### Instant text injection

- Streams directly into cursor
- No copy/paste

---

## Technical approach

### Hybrid architecture

**Local**

- Speech-to-text
- Cleanup

**Cloud**

- Intent inference
- Rewrite

---

## Latency strategy

- Start processing before user finishes speaking
- Stream transcript → trigger early LLM calls
- Return partial output immediately

**Targets**

- First output < 300ms
- Final output < 700ms

---

## Target user

- Non-native English developers
- Start with Spanish-speaking developers

---

## Positioning

**NOT**

- Translator
- Voice assistant

**INSTEAD**

AI input layer for global developers

---

## MVP scope

- macOS app
- One language (Spanish)
- Works in IDE + browser
- No accounts

---

## Success criteria

- Output better than user's English
- Feels instant
- Becomes habit (hotkey → speak → done)

---

## Risk

- If output ≈ translation → fails
- If slow → fails
- If friction → fails

---

## Summary

This product removes the need for non-native developers to think in English and replaces it with a system that converts native thoughts into high-quality English instantly.
