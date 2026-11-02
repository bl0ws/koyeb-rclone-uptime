FROM docker.io/louislam/uptime-kuma:2.0.2 AS kuma

ARG UPTIME_KUMA_PORT=3001
WORKDIR /app
RUN mkdir -p /app/data

ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install restic (incremental backup, replaces rclone)
RUN apt-get update && apt-get install -y restic && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

EXPOSE ${UPTIME_KUMA_PORT}

# Safe for Koyeb, helpful for Zeabur
VOLUME ["/app/data"]

CMD ["/usr/local/bin/run.sh"]
