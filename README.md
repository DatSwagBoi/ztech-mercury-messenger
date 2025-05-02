# ZTech Mercury Messenger

![ZTech Mercury Messenger Logo](https://static.wixstatic.com/media/d283e5_35a877e72a2d411ea79682140475c886~mv2.jpg/v1/fill/w_96,h_50,al_c,q_80,usm_0.66_1.00_0.01,enc_avif,quality_auto/d283e5_35a877e72a2d411ea79682140475c886~mv2.jpg)

## Overview

ZTech Mercury Messenger is an enterprise messaging platform built on AnythingLLM with Ollama integration. It provides a secure, self-hosted solution for organizational communications with advanced AI capabilities.

## Features

- **Enterprise-ready messaging platform**: Secure communications with end-to-end encryption
- **Custom Z-TECH branding**: Professional interface designed for enterprise use
- **Self-hosted RAG system**: Retrieval-Augmented Generation for enhanced AI responses
- **Secure document processing**: Confidential document handling with proper access controls
- **Local AI model integration**: Powered by Ollama for on-premises AI processing
- **Multi-user support**: Role-based access control and user management
- **Containerized deployment**: Easy installation and management using Docker
- **FastAPI Backend**: High-performance Python backend using FastAPI and Uvicorn

## System Requirements

### Hardware Requirements
- **CPU**: 4+ cores (8+ recommended for optimal performance)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 20GB+ available space (SSD recommended)
- **Network**: Stable internet connection for initial setup

### Software Requirements
- **Operating System**:
  - Windows 10/11 Pro, Enterprise, or Education (64-bit)
  - Build 19045 (Windows 10 22H2) or higher
- **Docker Desktop**:
  - Latest version with Hyper-V backend
- **Web Browser**:
  - Chrome, Firefox, Edge, or Safari (latest versions)

## Installation Options

### Option 1: Automated Deployment (Recommended)

The automated deployment script handles the entire installation process, including:
- Downloading the repository (if needed)
- Installing Docker Desktop with Hyper-V
- Deploying the application
- Creating necessary directories and configuration

#### Steps:

1. Download `MercuryInstallerWSL2.ps1` from the Z-TECH portal or GitHub repository(Or download the whole repository and run it from there)
2. Right-click the script and select "Run with PowerShell" (requires administrator privileges)
3. Follow the on-screen prompts
4. You may need to Reboot once you get a WSL error, Then Start the script again when the PC boots(This is to Install WSL)
5. You may need to open Powershell to run WSL --update or WSL --start
6. After completion, access the application at http://localhost:3001

### Option 2: Manual Installation

If you prefer to install the components manually, follow these steps:

#### Prerequisites:
1. Install Docker Desktop with Hyper-V backend
   - Download from [Docker's official website](https://www.docker.com/products/docker-desktop)
   - During installation, select Hyper-V as the backend

#### Deployment Steps:
1. Clone or download this repository:
   ```
   git clone https://github.com/yourusername/ztech-mercury-messenger.git
   ```
   
2. Navigate to the project directory:
   ```
   cd ztech-mercury-messenger
   ```
   
3. Create required directories:
   ```
   mkdir -p data ollama-data
   ```
   
4. Create a `.env` file in the project root with the following content:
   ```
   JWT_SECRET=your_secure_jwt_secret_key
   ```
   
5. Start the application using one of the following methods:

   **Option A: Using docker-compose.yml (full stack)**
   ```
   docker-compose up -d
   ```
   Access the full application at http://localhost:3001
   
   **Option B: Using compose.yaml (server only)**
   ```
   docker compose -f compose.yaml up -d
   ```
   Access the API server at http://localhost:8000

## First-Time Setup

After deployment, follow these steps to complete your ZTech Mercury Messenger setup:

1. **Create Admin Account**:
   - Access http://localhost:3001
   - Complete the registration form for the admin account
   - Use a strong password (minimum 8 characters)

2. **Configure Ollama Models**:
   - The system will automatically download the required models
   - This process may take several minutes depending on your internet connection
   - Default models:
     - `qwen3:0.6b` (Primary LLM)
     - `nomic-embed-text:latest` (Embedding model)

3. **System Configuration**:
   - Navigate to Settings → System
   - Verify all services are running properly
   - Adjust system settings as needed for your organization

4. **User Management**:
   - Add additional users through the Admin panel
   - Assign appropriate permissions
   - Set up user groups as needed

## Architecture

ZTech Mercury Messenger consists of the following containers:

1. **server**:
   - Python FastAPI backend application
   - Handles API requests, authentication, and data processing
   - Built with Python 3.10 and Uvicorn for high performance
   - Exposed on port 8000

2. **ztech-mercury**:
   - Frontend and backend application
   - Handles user interface, authentication, and message processing
   - Built on AnythingLLM with custom Z-TECH branding
   - Exposed on port 3001

3. **ollama**:
   - Local AI model server
   - Provides LLM and embedding capabilities
   - Runs independently but integrated with the main application
   - Exposed on port 11434 (internal only)

The containers are connected via a Docker network for secure communication.

### File Structure

```
ztech-mercury-messenger/
├── .dockerignore          # Specifies files to exclude from Docker build
├── .github/               # GitHub workflows and configuration
├── data/                  # Application data storage
├── scripts/               # Utility scripts
├── compose.yaml           # Docker Compose configuration
├── config.py              # Application configuration
├── docker-compose.yml     # Main Docker Compose configuration
├── Dockerfile             # Docker build instructions
├── main.py                # FastAPI application entry point
├── requirements.txt       # Python dependencies
└── README.md              # This documentation
```

## Data Storage and Backup

All persistent data is stored in two main directories:

- **`./data/`**: Contains application data, user information, and message history
- **`./ollama-data/`**: Contains AI models and related data

To backup your deployment:
1. Stop the application: `docker-compose down`
2. Copy the `data` and `ollama-data` directories to a secure location
3. Restart the application: `docker-compose up -d`

## Customization

### Branding

The application comes pre-configured with Z-TECH branding. To customize:

1. Replace files in the `custom-files/branding` directory:
   - `logo.png`: Main application logo (recommended size: 200x50px)
   - `favicon.ico`: Browser tab icon
   - `styles.css`: Custom CSS for appearance modifications

2. Rebuild the container:
   ```
   docker-compose build ztech-mercury
   docker-compose up -d
   ```

### Configuration Options

Adjust application settings through environment variables in `docker-compose.yml`:

- `APP_NAME`: Change the application title
- `OLLAMA_MODEL_PREF`: Select different LLM model
- `EMBEDDING_MODEL_PREF`: Select different embedding model
- `PASSWORDMINCHAR`: Adjust minimum password length

## Security Considerations

- **Authentication**: JWT-based authentication with configurable token expiration
- **Data Privacy**: All data remains on-premises; no external APIs required
- **Encryption**: Communications encrypted in transit with HTTPS
- **Access Control**: Role-based permissions system
- **Audit Logging**: User activities are logged for security monitoring

## Troubleshooting

### Common Issues

#### Docker Desktop Won't Start
- Verify Hyper-V is properly enabled
- Check system requirements are met
- Restart computer and try again

#### Application Not Responding
- Check Docker containers are running: `docker-compose ps`
- View logs: `docker-compose logs`
- Ensure ports 3001, 8000, and 11434 are not used by other applications

#### API Server Issues
- Check FastAPI server logs: `docker-compose logs server`
- Verify the server container is running: `docker ps | grep server`
- Test the API directly: `curl http://localhost:8000/docs` (should display Swagger documentation)

#### Models Fail to Download
- Check internet connection
- Verify sufficient disk space
- Review Ollama logs: `docker-compose logs ollama`

#### Performance Issues
- Increase container resource limits in Docker Desktop settings
- Consider using a more lightweight model like `qwen3:0.6b-Q2_K` for lower resource usage
- Close other resource-intensive applications

#### Directory Access Issues
- Check the ALLOWED_DIRECTORIES setting in config.py
- Ensure the application has proper permissions to the specified directories
- For security reasons, only directories explicitly listed in ALLOWED_DIRECTORIES can be accessed

### Logs

Access container logs for troubleshooting:
```
docker-compose logs server
docker-compose logs ztech-mercury-messenger
docker-compose logs ollama
```

## Development

### Local Development Setup

For developers who want to contribute to the project or make modifications:

1. Set up a virtual environment:
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Run FastAPI server locally:
   ```
   uvicorn main:app --reload
   ```

4. Access the API documentation at http://localhost:8000/docs

### Docker Development

For testing Docker builds:

1. Build the server container:
   ```
   docker build -t ztech-mercury-server .
   ```

2. Run the server container:
   ```
   docker run -p 8000:8000 ztech-mercury-server
   ```

## Updating

To update to the latest version:

1. Pull the latest changes:
   ```
   git pull
   ```
   
2. Rebuild and restart containers:
   ```
   docker-compose down
   docker-compose build
   docker-compose up -d
   ```
   
   Alternatively, to only update the server component:
   ```
   docker compose -f compose.yaml down
   docker compose -f compose.yaml build
   docker compose -f compose.yaml up -d
   ```

## Enterprise Support

Z-TECH Associates provides enterprise support packages with:

- Priority technical assistance
- Custom deployment options
- Advanced security features
- Training and onboarding
- Extended maintenance and updates

Contact Z-TECH Associates at support@ztechnet.com for enterprise support options.

## License

ZTech Mercury Messenger is open source software licensed under the MIT License. This permissive license allows you to freely use, modify, distribute, and sell the software, provided that the original copyright notice and permission notice are included in all copies or substantial portions of the software.

## About Z-TECH Associates

Z-TECH Associates specializes in enterprise AI solutions, secure communications, and custom software development. Our team of experts delivers cutting-edge technology with a focus on security, usability, and performance.

[Visit our website](https://www.ztechnet.com) for more information about our products and services.

---

© 2025 Z-TECH Associates. All rights reserved.