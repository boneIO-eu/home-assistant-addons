ARG BUILD_FROM
FROM $BUILD_FROM

# Install dependencies
RUN apk add --no-cache \
    bash \
    jq \
    postgresql-dev \
    gcc \
    musl-dev \
    python3-dev \
    py3-pip \
    && pip3 install --no-cache-dir --break-system-packages psycopg2-binary \
    && apk del gcc musl-dev python3-dev

# Copy scripts
COPY run.sh /
COPY regenerate_demo_data.py /

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
