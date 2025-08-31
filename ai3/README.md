# AI3 Directory

This directory contains the AI³ (AI Cubed) orchestration framework and multi-LLM cognitive architecture.

## Structure

- **Legacy Integration**: Content from `__OLD_BACKUPS/ai33/` will be migrated here
- **Framework Files**: 
  - `ai3.rb` - Main AI³ interface
  - `cognitive_orchestrator.rb` - Central coordination
  - `multi_llm_manager.rb` - Provider management
  - `session_manager.rb` - Session handling
  - `rag_engine.rb` - Retrieval-augmented generation

## Current State

The existing `lib/ai3/` contains foundational components:
- `orchestrator.rb`
- `providers.rb` 
- `session.rb`
- `vector_database.rb`

## Migration Plan

When legacy materials become available:
1. Integrate `minigpt.rb` from `__OLD_BACKUPS/ai33/`
2. Merge `ai3_old/ai3.rb` functionality
3. Add `MIGRATION_REPORT.md` documentation
4. Enhance with 15 specialized assistants as per master.json

## Configuration

AI³ settings are managed through master.json:
- Multi-LLM orchestration providers
- Session management parameters
- Vector database configuration
- Swarm coordination settings