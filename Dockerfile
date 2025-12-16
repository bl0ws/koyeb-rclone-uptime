# Main image to stable build 2.0.2
FROM docker.io/louislam/uptime-kuma:2.0.2 as KUMA

ARG UPTIME_KUMA_PORT=3001
WORKDIR /app
RUN mkdir -p /app/data

# Set timezone
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies (rclone, unzip, netcat, sqlite3)
RUN apt-get update && \
    apt-get install -y unzip curl netcat sqlite3 && \
    curl -Of https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    cp rclone-*-linux-amd64/rclone /usr/bin/rclone && \
    chmod 755 /usr/bin/rclone && \
    rm -rf rclone-*-linux-amd64* && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Add rclone config and scripts
COPY rclone.conf /app/data/rclone.conf
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

EXPOSE ${UPTIME_KUMA_PORT}

CMD [ "/usr/local/bin/run.sh" ]
