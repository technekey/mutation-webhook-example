FROM python:3.8.3-alpine

RUN pip install --upgrade pip

RUN adduser -D webhookadmin
USER webhookadmin
WORKDIR /home/webhookadmin

COPY --chown=webhookadmin:webhookadmin requirements.txt requirements.txt
RUN pip install --user -r requirements.txt

ENV PATH="/home/webhookadmin/.local/bin:${PATH}"

COPY   --chown=webhookadmin:webhookadmin . .
RUN chmod +x ./start_server.sh

ENTRYPOINT ["./start_server.sh"]
