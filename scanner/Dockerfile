FROM kalilinux/kali-rolling

RUN sed -i 's|http://http.kali.org/kali|http://mirrors.tuna.tsinghua.edu.cn/kali|g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y nmap proxychains4 jq curl

# Patch /usr/share/nmap/scripts/http-open-proxy.nse and socks-open-proxy.nse to add port 7890
RUN sed -i 's/{8000, 8080}/{8000, 8080, 7890}/g' /usr/share/nmap/scripts/http-open-proxy.nse && \
    sed -i 's/{1080, 9050}/{1080, 9050, 7890}/g' /usr/share/nmap/scripts/socks-open-proxy.nse

WORKDIR /root

CMD ["nmap", "--version"]