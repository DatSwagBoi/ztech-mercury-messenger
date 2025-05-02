# ZTech Mercury Messenger

<img align="right" width="300" src="https://placeholder.com/wp-content/uploads/2018/10/placeholder.com-logo1.png" alt="ZTech Mercury Messenger Logo">

A secure, enterprise-grade messaging and knowledge management platform built on AnythingLLM with Ollama integration. ZTech Mercury Messenger provides organizations with a powerful, self-hosted solution for document retrieval, contextual AI conversations, and intelligent ticket assistance.

[![GitHub license](https://img.shields.io/github/license/DatSwagBoi/ztech-mercury-messenger)](https://github.com/DatSwagBoi/ztech-mercury-messenger/blob/main/LICENSE)
[![Docker Image](https://img.shields.io/docker/v/aqws000/ztech-mercury-messenger?label=docker)](https://hub.docker.com/r/aqws000/ztech-mercury-messenger)

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [Installation](#installation)
  - [Docker Installation](#docker-installation)
  - [Configuration](#configuration)
- [Usage Guide](#usage-guide)
  - [User Interface](#user-interface)
  - [Slash Commands](#slash-commands)
  - [Working with Documents](#working-with-documents)
  - [Managing Workspaces](#managing-workspaces)
  - [Ticket Assistance](#ticket-assistance)
- [Models](#models)
  - [Configuring Ollama Models](#configuring-ollama-models)
  - [Recommended Models](#recommended-models)
- [Administration](#administration)
  - [User Management](#user-management)
  - [System Settings](#system-settings)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Features

- **Secure Self-Hosted Solution**: Keep your data within your organization's infrastructure
- **Document Processing**: Upload and process documents in various formats (PDF, DOCX, TXT, CSV, etc.)
- **Z-TECH Branded Interface**: Custom-designed user experience
- **Contextual Conversations**: Chat with your documents using advanced LLM technology
- **Ticket Management Integration**: Process and respond to support tickets with AI assistance
- **Role-Based Access Control**: Manage user permissions with granular controls
- **Multi-Model Support**: Use different models for different tasks
- **API Access**: Integrate with your existing tools and workflows
- **Version History**: Track changes to documents and conversations

## Quick Start

```bash
# Clone the repository
git clone https://github.com/DatSwagBoi/ztech-mercury-messenger.git
cd ztech-mercury-messenger

# Start the application
docker compose up -d
```

Access the application at http://localhost:3001

Default login:
- Username: `admin@example.com`
- Password: `password` (change immediately after first login)

## System Requirements

- Docker-compatible operating system (Windows, macOS, Linux)
- Docker and Docker Compose installed
- Minimum 4GB RAM (8GB+ recommended)
- 10GB+ free disk space
- Internet connection for initial setup

## Installation

### Docker Installation

The recommended way to install ZTech Mercury Messenger is using Docker:

```bash
# Clone the repository
git clone https://github.com/DatSwagBoi/ztech-mercury-messenger.git
cd ztech-mercury-messenger

# Create an environment file (optional)
cp .env.example .env
# Edit the .env file with your preferred settings

# Start the application
docker compose up -d
```

### Configuration

Configure the application by editing the `.env` file or environment variables in `docker-compose.yml`:

| Variable | Description | Default |
|---|---|---|
| `JWT_SECRET` | Secret key for JWT token generation | `your_secure_jwt_secret_key` |
| `LLM_PROVIDER` | LLM provider to use | `ollama` |
| `OLLAMA_BASE_PATH` | URL for Ollama API | `http://ollama:11434` |
| `OLLAMA_MODEL_PREF` | Default model for chat | `llama2` |
| `EMBEDDING_ENGINE` | Engine for document embeddings | `ollama` |
| `EMBEDDING_MODEL_PREF` | Model for embeddings | `nomic-embed-text` |

## Usage Guide

### User Interface

ZTech Mercury Messenger provides an intuitive interface with these main sections:

- **Chat**: Where you have conversations with your documents
- **Documents**: Upload and manage your document library
- **Workspaces**: Organize documents into contextual workspaces
- **Tools**: Access specialized functions like ticket processing
- **Settings**: Configure your user preferences and system settings

### Slash Commands

Enhance your experience with these slash commands:

| Command | Description | Example |
|---|---|---|
| `/help` | Display help information | `/help` |
| `/clear` | Clear the current conversation | `/clear` |
| `/model [name]` | Switch to a different model | `/model llama3` |
| `/upload` | Upload a document to the current workspace | `/upload` |
| `/search [query]` | Search through documents | `/search network issues` |
| `/ticket [id]` | Retrieve information about a specific ticket | `/ticket T-1234` |
| `/summarize` | Summarize the current conversation | `/summarize` |
| `/export [format]` | Export the conversation | `/export pdf` |
| `/system [prompt]` | Set a system prompt | `/system You are a helpful assistant` |
| `/context [doc]` | Add a specific document to the context | `/context network-policy.pdf` |

### Working with Documents

1. **Uploading Documents**:
   - Navigate to the Documents section
   - Click "Upload Document"
   - Select files from your computer
   - Documents will be processed and embedded automatically

2. **Document Management**:
   - View all documents in your library
   - Search for specific documents
   - Tag documents for better organization
   - Delete documents when no longer needed

3. **Document Processing Status**:
   - Pending: Document is queued for processing
   - Processing: Document is being processed
   - Completed: Document is ready for use
   - Failed: Processing failed (check logs for details)

### Managing Workspaces

Workspaces help organize documents into contextual groups:

1. **Creating a Workspace**:
   - Go to Workspaces
   - Click "New Workspace"
   - Name your workspace and add a description
   - Select documents to include

2. **Using Workspaces**:
   - Switch between workspaces to change context
   - Add or remove documents from workspaces
   - Share workspaces with team members

### Ticket Assistance

ZTech Mercury Messenger can help process support tickets:

1. **Ticket Processing**:
   - Import tickets from your ticketing system
   - Generate responses based on your knowledge base
   - Review and edit suggestions before sending

2. **Knowledge-Based Responses**:
   - The system uses your documents to generate contextual responses
   - Historical ticket resolutions improve future suggestions
   - Tags and categories help organize common issues

3. **Ticket Commands**:
   - `/ticket new` - Create a new ticket
   - `/ticket assign [user]` - Assign a ticket to a user
   - `/ticket status [id] [status]` - Update ticket status
   - `/ticket history [id]` - Show ticket history
   - `/ticket similar [id]` - Find similar tickets

## Models

### Configuring Ollama Models

ZTech Mercury Messenger uses Ollama for AI functionality:

1. **Installing Models**:
   ```bash
   # Connect to the Ollama container
   docker exec -it ztech-mercury-ollama /bin/bash
   
   # Pull models (examples)
   ollama pull llama2
   ollama pull nomic-embed-text
   ollama pull mistral
   ollama pull codellama
   ```

2. **Model Configuration**:
   - Chat models: Used for conversation
   - Embedding models: Used for document processing
   - Specialized models: For specific tasks like code or medical content

### Recommended Models

| Task | Recommended Models | Size | Performance |
|---|---|---|---|
| General Chat | llama2, mistral, llama3 | 7B-13B | Good balance of performance/resources |
| Code Assistance | codellama, wizardcoder | 7B-13B | Specialized for code generation |
| Embeddings | nomic-embed-text, all-MiniLM-L6-v2 | < 1GB | Efficient for document processing |
| Complex Reasoning | llama3, gemma | 13B+ | Better reasoning capabilities |

## Administration

### User Management

1. **Adding Users**:
   - Navigate to Settings > Users
   - Click "Add User"
   - Enter email and initial password
   - Assign appropriate roles

2. **User Roles**:
   - Admin: Full system access
   - Manager: Can manage workspaces and documents
   - User: Basic access to assigned workspaces
   - Viewer: Read-only access

### System Settings

Access settings at Settings > System:

- **Security**: Configure authentication methods and password policies
- **Storage**: Manage document storage settings and quotas
- **Models**: Configure default models and parameters
- **Appearance**: Customize interface elements and branding
- **Backups**: Configure automated backups
- **Logs**: View system logs and diagnostics

## Customization

Customize ZTech Mercury Messenger to match your organization's needs:

1. **Branding**:
   - Place your logo in `custom-files/branding/`
   - Customize colors in the appearance settings

2. **Custom Prompts**:
   - Create organization-specific prompts for common tasks
   - Save and share prompts with team members

3. **Integrations**:
   - Connect to external systems via the API
   - Set up webhooks for event notifications

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|---|---|
| Application won't start | Check Docker logs with `docker logs ztech-mercury-messenger` |
| Model not found | Ensure you've pulled the model to Ollama with `ollama pull [model]` |
| Slow document processing | Check system resources or use a smaller embedding model |
| Authentication issues | Verify JWT_SECRET is properly set and consistent |
| Database errors | Check storage permissions and available space |

## Contributing

We welcome contributions to ZTech Mercury Messenger:

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For support or inquiries, contact Z-TECH Associates:
- Email: support@ztechnet.com
- Website: https://ztechnet.com

---

Developed with ❤️ by [Z-TECH Associates](https://ztechnet.com)