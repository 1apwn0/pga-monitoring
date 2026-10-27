FROM debian:latest
COPY cadvisor-binary /usr/bin/cadvisor
EXPOSE 8080
ENTRYPOINT ["/usr/bin/cadvisor", "--port=8080"]
