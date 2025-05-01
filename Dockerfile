FROM mintplexlabs/anythingllm:latest

# Set labels for your custom build
LABEL maintainer="Z-TECH Associates <hcushing@ztechnet.com>"
LABEL description="ZTech Mercury Messenger - Enterprise Messaging Platform"

# Copy custom branding files
COPY ./custom-files/branding /app/frontend/public/branding

# Set environment variables for your build
ENV APP_NAME="ZTech Mercury Messenger"
ENV CUSTOM_BRANDING=true

# Copy entrypoint script (already executable in the container)
COPY ./scripts/custom-entrypoint.sh /app/

# Use the default entrypoint from the base image
# This avoids the chmod permission issues
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]