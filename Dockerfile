# Main image
FROM docker.io/louislam/uptime-kuma:2.0.2 as KUMA

ARG UPTIME_KUMA_PORT=3001
WORKDIR /app
RUN mkdir -p /app/data

# Set timezone
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install rclone
# Install unzip and rclone
RUN apt-get update && apt-get install -y unzip && \
    curl https://rclone.org/install.sh | bash

# Add rclone config and scripts
COPY rclone.conf /app/data/rclone.conf
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

EXPOSE ${UPTIME_KUMA_PORT}

CMD [ "/usr/local/bin/run.sh" ]
