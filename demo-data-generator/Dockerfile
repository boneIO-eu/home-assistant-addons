ARG BUILD_FROM
FROM $BUILD_FROM

# Install Python and psycopg2
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-psycopg2

# Copy scripts
COPY run.sh /
COPY regenerate_demo_data.py /
COPY demo_sensors.yaml /

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
