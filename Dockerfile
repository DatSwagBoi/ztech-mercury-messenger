FROM mintplexlabs/anythingllm:latest

# Set a label to identify your custom build
LABEL maintainer="ZTech <your-email@example.com>"
LABEL description="ZTech Mercury Messenger App - Custom AnythingLLM Build"

# Copy any custom files or configurations
COPY ./custom-files /app/custom-files

# Set environment variables specific to your build
ENV APP_NAME="ZTech Mercury Messenger"
ENV CUSTOM_BRANDING=true

# Add any additional installation steps
RUN apt-get update && apt-get install -y \
    your-additional-packages \
    && rm -rf /var/lib/apt/lists/*

# Add any custom scripts
COPY ./scripts/custom-entrypoint.sh /app/
RUN chmod +x /app/custom-entrypoint.sh

# Override the default entrypoint if needed
ENTRYPOINT ["/app/custom-entrypoint.sh"]