#cloud-config
package_update: true
package_upgrade: false

packages:
  - docker.io
  - docker-compose

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - mkdir -p /opt/gatus
  - |
    cat > /opt/gatus/config.yaml <<'EOF'
    web:
      port: 8080

    endpoints:
      - name: "${target_name} ICMP"
        url: "icmp://${target_ip}"
        interval: 5s
        conditions:
          - "[CONNECTED] == true"

      - name: "${target_name} SSH (TCP 22)"
        url: "tcp://${target_ip}:22"
        interval: 5s
        conditions:
          - "[CONNECTED] == true"

      - name: "${target_name} HTTP test (TCP 9000)"
        url: "tcp://${target_ip}:9000"
        interval: 5s
        conditions:
          - "[CONNECTED] == true"
    EOF
  - >
    docker run -d
    --name gatus
    --restart unless-stopped
    --cap-add NET_RAW
    -p 8080:8080
    -v /opt/gatus/config.yaml:/config/config.yaml
    twinproduction/gatus:latest
